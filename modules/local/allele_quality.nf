#!/usr/bin/env nextflow
process MINIMAP2_ALLELES {
    tag "$meta.id"
    label 'process_medium'

    conda "conda-forge::minimap2=2.28-4"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/minimap2:2.28--he4a0461_3' :
        'biocontainers/minimap2:2.28--he4a0461_3' }"
    
    input:
    tuple val(meta), path(alleles)
    tuple val(meta), path(trimmed_reads)

    output:
    tuple val(meta), path("*${meta.id}_alleles.sam"), emit: alleles_sam
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    minimap2 \\
        -ax map-ont \\
        $alleles \\
        $trimmed_reads \\
        > ./${meta.id}_alleles.sam
    
    # Versions #
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        minimap2: \$(echo \$(minimap2 --version 2>&1))
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}_alleles.sam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        minimap2: \$(minimap2 --version 2>&1)
    END_VERSIONS
    """
}

process SAMTOOLS_COVERAGE_ALLELES {
    tag "$meta.id"
    label 'process_low'

    conda "conda-forge::samtools:1.14"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.14--hb421002_0' :
        'biocontainers/samtools:1.14--hb421002_0' }"
    
    input:
    tuple val(meta), path(alleles_sam)

    output:
    tuple val(meta), path("*${meta.id}_alleles_coverage.txt"), emit: alleles_coverage
    tuple val(meta), path("${meta.id}_alleles.bam"), emit: alleles_bam
    path "versions.yml", emit: versions

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
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//' )
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}_alleles_coverage.txt
    touch ${meta.id}_alleles.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(samtools --version 2>&1 | sed 's/^.*samtools //; s/Using.*\$//' )
    END_VERSIONS
    """
}

process PYSAMSTATS_NANOPORE {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::pysamstats=1.1.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pysamstats:1.1.2--py39h0699b22_14':
        'biocontainers/pysamstats:1.1.2--py39h0699b22_14' }"
    
    input:
    tuple val(meta), path(alleles_bam)

    output:
    tuple val(meta), path("*${meta.id}_allele_stats.tsv"), emit: allele_stats_tsv
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    pysamstats \\
        --type baseq \\
        $alleles_bam \\
        > ./${meta.id}_allele_stats.tsv \\
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pysamstats: \$(echo \$(pysamstats -h | tail -n 2 | grep -Eo ": \\S+" | cut -d" " -f2))
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}_allele_stats.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pysamstats: \$(echo \$(pysamstats -v 2>&1 | head -n 1))
    END_VERSIONS
    """
}
