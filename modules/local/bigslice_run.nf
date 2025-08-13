process BIGSLICE_RUN {
  label 'bigslice'
  tag "dataset=${params.bigslice_dataset_name}"

  input:
    path input_dir
    path models_dir

  output:
    path "output", emit: outdir
    path "versions.yml", emit: versions

  script:
  """
  set -euo pipefail
  rm -rf output 2>/dev/null || true

  bigslice \
    -i "${input_dir}" \
    --program_db_folder "${models_dir}" \
    output

  cat <<-END_VERSIONS > versions.yml
  "NFCORE_FUNCSCAN:FUNCSCAN:BGC:BIGSLICE_RUN":
      bigslice: $(bigslice --version 2>&1 || echo unknown)
  END_VERSIONS
  """
}
