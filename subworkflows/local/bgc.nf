/*
    Run BGC screening tools
*/

include { UNTAR as UNTAR_ANTISMASHDB             } from '../../modules/nf-core/untar/main'
include { ANTISMASH_ANTISMASHDOWNLOADDATABASES   } from '../../modules/nf-core/antismash/antismashdownloaddatabases/main'
include { ANTISMASH_ANTISMASH                    } from '../../modules/nf-core/antismash/antismash/main'
include { GECCO_RUN                              } from '../../modules/nf-core/gecco/run/main'
include { HMMER_HMMSEARCH as BGC_HMMER_HMMSEARCH } from '../../modules/nf-core/hmmer/hmmsearch/main'
include { DEEPBGC_DOWNLOAD                       } from '../../modules/nf-core/deepbgc/download/main'
include { DEEPBGC_PIPELINE                       } from '../../modules/nf-core/deepbgc/pipeline/main'
include { COMBGC                                 } from '../../modules/local/combgc'
include { TABIX_BGZIP as BGC_TABIX_BGZIP         } from '../../modules/nf-core/tabix/bgzip/main'
include { MERGE_TAXONOMY_COMBGC                  } from '../../modules/local/merge_taxonomy_combgc'
include { BIGSLICE_PREP_INPUT } from '../modules/local/bigslice_prep_input'
include { BIGSLICE_RUN        } from '../modules/local/bigslice_run'



