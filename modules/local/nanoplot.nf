#!/usr/bin/env nextflow
process NANOPLOT {
    label 'process_low'

    conda "bioconda::nanoplot=1.44.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/nanoplot:1.44.1--pyhdfd78af_0' :
        'biocontainers/nanoplot:1.44.1--pyhdfd78af_0' }"

    input:
        tuple val(meta), path(nanopore_fastqs) 
    
    output:
        path "./${meta.id}/"
        tuple val(meta), path("./${meta.id}/${meta.id}_NanoStats.txt"), emit: untrimmed_NanoStats
        tuple val(meta), path("./${meta.id}/NanoPlot-report.html"), emit: untrimmed_report
        path "versions.yml", emit: versions

    script:
    """
    NanoPlot \\
        --fastq $nanopore_fastqs \\
        --outdir ./${meta.id}/ \\
        --no_static \\

    #rename output files to include sample name \\
    mv ./${meta.id}/NanoStats.txt ./${meta.id}/${meta.id}_NanoStats.txt \\

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanoplot: \$(echo \$(NanoPlot --version 2>&1) | sed 's/^.*NanoPlot //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p ${meta.id}
    touch ${meta.id}/${meta.id}_NanoStats.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanoplot: \$(NanoPlot --version 2>&1 | sed 's/^.*NanoPlot //; s/ .*\$//')
    END_VERSIONS
    """
}
