process BIGSLICE_PREP_INPUT {
  label 'bigslice'
  tag "dataset=${params.bigslice_dataset_name}"

  input:
    val antismash_dirs

  output:
    path "input", emit: input_dir
    path "versions.yml", emit: versions

  script:
  """
  set -euo pipefail

  DS="${params.bigslice_dataset_name}"
  ROOT="input"
  OUT="$ROOT/$DS"
  TAX="$OUT/taxonomy"

  rm -rf "$ROOT"
  mkdir -p "$OUT" "$TAX"

  for d in ${antismash_dirs.collect{ "\"$it\"" }.join(' ')}; do
    [ -d "$d" ] || continue
    sample=\$(basename "\$d")
    mkdir -p "\$OUT/\$sample"
    find "\$d" -type f \\( -name "*.region*.gbk" -o -name "*.gbk" \\) -print0 \
      | xargs -0 -I{} cp -f "{}" "\$OUT/\$sample/"
  done

  if [ -n "${params.bigslice_taxonomy:-}" ]; then
    cp "${params.bigslice_taxonomy}" "$TAX/dataset_taxonomy.tsv"
  else
    printf "accession\\ttaxdomain\\tphylum\\tclass\\torder\\tfamily\\tgenus\\tspecies\\n" > "$TAX/dataset_taxonomy.tsv"
    for d in "$OUT"/*/; do
      [ -d "$d" ] || continue
      acc=\$(basename "\$d")/
      printf "%s\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\n" "\$acc" >> "$TAX/dataset_taxonomy.tsv"
    done
  fi

  cat > "$ROOT/datasets.tsv" <<EOF
dataset_name\tdataset_path\taxonomy_path\tdescription
$DS\t$DS\t$DS/taxonomy/dataset_taxonomy.tsv\tantiSMASH $DS
EOF

  cat <<-END_VERSIONS > versions.yml
  "NFCORE_FUNCSCAN:FUNCSCAN:BGC:BIGSLICE_PREP_INPUT":
      bigslice: $(bigslice --version 2>&1 || echo unknown)
  END_VERSIONS
  """
}
