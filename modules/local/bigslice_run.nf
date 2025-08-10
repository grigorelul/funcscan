process BIGSLICE_RUN {
  label 'bigslice'
  tag "dataset=${params.bigslice_dataset_name}"

  input:
    path dataset_dir
    path models_dir

  output:
    path "output"

  script:
  """
  set -euo pipefail

  INPUT_ROOT="\$(dirname "${dataset_dir}")"
  mkdir -p output/result/cache

  bigslice -i "\${INPUT_ROOT}" --program_db_folder "${models_dir}" output
  """
}
