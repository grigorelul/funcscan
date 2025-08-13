process BIGSLICE_PREP_INPUT {
  label 'bigslice'
  tag "dataset=${params.bigslice_dataset_name}"

  input:
    val antismash_dirs

  output:
    path "input", emit: input_dir

  script:
  """
  set -euo pipefail

  ROOT="input"
  OUT="\$ROOT/!{ params.bigslice_dataset_name }"
  TAXROOT="\$ROOT/taxonomy"

  rm -rf "\$ROOT"
  mkdir -p "\$OUT" "\$TAXROOT"

  # copiem .gbk pe fiecare probă în subfoldere separate
  for d in !{ antismash_dirs.collect{ '"' + it + '"' }.join(' ') }; do
    [ -d "\$d" ] || continue
    sample=\$(basename "\$d")
    mkdir -p "\$OUT/\$sample"
    find "\$d" -type f \\( -name "*.region*.gbk" -o -name "*.gbk" \\) -print0 \
      | xargs -0 -I{} cp -f "{}" "\$OUT/\$sample/"
  done

  # taxonomy: fișier unic cu câte o linie per sample
  TX="!{ params.bigslice_taxonomy ?: '' }"
  if [ -n "\$TX" ]; then
    cp "\$TX" "\$TAXROOT/dataset_taxonomy.tsv"
  else
    printf "accession\\ttaxdomain\\tphylum\\tclass\\torder\\tfamily\\tgenus\\tspecies\\n" > "\$TAXROOT/dataset_taxonomy.tsv"
    for d in "\$OUT"/*/; do
      [ -d "\$d" ] || continue
      acc=\$(basename "\$d")/
      printf "%s\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\n" "\$acc" >> "\$TAXROOT/dataset_taxonomy.tsv"
    done
  fi

  # datasets.tsv FĂRĂ header
  printf "%s\\t%s\\t%s\\t%s\\n" \
    "!{ params.bigslice_dataset_name }" \
    "!{ params.bigslice_dataset_name }" \
    "taxonomy/dataset_taxonomy.tsv" \
    "antiSMASH !{ params.bigslice_dataset_name }" \
    > "\$ROOT/datasets.tsv"
  """
}
