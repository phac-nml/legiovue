process PLOT_PYSAMSTATS_TSV {
    tag "$meta.id"
    label 'process_low'

    publishDir "${params.outdir}/el_gato/plots", pattern: "*_allele_plots.pdf", mode: 'copy'

    conda "$projectDir/envs/plotting-env.yml"
    // Custom built for this...
    container "docker://darianhole/legio-plotting:0.1.0"

    input:
    tuple val(meta), path(tsv)

    output:
    tuple val(meta), path("${meta.id}_allele_plots.pdf"), emit: plot
    path "versions.yml", emit: versions

    script:
    // Special handling of using executables based on a docker micromamba image
    // https://stackoverflow.com/a/78027234
    // https://micromamba-docker.readthedocs.io/en/latest/faq.html#how-can-i-use-a-mambaorg-micromamba-based-image-with-apptainer
    def run_cmd = workflow.containerEngine == 'singularity' || workflow.containerEngine == 'apptainer' ? '/usr/local/bin/_entrypoint.sh plot_genome_cov.R' : 'plot_genome_cov.R'
    """
    $run_cmd \\
        --input_tsv $tsv \\
        --outfile ${meta.id}_allele_plots.pdf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        plot_genome_cov: 0.1.0
    END_VERSIONS
    """
}
