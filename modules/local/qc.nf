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
    tuple val(meta), path("*.tsv"), emit: tsv
    path "versions.yml", emit: versions

    script:
    def trimmomatic_arg         = trimmomatic_summary ? "-tr $trimmomatic_summary" : ""
    def quast_report_arg        = quast_report ? "-qa $quast_report" : ""
    def scored_quast_report_arg = scored_quast_report ? "-fs $scored_quast_report" : ""
    def st_report_arg           = st_report ? "-st $st_report" : ""
    def chewbbaca_stats_arg     = chewbbaca_stats ? "-al $chewbbaca_stats" : ""
    """
    combine_qc_data.py \\
        -s ${meta.id} \\
        -br $bracken_report \\
        $trimmomatic_arg \\
        $quast_report_arg \\
        $scored_quast_report_arg \\
        $st_report_arg \\
        $chewbbaca_stats_arg \\
        --min_abundance_percent ${params.min_abundance_percent} \\
        --min_reads ${params.min_reads}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        combine_qc_data: 0.1.0
    END_VERSIONS
    """
}
