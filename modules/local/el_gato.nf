process EL_GATO_READS {
    tag "$meta.id"
    label 'process_medium'

    publishDir "${params.outdir}/el_gato/reads", pattern: "*.tsv", mode: 'copy'
    publishDir "${params.outdir}/el_gato/reads", pattern: "*.bam*", mode: 'copy'
    publishDir "${params.outdir}/el_gato/reads", pattern: "*.log", mode: 'copy'
    publishDir "${params.outdir}/el_gato/reads", pattern: "*.json", mode: 'copy'
    publishDir "${params.outdir}/el_gato/reads", pattern: "*_possible_mlsts.txt", mode: 'copy'

    conda "bioconda::el_gato=1.20.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/el_gato:1.20.2--py311h7e72e81_0' :
        'biocontainers/el_gato:1.20.2--py311h7e72e81_0' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("${meta.id}_ST.tsv"), emit: report
    tuple val(meta), path("${meta.id}*.bam"), path("${meta.id}*.bam.bai"), optional: true, emit: bam_bai
    tuple val(meta), path("${meta.id}_possible_mlsts.txt"), optional: true, emit: possible_mlsts
    tuple val(meta), path("${meta.id}_run.log"), emit: log
    tuple val(meta), path("${meta.id}_reads.json"), emit: json
    path "versions.yml", emit: versions

    script:
    def reads_in = "--read1 ${reads[0]} --read2 ${reads[1]}"
    """
    el_gato.py \\
        --threads $task.cpus \\
        --out out \\
        --sample ${meta.id} \\
        --header \\
        $reads_in \\
    > ${meta.id}_ST.tsv

    # Rename outputs #
    mv out/run.log ${meta.id}_run.log
    mv out/report.json ${meta.id}_reads.json

    if [ -f out/possible_mlsts.txt ]; then
        mv out/possible_mlsts.txt ${meta.id}_possible_mlsts.txt
    fi

    if [ -f out/reads_vs_all_ref_filt_sorted.bam ]; then
        mv out/reads_vs_all_ref_filt_sorted.bam ${meta.id}_reads_vs_all_ref_filt_sorted.bam
        mv out/reads_vs_all_ref_filt_sorted.bam.bai ${meta.id}_reads_vs_all_ref_filt_sorted.bam.bai
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        el_gato: \$(el_gato.py --version | sed 's/^el_gato version: //')
    END_VERSIONS
    """
}

// TODO: Combine to one function at some point as
//  maintaining 2 is a pain
process EL_GATO_ASSEMBLY {
    tag "$meta.id"
    label 'process_low'
    label 'error_ignore' // Non-legion samples explode here otherwise

    publishDir "${params.outdir}/el_gato/assembly", pattern: "*.tsv", mode: 'copy'
    publishDir "${params.outdir}/el_gato/assembly", pattern: "*.log", mode: 'copy'
    publishDir "${params.outdir}/el_gato/assembly", pattern: "*.json", mode: 'copy'

    conda "bioconda::el_gato=1.20.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/el_gato:1.20.2--py311h7e72e81_0' :
        'biocontainers/el_gato:1.20.2--py311h7e72e81_0' }"

    input:
    tuple val(meta), path(assembly)

    output:
    tuple val(meta), path("${meta.id}_ST.tsv"), emit: report
    tuple val(meta), path("${meta.id}_run.log"), emit: log
    tuple val(meta), path("${meta.id}_assembly.json"), emit: json
    path "versions.yml", emit: versions

    script:
    """
    el_gato.py \\
        --threads $task.cpus \\
        --out out \\
        --sample ${meta.id} \\
        --header \\
        --assembly $assembly \\
    > ${meta.id}_ST.tsv

    # Rename outputs #
    mv out/run.log ${meta.id}_run.log
    mv out/report.json ${meta.id}_assembly.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        el_gato: \$(el_gato.py --version | sed 's/^el_gato version: //')
    END_VERSIONS
    """
}

process EL_GATO_REPORT {
    label 'process_low'

    publishDir "${params.outdir}/el_gato", pattern: "*.pdf", mode: 'copy'

    conda "bioconda::el_gato=1.20.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/el_gato:1.20.2--py311h7e72e81_0' :
        'biocontainers/el_gato:1.20.2--py311h7e72e81_0' }"

    input:
    path read_jsons
    path assembly_jsons

    output:
    path "*.pdf", emit: pdf
    path "versions.yml", emit: versions

    script:
    """
    elgato_report.py \\
        -i *.json \\
        -o el_gato_report.pdf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        el_gato: \$(el_gato.py --version | sed 's/^el_gato version: //')
    END_VERSIONS
    """
}

process COMBINE_EL_GATO {
    label 'process_low'

    publishDir "${params.outdir}/el_gato", pattern: "el_gato_st.tsv", mode: 'copy'

    conda "conda-forge::pandas=2.2.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:2.2.1' :
        'biocontainers/pandas:2.2.1' }"

    input:
    path reads_st
    path assembly_st

    output:
    path "el_gato_st.tsv", emit: report
    path "versions.yml", emit: versions

    script:
    def reads_arg = reads_st ? "--reads_tsv $reads_st" : ""
    def assembly_arg = assembly_st ? "--assembly_tsv $assembly_st" : ""
    """
    combine_el_gato.py \\
        $reads_arg \\
        $assembly_arg

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        combine_el_gato: 0.1.0
    END_VERSIONS
    """
}