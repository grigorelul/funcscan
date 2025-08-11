process BIGSLICE_PREP_INPUT {
  label 'bigslice'
  tag "dataset=${params.bigslice_dataset_name}"

  input:
    val antismash_dirs

  output:
    // emitem rădăcina "input" (nu subfolderul), ca să meargă -i input
    path "input", emit: input_dir

  script:
  """
  set -euo pipefail

  DATASET="${params.bigslice_dataset_name}"
  ROOT="input"
  OUT="\${ROOT}/\${DATASET}"
  mkdir -p "\$OUT/taxonomy"

  # copiez doar *.gbk și *.region*.gbk din fiecare director antiSMASH
  for d in ${antismash_dirs.collect{ "\"$it\"" }.join(' ')}; do
    [ -d "\$d" ] || continue
    find "\$d" -type f \\( -name "*.region*.gbk" -o -name "*.gbk" \\) -print0 \
      | xargs -0 -I{} cp -n "{}" "\$OUT/"
  done

  # taxonomy: din parametru sau header gol
  if [ "${params.bigslice_taxonomy ?: ''}" != "" ]; then
    cp "${params.bigslice_taxonomy}" "\$OUT/taxonomy/dataset_taxonomy.tsv"
  else
    printf "accession\\ttaxdomain\\tphylum\\tclass\\torder\\tfamily\\tgenus\\tspecies\\n" > "\$OUT/taxonomy/dataset_taxonomy.tsv"
  fi

  # IMPORTANT: registrul de dataset-uri (4 coloane)
  # <name>   <path_rel_la_input>   <tax_rel_la_input>   <descriere>
  printf "%s\\t%s\\t%s\\t%s\\n" \
    "\$DATASET" \
    "\$DATASET" \
    "\$DATASET/taxonomy/dataset_taxonomy.tsv" \
    "antiSMASH BGCs" > "\$ROOT/datasets.tsv"
  """
}
