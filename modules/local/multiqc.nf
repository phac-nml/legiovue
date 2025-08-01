process MULTIQC {
    label 'process_medium'

    conda "bioconda::multiqc=1.28"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/multiqc:1.28--pyhdfd78af_0' :
        'quay.io/biocontainers/multiqc:1.28--pyhdfd78af_0' }"

    input:
    path multiqc_config
    path fastqcs_zips
    path scored_quast_report
    path el_gato_report
    path bracken_breakdowns
    path trimmomatic_stderrs
    path chewbbacca_allele_stats
    path overall_qc
    path versions_yml

    output:
    path "*multiqc_report.html", emit: report
    path "*_data", emit: data
    path "versions.yml", emit: versions

    script:
    """
    mkdir -p multiqc_work_dir
    cp -r \\
        ${fastqcs_zips} \\
        ${scored_quast_report} \\
        ${el_gato_report} \\
        ${bracken_breakdowns} \\
        ${trimmomatic_stderrs} \\
        ${chewbbacca_allele_stats} \\
        ${overall_qc} \\
        ${versions_yml} \\
        multiqc_work_dir/

    multiqc \\
        -f \\
        -k yaml \\
        --config $multiqc_config \\
        multiqc_work_dir/

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: \$(echo \$(multiqc --version 2>&1) | sed 's/^multiqc, version //')
    END_VERSIONS
    """
}
