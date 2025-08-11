process BIGSLICE_PREP_INPUT {
  label 'bigslice'
  tag "dataset=${params.bigslice_dataset_name}"

  input:
  val antismash_dirs

  output:
  path "input", emit: input_dir

  script:
  def DATASET = params.bigslice_dataset_name
  def OUT     = "input/${DATASET}"
  """
  set -euo pipefail

  OUT="${OUT}"
  mkdir -p "\$OUT/taxonomy"

  # 1) leagă fiecare director antiSMASH ca subfolder în dataset
  for d in ${antismash_dirs.collect{ "\"$it\"" }.join(' ')}; do
    [ -d "\$d" ] || continue
    bn=\$(basename "\$d")
    ln -sfn "\$d" "\$OUT/\$bn"
  done

  # 2) taxonomy: antet + câte o linie per folder-probă (Unknown dacă nu dai GTDB)
  printf "accession\\ttaxdomain\\tphylum\\tclass\\torder\\tfamily\\tgenus\\tspecies\\n" > "\$OUT/taxonomy/dataset_taxonomy.tsv"
  for d in ${antismash_dirs.collect{ "\"$it\"" }.join(' ')}; do
    bn=\$(basename "\$d")
    printf "%s/\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\n" "\$bn" >> "\$OUT/taxonomy/dataset_taxonomy.tsv"
  done

  # 3) datasets.tsv (4 coloane)
  mkdir -p input
  printf "%s\t%s\t%s\t%s\n" \
    "$DATASET" "$DATASET" "$DATASET/taxonomy/dataset_taxonomy.tsv" "antiSMASH $DATASET" \
    > "input/datasets.tsv"

  """
}
