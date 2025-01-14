process QUAST {
    label 'process_medium'

    conda "bioconda::quast=5.2.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/quast:5.2.0--py39pl5321h2add14b_1' :
        'biocontainers/quast:5.2.0--py39pl5321h2add14b_1' }"

    input:
    path contigs
    path reference

    output:
    path "transposed_report.tsv", emit: report
    path "report.html", emit: html_report
    path "report.pdf", emit: pdf_report
    path "*_stats", emit: stats_folders
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    quast \\
        --threads $task.cpus \\
        -o ./ \\
        -r $reference \\
        *.contigs.fa

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quast: \$(quast.py --version 2>&1 | sed 's/^.*QUAST v//; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    """
    touch transposed_report.tsv
    touch report.html
    touch report.pdf
    mkdir quast_stats

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quast: \$(quast.py --version 2>&1 | sed 's/^.*QUAST v//; s/ .*\$//')
    END_VERSIONS
    """
}

process SCORE_QUAST {
    label 'process_single'

    publishDir "${params.outdir}", pattern: "scored_quast_report.csv", mode: 'copy'

    conda "conda-forge::python=3.10.4"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.10.4' :
        'biocontainers/python:3.10.4' }"

    input:
    path transposed_report

    output:
    path "scored_quast_report.csv", emit: report
    path "versions.yml", emit: versions

    script:
    """
    quast_analyzer.py \\
        $transposed_report \\
        --outfile scored_quast_report.csv

    # TODO Add in version to the script itself at some point
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quast_analyzer: 0.1.0
    END_VERSIONS
    """

    stub:
    """
    touch scored_quast_report.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quast_analyzer: 0.1.0
    END_VERSIONS
    """
}
