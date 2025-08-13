process BIGSLICE_PREP_INPUT {
  label 'bigslice'

  // copiem input-ul în outdir (nu symlink)
  publishDir [
    path: "${params.outdir}/bigslice/${params.bigslice_dataset_name}",
    mode: 'copy',
    pattern: 'input/**'
  ]

  input:
    val antismash_dirs   // lista de directoare antiSMASH (unul pe probă)

  output:
    path "input", emit: input_dir   // directorul 'input' complet pe care îl dăm mai departe

  script:
  """
  set -euo pipefail

  DS="\${params.bigslice_dataset_name}"
  ROOT="input"
  OUT="\$ROOT/\$DS"
  TAX="\$OUT/taxonomy"

  rm -rf "\$ROOT"
  mkdir -p "\$OUT" "\$TAX"

  # copiem .gbk pe fiecare probă în subfoldere separate
  for d in ${antismash_dirs.collect{ "\"$it\"" }.join(' ')}; do
    [ -d "\$d" ] || continue
    sample=\$(basename "\$d")
    mkdir -p "\$OUT/\$sample"
    find "\$d" -type f \\( -name "*.region*.gbk" -o -name "*.gbk" \\) -print0 \
      | xargs -0 -I{} cp -f "{}" "\$OUT/\$sample/"
  done

  # taxonomy: dacă ai dat un fișier, îl copiem; altfel generăm "Unknown" per sample
  if [ -n "\${params.bigslice_taxonomy:-}" ]; then
    cp "\${params.bigslice_taxonomy}" "\$TAX/dataset_taxonomy.tsv"
  else
    printf "accession\\ttaxdomain\\tphylum\\tclass\\torder\\tfamily\\tgenus\\tspecies\\n" > "\$TAX/dataset_taxonomy.tsv"
    for d in "\$OUT"/*/; do
      [ -d "\$d" ] || continue
      acc=\$(basename "\$d")/
      printf "%s\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\n" "\$acc" >> "\$TAX/dataset_taxonomy.tsv"
    done
  fi

  # datasets.tsv la rădăcina "input/"
  cat > "\$ROOT/datasets.tsv" <<EOF
dataset_name\tdataset_path\ttaxonomy_path\tdescription
\$DS\t\$DS\t\$DS/taxonomy/dataset_taxonomy.tsv\tantiSMASH \$DS
EOF
  """
}
