process COMBINE_SAMPLE_DATA {
    tag "$meta.id"
    label 'process_low'

    conda "conda-forge::pandas=2.2.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:2.2.1' :
        'biocontainers/pandas:2.2.1' }"

    input:
    tuple val(meta), path(bracken_report), path(trimmomatic_summary)
    path(quast_report)
    path(scored_quast_report)
    path(st_report)
    path(chewbbaca_stats)

    output:
    tuple val(meta), path("*.csv"), emit: csv
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def trimmomatic_arg         = trimmomatic_summary ? "-tr $trimmomatic_summary" : ""
    def quast_report_arg        = quast_report ? "-qa $quast_report" : ""
    def scored_quast_report_arg = scored_quast_report ? "-fs $scored_quast_report" : ""
    def st_report_arg           = st_report ? "-st $st_report" : ""
    def chewbbaca_stats_arg     = chewbbaca_stats ? "-al $chewbbaca_stats" : ""
    def irida_id_arg            = meta.irida_id ? "-id ${meta.irida_id}": ""
    """
    combine_qc_data.py \\
        -s ${meta.id} \\
        -br $bracken_report \\
        $trimmomatic_arg \\
        $quast_report_arg \\
        $scored_quast_report_arg \\
        $st_report_arg \\
        $chewbbaca_stats_arg \\
        $irida_id_arg \\
        --min_abundance_percent ${params.min_abundance_percent} \\
        --min_reads_fail ${params.min_reads} \\
        --min_reads_warn ${params.min_reads_warn}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        combine_qc_data: 0.3.0
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        combine_qc_data: 0.3.0
    END_VERSIONS
    """
}

process COMBINE_SAMPLE_DATA_NANOPORE {
    tag "$meta.id"
    label 'process_low'

    conda "conda-forge::pandas=2.2.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:2.2.1' :
        'biocontainers/pandas:2.2.1' }"

    input:
    tuple val(meta), path(bracken_report)
    tuple val(meta), path(pretrim_nanoplot_txt)
    tuple val(meta), path(trim_nanoplot_txt)
    path(quast_report)
    path(scored_quast_report)
    tuple val(meta), path(assembly_cov_txt)
    tuple val(meta), path(sbt_tsv)
    tuple val(meta), path(allele_cov_txt)
    path(chewbbaca_stats)

    output:
    tuple val(meta), path("./${meta.id}.qc.csv"), emit: csv
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    nanopore_combine_qc_data.py \\
        --sample ${meta.id} \\
        --bracken_tsv $bracken_report \\
        --pretrim_nanoplot_txt $pretrim_nanoplot_txt \\
        --trim_nanoplot_txt $trim_nanoplot_txt \\
        --quast_tsv $quast_report \\
        --quast_score_csv $scored_quast_report \\
        --assembly_cov_txt $assembly_cov_txt \\
        --st_tsv $sbt_tsv \\
        --allele_cov_txt $allele_cov_txt \\
        --chewbbaca_stats_tsv $chewbbaca_stats \\
        --min_reads ${params.min_reads_nanopore} \\
        --min_reads_warn ${params.min_reads_warn_nanopore} \\
        --min_length ${params.min_length_nanopore} \\
        --min_length_warn ${params.min_read_length_warn_nanopore} \\
        --min_qual ${params.min_quality_nanopore} \\
        --min_qual_warn ${params.min_read_quality_warn_nanopore} \\
        --min_abundance_percent ${params.min_abundance_percent} \\
        --outdir ./ \\

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanopore_combine_qc_data: 0.3.0
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanopore_combine_qc_data: 0.3.0
    END_VERSIONS
    """
}
