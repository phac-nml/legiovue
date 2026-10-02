process KRAKEN2_CLASSIFY {
    tag "$meta.id"
    label 'process_high'

    conda "bioconda::kraken2=2.1.3"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-8706a1dd73c6cc426e12dd4dd33a5e917b3989ae:c8cbdc8ff4101e6745f8ede6eb5261ef98bdaff4-0' :
        'biocontainers/mulled-v2-8706a1dd73c6cc426e12dd4dd33a5e917b3989ae:c8cbdc8ff4101e6745f8ede6eb5261ef98bdaff4-0' }"

    input:
    tuple val(meta), path(reads)
    path db

    output:
    tuple val(meta), path('*-classified.tsv'), optional: true, emit: classified
    tuple val(meta), path('*-kreport.tsv'), optional: true, emit: report
    tuple val(meta), path('empty.txt'), optional: true, emit: no_reads
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def gz_arg = reads[0].toString().endsWith('.gz') ? "--gzip-compressed" : ""
    def gz_cat = reads[0].toString().endsWith('.gz') ? "zcat ${reads[0]}" : "cat ${reads[0]}"
    """
    # Need at least a few reads to not fail, going with 5
    if [ \$($gz_cat | head -n 20 | wc -l) -eq 20 ]; then
        kraken2 \\
            --paired \\
            $gz_arg \\
            --confidence 0.1 \\
            --threads $task.cpus \\
            --output ${meta.id}-classified.tsv \\
            --report ${meta.id}-kreport.tsv \\
            --memory-mapping \\
            --db $db \\
            $reads
    else
        touch empty.txt
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kraken2: \$(echo \$(kraken2 --version 2>&1) | sed 's/^.*Kraken version //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}-classified.tsv
    touch ${meta.id}-kreport.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kraken2: \$(echo \$(kraken2 --version 2>&1) | sed 's/^.*Kraken version //; s/ .*\$//')
    END_VERSIONS
    """
}
