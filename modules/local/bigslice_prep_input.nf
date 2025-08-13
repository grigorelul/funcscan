process BIGSLICE_PREP_INPUT {
  label 'bigslice'

  input:
    val antismash_dirs   // listă colectată .collect()

  output:
    path "input", emit: input_dir

  script:
    // pregătesc lista pentru for-ul din bash
    def dirsQuoted = antismash_dirs.collect { "\"${it}\"" }.join(' ')
    """
    set -euo pipefail

    # Setez DS in BASH (nu doar Groovy)
    DS="${params.bigslice_dataset_name}"

    ROOT="input"; OUT="\$ROOT/\$DS"; TAX="\$OUT/taxonomy"
    rm -rf "\$ROOT"
    mkdir -p "\$OUT" "\$TAX"

    # copiem .gbk/.region*.gbk pe subfoldere per-sample
    for d in ${dirsQuoted}; do
      [ -d "\$d" ] || continue
      sample=\$(basename "\$d")
      mkdir -p "\$OUT/\$sample"
      find "\$d" -type f \\( -name "*.region*.gbk" -o -name "*.gbk" \\) -print0 \
        | xargs -0 -I{} cp -f "{}" "\$OUT/\$sample/"
    done

    # taxonomy într-un singur fișier (o linie per sample)
    printf "accession\\ttaxdomain\\tphylum\\tclass\\torder\\tfamily\\tgenus\\tspecies\\n" > "\$TAX/dataset_taxonomy.tsv"
    for d in "\$OUT"/*/; do
      [ -d "\$d" ] || continue
      acc=\$(basename "\$d")/
      printf "%s\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\tUnknown\\n" "\$acc" >> "\$TAX/dataset_taxonomy.tsv"
    done

    # datasets.tsv la rădăcina input/
    cat > "\$ROOT/datasets.tsv" <<EOF
dataset_name\tdataset_path\ttaxonomy_path\tdescription
\$DS\t\$DS\t\$DS/taxonomy/dataset_taxonomy.tsv\tantiSMASH \$DS
EOF
    """
}
