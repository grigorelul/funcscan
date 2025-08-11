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

  DATASET="${params.bigslice_dataset_name}"
  OUT="input/${params.bigslice_dataset_name}"
  mkdir -p "\$OUT/taxonomy"

  # copiem doar .gbk / .region*.gbk din directoarele antiSMASH
  for d in ${antismash_dirs.collect{ "\"$it\"" }.join(' ')}; do
    [ -d "\$d" ] || continue
    find "\$d" -type f \\( -name "*.region*.gbk" -o -name "*.gbk" \\) -print0 \
      | xargs -0 -I{} cp -n "{}" "\$OUT/"
  done

  # taxonomy (dacă nu dai fișier, scriem antetul gol)
  if [ "${params.bigslice_taxonomy ?: ''}" != "" ]; then
    cp "${params.bigslice_taxonomy}" "\$OUT/taxonomy/dataset_taxonomy.tsv"
  else
    printf "accession\\ttaxdomain\\tphylum\\tclass\\torder\\tfamily\\tgenus\\tspecies\\n" > "\$OUT/taxonomy/dataset_taxonomy.tsv"
  fi

  # >>> manifestul pentru BiG-SLiCE: dataset \\t subfolder
  printf "%s\\t%s\\n" "\$DATASET" "\$DATASET" > "input/datasets.tsv"
  """
}
