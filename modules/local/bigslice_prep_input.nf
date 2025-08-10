process BIGSLICE_RUN {
  tag "${params.bigslice_dataset_name}"

  input:
    path input_dir
    path models_dir

  output:
    path("result")       emit: result
    path("versions.yml") emit: versions

  script:
  """
  set -euo pipefail
  mkdir -p result/cache

  bigslice -i "\${input_dir}" \\
           --program_db_folder "\${models_dir}" \\
           "\${PWD}"

  cat <<EOF > versions.yml
BIGSLICE_RUN:
  bigslice: $(bigslice --version 2>&1 || echo unknown)
EOF
  """
}
