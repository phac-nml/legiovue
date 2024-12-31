process KRAKEN2_CLASSIFY {
    tag "$meta.id"
    label 'process_high'

    publishDir "${params.outdir}/kraken_bracken", pattern: "*-classified.tsv", mode: 'copy'
    publishDir "${params.outdir}/kraken_bracken", pattern: "*-kreport.tsv", mode: 'copy'

    conda "bioconda::kraken2=2.1.3"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-8706a1dd73c6cc426e12dd4dd33a5e917b3989ae:c8cbdc8ff4101e6745f8ede6eb5261ef98bdaff4-0' :
        'biocontainers/mulled-v2-8706a1dd73c6cc426e12dd4dd33a5e917b3989ae:c8cbdc8ff4101e6745f8ede6eb5261ef98bdaff4-0' }"

    input:
    tuple val(meta), path(reads)
    path db

    output:
    tuple val(meta), path('*-classified.tsv'), emit: classified
    tuple val(meta), path('*-kreport.tsv'), emit: report
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def gz_arg = reads[0].endsWith('.gz') ? "--gzip-compressed" : ""
    """
    kraken2 \\
        --paired \\
        $gz_arg \\
        --confidence 0.1 \\
        --threads $task.cpus \\
        --output ${meta.id}-classified.tsv \\
        --report ${meta.id}-kreport.tsv \\
        --db $db \\
        $reads

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kraken2: \$(echo \$(kraken2 --version 2>&1) | sed 's/^.*Kraken version //; s/ .*\$//')
    END_VERSIONS
    """
}
