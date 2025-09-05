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
