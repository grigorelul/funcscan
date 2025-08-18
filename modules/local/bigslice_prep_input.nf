/*
 * BIGSLICE_PREP_INPUT: Prepares antiSMASH outputs for BiG-SLiCE analysis
 * 
 * This process transforms antiSMASH output directories into the specific
 * directory structure and file format that BiG-SLiCE expects for clustering
 * biosynthetic gene clusters (BGCs).
 * 
 * BiG-SLiCE input structure:
 * input/
 * ├── datasets.tsv              # dataset configuration file
 * ├── <dataset_name>/           # GBK files organized by sample (each GBK contains a BGC region)
 * │   ├── sample1/
 * │   │   ├── region001.gbk     # BGC region 1 in GenBank format
 * │   │   └── region002.gbk     # BGC region 2 in GenBank format
 * │   └── sample2/
 * │       └── region001.gbk     # BGC region 1 in GenBank format
 * └── taxonomy/
 *     └── dataset_taxonomy.tsv  # taxonomic information (9-column format)
 */
process BIGSLICE_PREP_INPUT {
  label 'bigslice'
  tag "dataset=${params.bigslice_dataset_name}"

  input:
  // list of antiSMASH output directories (one per sample)
  val antismash_dirs

  output:
  // complete "input" folder structure for BiG-SLiCE (contains dataset/, taxonomy/, datasets.tsv)
  path "input", emit: input_dir

  script:
  // prepare quoted directory list for bash for-loop processing
  def quoted = antismash_dirs.collect { "\"${it}\"" }.join(' ')
  """
  set -euo pipefail

  # define directory structure variables
  ROOT="input"                              # BiG-SLiCE input root directory
  DS="${params.bigslice_dataset_name}"      # dataset name (e.g., 'antismash')
  OUT="\$ROOT/\$DS"                         # dataset-specific output directory
  TAXROOT="\$ROOT/taxonomy"                 # taxonomy directory

  # clean and create directory structure
  rm -rf "\$ROOT"
  mkdir -p "\$OUT" "\$TAXROOT"

  # copy GBK files from each antiSMASH sample to separate subdirectories
  # each GBK file contains a BGC region and maintains per-sample organization required by BiG-SLiCE
  for d in ${quoted}; do
    [ -d "\$d" ] || continue                # skip if directory doesn't exist
    sample=\$(basename "\$d")               # extract sample name from directory path
    mkdir -p "\$OUT/\$sample"               # create sample-specific subdirectory
    
    # find and copy all BGC region GBK files (*.region*.gbk or *.gbk)
    # each file represents one biosynthetic gene cluster region
    find "\$d" -type f \\( -name "*.region*.gbk" -o -name "*.gbk" \\) -print0 \
      | xargs -0 -I{} cp -f "{}" "\$OUT/\$sample/"
  done

  # create taxonomy file: single TSV with 9-column GTDB format + one line per sample
  if [ -n "${params.bigslice_taxonomy ?: ''}" ]; then
    # if taxonomy file provided via parameter, copy as-is
    cp "${params.bigslice_taxonomy}" "\$TAXROOT/dataset_taxonomy.tsv"
  else
    # generate placeholder taxonomy file with "Unknown" values
    # BiG-SLiCE requires 9 columns: accession, taxdomain, phylum, class, order, family, genus, species, organism
    printf "accession\\ttaxdomain\\tphylum\\tclass\\torder\\tfamily\\tgenus\\tspecies\\torganism\\n" > "\$TAXROOT/dataset_taxonomy.tsv"
    
    # add one line per sample with "Unknown" taxonomic classifications
    for d in "\$OUT"/*/; do
      [ -d "\$d" ] || continue
      acc=\$(basename "\$d")/                # sample accession (with trailing slash as per BiG-SLiCE format)
      printf "%s\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\n" "\$acc" >> "\$TAXROOT/dataset_taxonomy.tsv"
    done
  fi

  # create datasets.tsv configuration file with commented header
  # this file tells BiG-SLiCE where to find the dataset and taxonomy information
  {
    echo "# dataset_name\\tdataset_path\\ttaxonomy_path\\tdescription"
    printf "%s\\t%s\\t%s\\t%s\\n" "\$DS" "\$DS" "taxonomy/dataset_taxonomy.tsv" "antiSMASH \$DS"
  } > "\$ROOT/datasets.tsv"
  """
}
