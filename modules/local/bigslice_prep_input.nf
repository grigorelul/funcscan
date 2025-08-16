process PREP_BIGSLICE_INPUT {
  tag "prep_bigslice_input"

  input:
  val outdir                       // ai deja setat în workflow
  val dataset_name                 // ex: params.bigslice_dataset_name ?: 'antismash'
  val taxonomy_src                 // ex: params.bigslice_taxonomy (poate fi null)

  output:
  path "${outdir}/bigslice/input/datasets.tsv", emit: datasets_tsv
  path "${outdir}/bigslice/input/taxonomy/dataset_taxonomy.tsv", emit: taxonomy_tsv

  shell:
  '''
  set -euo pipefail

  input_dir="${outdir}/bigslice/input"
  ds="${dataset_name}"

  mkdir -p "${input_dir}/${ds}" "${input_dir}/taxonomy"

  # --- datasets.tsv (TAB-uri garantate) ---
  printf "# dataset_name\tdataset_path\ttaxonomy_path\tdescription\n" \
    >  "${input_dir}/datasets.tsv"
  printf "%s\t%s\t%s\t%s\n" \
    "${ds}" "${ds}" "taxonomy/dataset_taxonomy.tsv" "antiSMASH ${ds}" \
    >> "${input_dir}/datasets.tsv"

  # --- taxonomy ---
  if [ -n "${taxonomy_src:-}" ] && [ -s "${taxonomy_src}" ]; then
      # copiem exact ce ai dat tu
      cp "${taxonomy_src}" "${input_dir}/taxonomy/dataset_taxonomy.tsv"
  else
      # fallback: doar antetul în 9 coloane (format BiG-SLiCE)
      printf "# Genome folder\tKingdom\tPhylum\tClass\tOrder\tFamily\tGenus\tSpecies\tOrganism\n" \
        > "${input_dir}/taxonomy/dataset_taxonomy.tsv"
  fi

  # mici verificări de sanity (nu opresc rularea, doar ajută la debug)
  awk -F '\\t' 'NR==1{print "datasets.tsv header cols:", NF}' "${input_dir}/datasets.tsv" >&2 || true
  awk -F '\\t' 'NR==1{print "taxonomy.tsv header cols:", NF}' "${input_dir}/taxonomy/dataset_taxonomy.tsv" >&2 || true
  '''
}
