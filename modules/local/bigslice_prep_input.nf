process BIGSLICE_PREP_INPUT {
  label 'bigslice'
  tag "dataset=${params.bigslice_dataset_name}"

  input:
    val ds                      // numele dataset-ului (ex: 'antismash')
    val dirs                    // listă de directoare antiSMASH, colectată în subworkflow
    path tax_file optional true // fișier taxonomy TSV (opțional)

  output:
    path "input", emit: input_dir

  script:
    // porțiunea care scrie taxonomy: dacă avem fișier, îl copiem; altfel generăm cu "Unknown"
    def taxonomyBlock = tax_file ? """
      cp "${tax_file}" "\$TAX/dataset_taxonomy.tsv"
    """ : """
      printf "accession\\ttaxdomain\\tphylum\\tclass\\torder\\tfamily\\tgenus\\tspecies\\n" > "\$TAX/dataset_taxonomy.tsv"
      for d in "\$OUT"/*/; do
        [ -d "\$d" ] || continue
        acc=\$(basename "\$d")/
        printf "%s\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\n" "\$acc" >> "\$TAX/dataset_taxonomy.tsv"
      done
    """

    // directoarele antiSMASH, quotate pentru bash
    def dirsQuoted = dirs.collect{ "\"$it\"" }.join(' ')

    return """
    set -euo pipefail

    ROOT="input"
    OUT="\$ROOT/${ds}"
    TAX="\$OUT/taxonomy"

    rm -rf "\$ROOT"
    mkdir -p "\$OUT" "\$TAX"

    # copiem .gbk pe probe, în subfoldere separate
    for d in ${dirsQuoted}; do
      [ -d "\$d" ] || continue
      sample=\$(basename "\$d")
      mkdir -p "\$OUT/\$sample"
      find "\$d" -type f \\( -name "*.region*.gbk" -o -name "*.gbk" \\) -print0 \
        | xargs -0 -I{} cp -f "{}" "\$OUT/\$sample/"
    done

    ${taxonomyBlock}

    # datasets.tsv la rădăcina 'input/'
    cat > "\$ROOT/datasets.tsv" <<EOF
    dataset_name\tdataset_path\ttaxonomy_path\tdescription
    ${ds}\t${ds}\t${ds}/taxonomy/dataset_taxonomy.tsv\tantiSMASH ${ds}
    EOF
    """
}
