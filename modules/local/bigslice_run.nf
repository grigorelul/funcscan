process BIGSLICE_RUN {
  label 'bigslice'

  input:
  path input_dir
  path models_dir

  output:
  path "output", emit: outdir

  script:
  """
  set -euo pipefail
  rm -rf output 2>/dev/null || true

  bigslice \
    -i "${input_dir}" \
    --program_db_folder "${models_dir}" \
    output
  """
}
