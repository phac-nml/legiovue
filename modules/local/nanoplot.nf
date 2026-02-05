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
        tuple val(meta), path("./${meta.id}_Untrimmed/NanoStats.txt"), emit: untrimmed_NanoStats

    script:
    """
    NanoPlot \\
        --fastq $nanopore_fastqs \\
        --outdir ./${meta.id}_Untrimmed/ \\
        --no_static \\
    """
}

#!/usr/bin/env nextflow
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
        tuple val(meta), path("./${meta.id}_Trimmed/NanoStats.txt"), emit: trimmed_NanoStats

    script:
    """
    NanoPlot \\
        --fastq $trimmed_reads \\
        --outdir ./${meta.id}_Trimmed/ \\
        --no_static \\
    """
}
