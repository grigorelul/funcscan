process BIGSLICE_RUN {
  label 'bigslice'
  tag "dataset=${params.bigslice_dataset_name}"

  input:
    path input_dir
    path models_dir

  output:
    path "output/**", emit: outdir
    path "versions.yml", emit: versions

  script:
  """
  set -euo pipefail

  # evităm promptul interactiv ("Folder output exists?..."):
  rm -rf output 2>/dev/null || true

  bigslice \
    -i "${input_dir}" \
    --program_db_folder "${models_dir}" \
    output

  printf '"NFCORE_FUNCSCAN:FUNCSCAN:BGC:BIGSLICE_RUN":\\n  bigslice: "%s"\\n' "$(bigslice --version 2>&1 || echo unknown)" > versions.yml || true
  """
}
