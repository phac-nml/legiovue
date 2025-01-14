process PLOT_PYSAMSTATS_TSV {
    tag "$meta.id"
    label 'process_low'
    // As its just a plot output better to ignore errors for now
    label 'error_ignore'

    conda "$projectDir/envs/plotting-env.yml"
    // Custom built for this...
    // container "docker://docker.io/darianhole/legio-plotting:0.1.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-b2ec1fea5791d428eebb8c8ea7409c350d31dada:a447f6b7a6afde38352b24c30ae9cd6e39df95c4-1' :
        'biocontainers/mulled-v2-b2ec1fea5791d428eebb8c8ea7409c350d31dada:a447f6b7a6afde38352b24c30ae9cd6e39df95c4-1' }"

    input:
    tuple val(meta), path(tsv)

    output:
    tuple val(meta), path("${meta.id}_allele_plots.pdf"), emit: plot
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    plot_genome_cov.R \\
        --input_tsv $tsv \\
        --outfile ${meta.id}_allele_plots.pdf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        plot_genome_cov: 0.1.0
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}_allele_plots.pdf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        plot_genome_cov: 0.1.0
    END_VERSIONS
    """
}
