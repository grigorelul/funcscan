process BIGSLICE_PREP_INPUT {
  label 'bigslice'
  tag "dataset=${params.bigslice_dataset_name}"

  /*
   * Pasăm valorile din params către script prin variabile de mediu
   * (evităm astfel interpolarea ${params...} în bash).
   */
  env.DS       = params.bigslice_dataset_name
  env.TAX_FILE = params.bigslice_taxonomy ?: ''

  input:
    // listă de directoare antiSMASH (unul per sample), colectată în subworkflow
    val antismash_dirs

  output:
    // expunem întregul folder 'input' (va conține datasets.tsv, taxonomy/, samples/)
    path "input", emit: input_dir

  script:
  """
  set -euo pipefail

  ROOT="input"
  OUT="\$ROOT/\$DS"
  TAX="\$OUT/taxonomy"

  rm -rf "\$ROOT"
  mkdir -p "\$OUT" "\$TAX"

  # copiem .gbk în subfoldere pe sample
  for d in ${antismash_dirs.collect{ "\"$it\"" }.join(' ')}; do
    [ -d "\$d" ] || continue
    sample=\$(basename "\$d")
    mkdir -p "\$OUT/\$sample"
    find "\$d" -type f \\( -name "*.region*.gbk" -o -name "*.gbk" \\) -print0 \
      | xargs -0 -I{} cp -f "{}" "\$OUT/\$sample/"
  done

  # taxonomy: folosim fișierul dat sau generăm unul cu Unknown per sample
  if [ -n "\$TAX_FILE" ]; then
    cp "\$TAX_FILE" "\$TAX/dataset_taxonomy.tsv"
  else
    printf "accession\\ttaxdomain\\tphylum\\tclass\\torder\\tfamily\\tgenus\\tspecies\\n" > "\$TAX/dataset_taxonomy.tsv"
    for d in "\$OUT"/*/; do
      [ -d "\$d" ] || continue
      acc=\$(basename "\$d")/
      printf "%s\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\n" "\$acc" >> "\$TAX/dataset_taxonomy.tsv"
    done
  fi

  # datasets.tsv la rădăcina 'input/'
  cat > "\$ROOT/datasets.tsv" <<EOF
  dataset_name\tdataset_path\ttaxonomy_path\tdescription
  \$DS\t\$DS\t\$DS/taxonomy/dataset_taxonomy.tsv\tantiSMASH \$DS
  EOF
  """
}
