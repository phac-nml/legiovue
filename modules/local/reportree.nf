// TODO - Incorporate when we have a time to create a working container/setup
process REPORTREE {
    label 'process_medium'

    publishDir "${params.outdir}/reportree", pattern: "", mode: 'copy'

    // No conda at the moment as the install for the env is a pain
    // conda "$projectDir/envs/"
    // Only a docker container that they host at the moment
    //  Container also missing ps so won't work
    container "insapathogenomics/reportree"

    input:
    path cgmlst
    path metadata

    output:
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def metadata_arg = metadata ? "-m $metadata" : ""
    """
    reportree.py \\
        $metadata_arg \\
        -a $cgmlst/cgMLST100.tsv \\
        -thr 0-5 \\
        --method MSTreeV2 \\
        --loci-called 1.0 \\
        --matrix-4-grapetree \\
        --analysis grapetree

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ReporTree: \$(reportree.py -v | head -n 1 | cut -d' ' -f2)
    END_VERSIONS
    """

    stub:
    """
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ReporTree: \$(reportree.py -v | head -n 1 | cut -d' ' -f2)
    END_VERSIONS
    """
}
