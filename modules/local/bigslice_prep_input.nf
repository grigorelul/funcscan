process BIGSLICE_PREP_INPUT {
  tag "bigslice_prep_input"

  input:
  val dataset_name                 // ex: params.bigslice_dataset_name ?: 'antismash'
  val taxonomy_src                 // ex: params.bigslice_taxonomy (poate fi null)

  output:
  path "input", emit: input_dir
  path "input/datasets.tsv", emit: datasets_tsv
  path "input/taxonomy/dataset_taxonomy.tsv", emit: taxonomy_tsv

  script:
  """
  set -euo pipefail

  # Creăm structura în work directory
  mkdir -p "input/${dataset_name}" "input/taxonomy"

  # --- datasets.tsv (TAB-uri garantate) ---
  printf "# dataset_name\\tdataset_path\\ttaxonomy_path\\tdescription\\n" \\
    > "input/datasets.tsv"
  printf "%s\\t%s\\t%s\\t%s\\n" \\
    "${dataset_name}" "${dataset_name}" "taxonomy/dataset_taxonomy.tsv" "antiSMASH ${dataset_name}" \\
    >> "input/datasets.tsv"

  # --- taxonomy ---
  if [ -n "${taxonomy_src}" ] && [ -f "${taxonomy_src}" ] && [ -s "${taxonomy_src}" ]; then
      # copiem exact ce ai dat tu
      cp "${taxonomy_src}" "input/taxonomy/dataset_taxonomy.tsv"
  else
      # fallback: doar antetul în 9 coloane (format BiG-SLiCE)
      printf "# Genome folder\\tKingdom\\tPhylum\\tClass\\tOrder\\tFamily\\tGenus\\tSpecies\\tOrganism\\n" \\
        > "input/taxonomy/dataset_taxonomy.tsv"
  fi

  # mici verificări de sanity (nu opresc rularea, doar ajută la debug)
  awk -F '\\t' 'NR==1{print "datasets.tsv header cols:", NF}' "input/datasets.tsv" >&2 || true
  awk -F '\\t' 'NR==1{print "taxonomy.tsv header cols:", NF}' "input/taxonomy/dataset_taxonomy.tsv" >&2 || true
  """
}
