#!/usr/bin/env nextflow
process NANOQ {
    label 'process_low'

    conda "bioconda::dragonflye=1.2.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/dragonflye:1.2.1--hdfd78af_0' :
        'biocontainers/dragonflye:1.2.1--hdfd78af_0' }"

    publishDir '2.Trimmed_Reads', mode: 'copy'

    input:
        tuple val(meta), path(nanopore_fastqs) 

    output:
        tuple val(meta), path ("Trimmed_${meta.id}.fastq"), emit: trimmed_reads

    script:
    """
    nanoq \\
        --min-len 1000 \\
        --input $nanopore_fastqs \\
        --output Trimmed_${meta.id}.fastq \\
        --output-type u \\
    """
}