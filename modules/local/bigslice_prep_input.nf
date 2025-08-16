process BIGSLICE_PREP_INPUT {
  label 'bigslice'
  tag "dataset=${params.bigslice_dataset_name}"

  input:
  // lista directoarelor antiSMASH (câte unul per sample)
  val antismash_dirs

  output:
  // întregul folder "input" (va conține DS/, taxonomy/, datasets.tsv)
  path "input", emit: input_dir

  script:
  // pregătesc lista de directoare pt. for-loop în bash
  def quoted = antismash_dirs.collect { "\"${it}\"" }.join(' ')
  """
  set -euo pipefail

  ROOT="input"
  DS="${params.bigslice_dataset_name}"
  OUT="\$ROOT/\$DS"
  TAXROOT="\$ROOT/taxonomy"

  rm -rf "\$ROOT"
  mkdir -p "\$OUT" "\$TAXROOT"

  # copiem .gbk pe fiecare probă în subfoldere separate
  for d in ${quoted}; do
    [ -d "\$d" ] || continue
    sample=\$(basename "\$d")
    mkdir -p "\$OUT/\$sample"
    find "\$d" -type f \\( -name "*.region*.gbk" -o -name "*.gbk" \\) -print0 \
      | xargs -0 -I{} cp -f "{}" "\$OUT/\$sample/"
  done

  # taxonomie: un singur fișier cu header + câte o linie pe sample
  if [ -n "${params.bigslice_taxonomy ?: ''}" ]; then
    # dacă l-ai dat prin parametru, îl copiem ca atare
    cp "${params.bigslice_taxonomy}" "\$TAXROOT/dataset_taxonomy.tsv"
  else
    # generăm placeholder „Unknown"
    printf "accession\\ttaxdomain\\tphylum\\tclass\\torder\\tfamily\\tgenus\\tspecies\\n" > "\$TAXROOT/dataset_taxonomy.tsv"
    for d in "\$OUT"/*/; do
      [ -d "\$d" ] || continue
      acc=\$(basename "\$d")/
      printf "%s\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\n" "\$acc" >> "\$TAXROOT/dataset_taxonomy.tsv"
    done
  fi

  # datasets.tsv cu header comentat
  {
    echo "# dataset_name\\tdataset_path\\ttaxonomy_path\\tdescription"
    printf "%s\\t%s\\t%s\\t%s\\n" "\$DS" "\$DS" "taxonomy/dataset_taxonomy.tsv" "antiSMASH \$DS"
  } > "\$ROOT/datasets.tsv"
  """
}
