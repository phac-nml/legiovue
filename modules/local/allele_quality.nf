#!/usr/bin/env nextflow
process MINIMAP2_ALLELES {
    tag "$meta.id"
    label 'process_medium'

    conda "conda-forge::minimap2=2.28-4"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/minimap2:2.28--he4a0461_3' :
        'biocontainers/minimap2:2.28--he4a0461_3' }"

    publishDir '6.Allele_Evaluation', mode: 'copy'
    
    input:
    tuple val(meta), path(alleles)
    tuple val(meta), path(trimmed_reads)

    output:
    tuple val(meta), path("*${meta.id}_alleles.sam"), emit: alleles_sam

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    minimap2 \\
        -ax map-ont \\
        $alleles \\
        $trimmed_reads \\
        > ./${meta.id}_alleles.sam
    """
}

process SAMTOOLS_COVERAGE_ALLELES {
    tag "$meta.id"
    label 'process_low'

    conda "conda-forge::samtools:1.14"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.14--hb421002_0' :
        'biocontainers/samtools:1.14--hb421002_0' }"

    publishDir '6.Allele_Evaluation', mode: 'copy'
    
    input:
    tuple val(meta), path(alleles_sam)

    output:
    tuple val(meta), path("*${meta.id}_alleles_coverage.txt"), emit: alleles_coverage
    tuple val(meta), path("${meta.id}_alleles.bam"), emit: alleles_bam

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    samtools sort \\
        -O bam \\
        -o ./${meta.id}_alleles.bam \\
        $alleles_sam \\
    && \\
    samtools index \\
        ./${meta.id}_alleles.bam \\
    && \\
    samtools coverage \\
        ./${meta.id}_alleles.bam \\
        -o ./${meta.id}_alleles_coverage.txt \\
    """
}

process PYSAMSTATS_NANOPORE {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::pysamstats=1.1.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pysamstats:1.1.2--py39he47c912_12':
        'biocontainers/pysamstats:1.1.2--py39he47c912_12' }"

    publishDir '6.Allele_Evaluation', mode: 'copy'
    
    input:
    tuple val(meta), path(alleles_bam)

    output:
    tuple val(meta), path("*${meta.id}_alleles_baseq.tsv"), emit: alleles_baseq

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    pysamstats \\
        --type baseq \\
        $alleles_bam \\
        > ./${meta.id}_alleles_baseq.tsv \\
    """
}