workflow BGC {
    take:
    fastas // tuple val(meta), path(PREPPED_INPUT.out.fna)
    faas   // tuple val(meta), path(<ANNO_TOOL>.out.faa)
    gbks   // tuple val(meta), path(<ANNO_TOOL>.out.gbk)
    tsvs   // tuple val(meta), path(MMSEQS_CREATETSV.out.tsv)

    main:
    ch_versions = Channel.empty()
    ch_bgcresults_for_combgc = Channel.empty()

    // When adding new tool that requires FAA, make sure to update conditions
    // in funcscan.nf around annotation and AMP subworkflow execution
    // to ensure annotation is executed!
    ch_faa_for_bgc_hmmsearch = faas

    // ANTISMASH
    if (!params.bgc_skip_antismash) {
        // Check whether user supplies database and/or antismash directory. If not, obtain them via the module antismash/antismashdownloaddatabases.
        // Important for future maintenance: For CI tests, only the "else" option below is used. Both options should be tested locally whenever the antiSMASH module gets updated.
        if (params.bgc_antismash_db && file(params.bgc_antismash_db, checkIfExists: true).extension == 'gz') {
            UNTAR_ANTISMASHDB([[id: 'antismashdb'], file(params.bgc_antismash_db, checkIfExists: true)])
            ch_antismash_databases = UNTAR_ANTISMASHDB.out.untar.map { _meta, dir -> [dir] }
        }
        else if (params.bgc_antismash_db && file(params.bgc_antismash_db, checkIfExists: true).isDirectory()) {
            ch_antismash_databases = Channel.fromPath(params.bgc_antismash_db, checkIfExists: true).first()
        }
        else {
            ANTISMASH_ANTISMASHDOWNLOADDATABASES()
            ch_versions = ch_versions.mix(ANTISMASH_ANTISMASHDOWNLOADDATABASES.out.versions)
            ch_antismash_databases = ANTISMASH_ANTISMASHDOWNLOADDATABASES.out.database
        }

        ANTISMASH_ANTISMASH(gbks, ch_antismash_databases, [])

        ch_versions = ch_versions.mix(ANTISMASH_ANTISMASH.out.versions)
        ch_antismashresults = ANTISMASH_ANTISMASH.out.knownclusterblast_dir
            .mix(ANTISMASH_ANTISMASH.out.gbk_input)
            .groupTuple()
            .map { meta, files ->
                [meta, files.flatten()]
            }

        // Filter out samples with no BGC hits
        ch_antismashresults_for_combgc = ch_antismashresults
            .join(fastas, remainder: false)
            .join(ANTISMASH_ANTISMASH.out.gbk_results, remainder: false)
            .map { meta, gbk_input, _fasta, _gbk_results ->
                [meta, gbk_input]
            }

        ch_bgcresults_for_combgc = ch_bgcresults_for_combgc.mix(ch_antismashresults_for_combgc)

                // colectăm directoarele antiSMASH (unul per probă)
        ch_antismash_dirs = ANTISMASH_ANTISMASH.out.html
        .map { meta, html -> html.parent }
        .collect()

        if( params.run_bigslice ) {
        // 1) pregătim input-ul BiG-SLiCE
        BIGSLICE_PREP_INPUT( ch_antismash_dirs )

        // 2) rulăm BiG-SLiCE
        BIGSLICE_RUN(
            BIGSLICE_PREP_INPUT.out.input_dir,
            file(params.bigslice_models)
        )
        }

    }

    // DEEPBGC
    if (!params.bgc_skip_deepbgc) {
        if (params.bgc_deepbgc_db) {

            ch_deepbgc_database = Channel.fromPath(params.bgc_deepbgc_db, checkIfExists: true)
                .first()
        }
        else {
            DEEPBGC_DOWNLOAD()
            ch_deepbgc_database = DEEPBGC_DOWNLOAD.out.db
            ch_versions = ch_versions.mix(DEEPBGC_DOWNLOAD.out.versions)
        }

        DEEPBGC_PIPELINE(gbks, ch_deepbgc_database)
        ch_versions = ch_versions.mix(DEEPBGC_PIPELINE.out.versions)
        ch_bgcresults_for_combgc = ch_bgcresults_for_combgc.mix(DEEPBGC_PIPELINE.out.bgc_tsv)
    }

    // GECCO
    if (!params.bgc_skip_gecco) {
        ch_gecco_input = gbks
            .groupTuple()
            .multiMap {
                fastas: [it[0], it[1], []]
            }

        GECCO_RUN(ch_gecco_input, [])
        ch_versions = ch_versions.mix(GECCO_RUN.out.versions)
        ch_geccoresults_for_combgc = GECCO_RUN.out.gbk
            .mix(GECCO_RUN.out.clusters)
            .groupTuple()
            .map { meta, files ->
                [meta, files.flatten()]
            }
        ch_bgcresults_for_combgc = ch_bgcresults_for_combgc.mix(ch_geccoresults_for_combgc)
    }

    // HMMSEARCH
    if (params.bgc_run_hmmsearch) {
        if (params.bgc_hmmsearch_models) {
            ch_bgc_hmm_models = Channel.fromPath(params.bgc_hmmsearch_models, checkIfExists: true)
        }
        else {
            error('[nf-core/funcscan] error: hmm model files not found for --bgc_hmmsearch_models! Please check input.')
        }

        ch_bgc_hmm_models_meta = ch_bgc_hmm_models.map { file ->
            def meta = [:]
            meta['id'] = file.extension == 'gz' ? file.name - '.hmm.gz' : file.name - '.hmm'

            [meta, file]
        }

        ch_in_for_bgc_hmmsearch = ch_faa_for_bgc_hmmsearch
            .combine(ch_bgc_hmm_models_meta)
            .map { meta_faa, faa, meta_hmm, hmm ->
                def meta_new = [:]
                meta_new['id'] = meta_faa['id']
                meta_new['hmm_id'] = meta_hmm['id']
                [meta_new, hmm, faa, params.bgc_hmmsearch_savealignments, params.bgc_hmmsearch_savetargets, params.bgc_hmmsearch_savedomains]
            }

        BGC_HMMER_HMMSEARCH(ch_in_for_bgc_hmmsearch)
        ch_versions = ch_versions.mix(BGC_HMMER_HMMSEARCH.out.versions)
    }

    // COMBGC

    ch_bgcresults_for_combgc
        .join(fastas, remainder: true)
        .filter { meta, bgcfile, fasta ->
            if (!bgcfile) {
                log.warn("[nf-core/funcscan] BGC workflow: No hits found by BGC tools; comBGC summary tool will not be run for sample: ${meta.id}")
            }
            return [meta, bgcfile, fasta]
        }

    COMBGC(ch_bgcresults_for_combgc)
    ch_versions = ch_versions.mix(COMBGC.out.versions)

    // COMBGC concatenation
    if (!params.run_taxa_classification) {
        ch_combgc_summaries = COMBGC.out.tsv.map { it[1] }.collectFile(name: 'combgc_complete_summary.tsv', storeDir: "${params.outdir}/reports/combgc", keepHeader: true)
    }
    else {
        ch_combgc_summaries = COMBGC.out.tsv.map { it[1] }.collectFile(name: 'combgc_complete_summary.tsv', keepHeader: true)
    }

    // MERGE_TAXONOMY
    if (params.run_taxa_classification) {

        ch_mmseqs_taxonomy_list = tsvs.map { it[1] }.collect()
        MERGE_TAXONOMY_COMBGC(ch_combgc_summaries, ch_mmseqs_taxonomy_list)
        ch_versions = ch_versions.mix(MERGE_TAXONOMY_COMBGC.out.versions)

        ch_tabix_input = Channel.of(['id': 'combgc_complete_summary_taxonomy'])
            .combine(MERGE_TAXONOMY_COMBGC.out.tsv)

        BGC_TABIX_BGZIP(ch_tabix_input)
        ch_versions = ch_versions.mix(BGC_TABIX_BGZIP.out.versions)
    }

    emit:
    versions = ch_versions
}
