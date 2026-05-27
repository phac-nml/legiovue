#!/usr/bin/env nextflow
process NANOQ {
    label 'process_low'

    conda "bioconda::nanoq=0.10.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/nanoq:0.10.0--hc1c3326_4 ' :
        'biocontainers/nanoq:0.10.0--hc1c3326_4 ' }"

    input:
        tuple val(meta), path(nanopore_fastqs) 

    output:
        tuple val(meta), path ("./${meta.id}.fastq"), emit: trimmed_reads
        tuple val(meta), path ("./${meta.id}_nanoq.txt"), emit: report
        path "versions.yml", emit: versions

    script:
    """
    nanoq \\
        --min-len 1000 \\
        --input $nanopore_fastqs \\
        --output ${meta.id}.fastq \\
        --output-type u \\
        --stats \\
        --header \\
        -vvv \\
        --report ${meta.id}_nanoq.txt \\


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanoq: \$(echo \$(nanoq --version | sed -e 's/nanoq //g'))
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}.fastq

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanoq: \$(nanoq --version | sed -e 's/nanoq //g')
    END_VERSIONS
    """
}