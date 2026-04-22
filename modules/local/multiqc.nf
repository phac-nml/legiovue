process MULTIQC {
    label 'process_medium'

    conda "bioconda::multiqc=1.28"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/multiqc:1.28--pyhdfd78af_0' :
        'biocontainers/multiqc:1.28--pyhdfd78af_0' }"

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
    multiqc \\
        -f \\
        -k yaml \\
        --config $multiqc_config \\
        ./

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: \$(echo \$(multiqc --version 2>&1) | sed 's/^multiqc, version //')
    END_VERSIONS
    """
}
