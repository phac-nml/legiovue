process CREATE_ABUNDANCE_FILTER {
    tag "$meta.id"
    label 'process_single'

    conda "conda-forge::pandas=2.2.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:2.2.1' :
        'biocontainers/pandas:2.2.1' }"

    input:
    tuple val(meta), path(bracken_report)

    output:
    tuple val(meta), path("${meta.id}.check.csv"), emit: abundance_check
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    filter_lpn_abundance.py \\
        --sample ${meta.id} \\
        --bracken_tsv $bracken_report \\
        --threshold ${params.min_abundance_percent}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        filter_lpn_abundance: 0.1.0
    END_VERSIONS
    """
}

process CSVTK_COMBINE_STATS {
    tag "$meta.id"
    label 'process_single'

    publishDir "${params.outdir}/el_gato/allele_stats", pattern: "*.tsv", mode: 'copy'

    conda "bioconda::csvtk=0.30.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/csvtk:0.30.0--h9ee0642_0':
        'biocontainers/csvtk:0.30.0--h9ee0642_0' }"

    input:
    tuple val(meta), path(mapq_tsv), path(baseq_tsv)

    output:
    tuple val(meta), path("${meta.id}.allele_stats.tsv"), emit: tsv
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    csvtk \\
        join \\
        -tT \\
        -f "chrom,pos,reads_all,reads_pp" \\
        $mapq_tsv \\
        $baseq_tsv \\
    > ${meta.id}.allele_stats.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        csvtk: \$(echo \$( csvtk version | sed -e "s/csvtk v//g" ))
    END_VERSIONS
    """
}

process CSVTK_COMBINE{
    label 'process_single'

    publishDir "${params.outdir}", pattern: "*.tsv", mode: 'copy'

    conda "bioconda::csvtk=0.30.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/csvtk:0.30.0--h9ee0642_0':
        'biocontainers/csvtk:0.30.0--h9ee0642_0' }"

    input:
    path tsvs

    output:
    path "overall.qc.tsv", emit: tsv
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    csvtk \\
        concat \\
        -tT \\
        $tsvs \\
    > overall.qc.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        csvtk: \$(echo \$( csvtk version | sed -e "s/csvtk v//g" ))
    END_VERSIONS
    """
}
