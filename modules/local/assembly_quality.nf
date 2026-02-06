#!/usr/bin/env nextflow
process MINIMAP2_ASSEMBLY {
    tag "$meta.id"
    label 'process_low'

    conda "conda-forge::minimap2=2.28-4"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/minimap2:2.28--he4a0461_3' :
        'biocontainers/minimap2:2.28--he4a0461_3' }"

    publishDir '5.Assembly_Evaluation', mode: 'copy'
    
    input:
    tuple val(meta), path(assembly)
    tuple val(meta), path(trimmed_reads)

    output:
    tuple val(meta), path("*${meta.id}.sam"), emit: assembly_sam

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    awk \\
        ' /^>/ && FNR > 1 {next} {print \$0} ' \\
        $assembly \\
        > ./${meta.id}_single_contig.fasta \\
    && \\
    minimap2 \\
        -ax map-ont \\
        ./${meta.id}_single_contig.fasta \\
        $trimmed_reads \\
        > ./${meta.id}.sam
    """
}

process SAMTOOLS_COVERAGE_ASSEMBLY {
    tag "$meta.id"
    label 'process_low'

    conda "conda-forge::samtools:1.14"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.14--hb421002_0' :
        'biocontainers/samtools:1.14--hb421002_0' }"

    publishDir '5.Assembly_Evaluation', mode: 'copy'
    
    input:
    tuple val(meta), path(assembly_sam)

    output:
    tuple val(meta), path("*${meta.id}_assembly_coverage.txt"), emit: assembly_coverage

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    samtools sort \\
        -O bam \\
        -o ./${meta.id}.bam \\
        $assembly_sam \\
    && \\
    samtools index \\
        ./${meta.id}.bam \\
    && \\
    samtools coverage \\
        ./${meta.id}.bam \\
        -o ./${meta.id}_assembly_coverage.txt \\
    """
}

workflow ASSEMBLY_DEPTH {
    take:
    ch_assembly
    ch_trimmed_reads

    main:
    

    //emit coverage report for qc data collection
    emit:
    SAMTOOLS_COVERAGE.out.assembly_coverage
}
