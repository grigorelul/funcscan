process BIGSLICE_PREP_INPUT {
  label 'bigslice'
  tag "dataset=${params.bigslice_dataset_name}"

  input:
    val antismash_dirs

  output:
    path "input", emit: input_dir

  script:
  // pregătim valori GROOVY aici, ca să evităm ${...:-} în bash
  def DS = params.bigslice_dataset_name
  def TAXFILE = params.bigslice_taxonomy ?: ''
  def quotedDirs = antismash_dirs.collect{ "\"$it\"" }.join(' ')

  """
  set -euo pipefail

  ROOT="input"
  OUT="\$ROOT/!{DS}"
  TAXROOT="\$ROOT/taxonomy"

  rm -rf "\$ROOT"
  mkdir -p "\$OUT" "\$TAXROOT"

  # copiem .gbk pe fiecare probă în subfoldere separate
  for d in ${quotedDirs}; do
    [ -d "\$d" ] || continue
    sample=\$(basename "\$d")
    mkdir -p "\$OUT/\$sample"
    find "\$d" -type f \\( -name "*.region*.gbk" -o -name "*.gbk" \\) -print0 \
      | xargs -0 -I{} cp -f "{}" "\$OUT/\$sample/"
  done

  # taxonomy: fișier unic cu câte o linie per sample
  if [ -n "!{TAXFILE}" ]; then
    cp "!{TAXFILE}" "\$TAXROOT/dataset_taxonomy.tsv"
  else
    printf "accession\\ttaxdomain\\tphylum\\tclass\\torder\\tfamily\\tgenus\\tspecies\\n" > "\$TAXROOT/dataset_taxonomy.tsv"
    for d in "\$OUT"/*/; do
      [ -d "\$d" ] || continue
      acc=\$(basename "\$d")/
      printf "%s\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\n" "\$acc" >> "\$TAXROOT/dataset_taxonomy.tsv"
    done
  fi

  # datasets.tsv FĂRĂ header — BiG-SLiCE 2.0.2 NU ignoră headerul
  # taxonomy_path este la același nivel: "taxonomy/dataset_taxonomy.tsv"
  printf "%s\\t%s\\t%s\\t%s\\n" "!{DS}" "!{DS}" "taxonomy/dataset_taxonomy.tsv" "antiSMASH !{DS}" > "\$ROOT/datasets.tsv"
  """
}
