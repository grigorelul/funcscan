process BIGSLICE_RUN {
  label 'bigslice'

  input:
  path input_dir
  path models_dir

  output:
  path "output/**",    emit: out_dir
  path "versions.yml", emit: versions

  script:
  """
  set -euo pipefail

  # evităm promptul interactiv „Folder output exists? …”
  rm -rf output 2>/dev/null || true

  bigslice \
    -i "${input_dir}" \
    --program_db_folder "${models_dir}" \
    output

  # versiunea nu e obligatorie; dacă vrei un placeholder:
  printf "bigslice: unknown\n" > versions.yml
  """
}