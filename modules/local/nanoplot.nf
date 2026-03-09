#!/usr/bin/env nextflow
process NANOPLOT {
    label 'process_low'

    conda "bioconda::nanoplot=1.44.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/nanoplot:1.44.1--pyhdfd78af_0' :
        'biocontainers/nanoplot:1.44.1--pyhdfd78af_0' }"

    publishDir '1.Nanoplot_Results', mode: 'copy'

    input:
        tuple val(meta), path(nanopore_fastqs) 
    
    output:
        path "./${meta.id}_Untrimmed/"
        tuple val(meta), path("./${meta.id}_Untrimmed/${meta.id}_Untrimmed_NanoStats.txt"), emit: untrimmed_NanoStats
        path "versions.yml", emit: versions

    script:
    """
    NanoPlot \\
        --fastq $nanopore_fastqs \\
        --outdir ./${meta.id}_Untrimmed/ \\
        --no_static \\

    #rename output files to include sample name \\
    mv ./${meta.id}_Untrimmed/NanoStats.txt ./${meta.id}_Untrimmed/${meta.id}_Untrimmed_NanoStats.txt \\

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanoplot: \$(echo \$(NanoPlot --version 2>&1) | sed 's/^.*NanoPlot //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p ${meta.id}_Untrimmed
    touch ${meta.id}_Untrimmed/${meta.id}_Untrimmed_NanoStats.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanoplot: \$(NanoPlot --version 2>&1 | sed 's/^.*NanoPlot //; s/ .*\$//')
    END_VERSIONS
    """
}

process NANOPLOT_TRIMMED {
    label 'process_low'

    conda "bioconda::nanoplot=1.44.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/nanoplot:1.44.1--pyhdfd78af_0' :
        'biocontainers/nanoplot:1.44.1--pyhdfd78af_0' }"

    publishDir '1.Nanoplot_Results', mode: 'copy'

    input:
        tuple val(meta), path(trimmed_reads) 
    
    output:
        path "./${meta.id}_Trimmed/"
        tuple val(meta), path("./${meta.id}_Trimmed/${meta.id}_Trimmed_NanoStats.txt"), emit: trimmed_NanoStats
        path "versions.yml", emit: versions

    script:
    """
    NanoPlot \\
        --fastq $trimmed_reads \\
        --outdir ./${meta.id}_Trimmed/ \\
        --no_static \\
    
    #rename output files to include sample name \\
    mv ./${meta.id}_Trimmed/NanoStats.txt ./${meta.id}_Trimmed/${meta.id}_Trimmed_NanoStats.txt \\

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanoplot: \$(echo \$(NanoPlot --version 2>&1) | sed 's/^.*NanoPlot //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p ${meta.id}_Trimmed
    touch ${meta.id}_Trimmed/${meta.id}_Trimmed_NanoStats.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanoplot: \$(NanoPlot --version 2>&1 | sed 's/^.*NanoPlot //; s/ .*\$//')
    END_VERSIONS
    """
}
