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

INPUT_ROOT="${input_dir}"

# evităm promptul interactiv 'Folder output exists?'
rm -rf output 2>/dev/null || true

bigslice \
  -i "${INPUT_ROOT}" \
  --program_db_folder "${models_dir}" \
  output

  """
}
