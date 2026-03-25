process EL_GATO_READS {
    tag "$meta.id"
    label 'process_medium'

    conda "${params.el_gato_conda_build}"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        params.el_gato_singularity_container :
        params.el_gato_docker_container }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("${meta.id}_ST.tsv"), emit: report
    tuple val(meta), path("${meta.id}*.bam"), path("${meta.id}*.bam.bai"), optional: true, emit: bam_bai
    tuple val(meta), path("${meta.id}_possible_mlsts.txt"), optional: true, emit: possible_mlsts
    tuple val(meta), path("${meta.id}_run.log"), emit: log
    tuple val(meta), path("${meta.id}_reads.json"), emit: json
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def reads_in = "--read1 ${reads[0]} --read2 ${reads[1]}"
    """
    el_gato.py \\
        --threads $task.cpus \\
        --out out \\
        --sample ${meta.id} \\
        --header \\
        ${params.el_gato_sbt_path ? "--sbt " + params.el_gato_sbt_path : ""} \\
        ${params.el_gato_allele_profiles_path ? "--allele-profiles " + params.el_gato_allele_profiles_path : ""} \\
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

    cat << END_VERSIONS > versions.yml
    "${task.process}":
        el_gato: \$(el_gato.py --version | sed 's/^el_gato version: //')
        el_gato_sbt_name: ${params.el_gato_sbt_name}
    END_VERSIONS
    """

    stub:
    """
    # Due to splitCSV have to actually have a CSV in stub
    echo "Sample	ST	flaA	pilE	asd	mip	mompS	proA	neuA_neuAH" > ${meta.id}_ST.tsv
    echo "${meta.id}	MD-	-	-	-	-	-	-	-" >> ${meta.id}_ST.tsv

    touch ${meta.id}.bam
    touch ${meta.id}.bam.bai
    touch ${meta.id}_possible_mlsts.txt
    touch ${meta.id}_run.log
    touch ${meta.id}_reads.json

    cat << END_VERSIONS > versions.yml
    "${task.process}":
        el_gato: \$(el_gato.py --version | sed 's/^el_gato version: //')
        el_gato_sbt_name: ${params.el_gato_sbt_name}
    END_VERSIONS
    """
}

process EL_GATO_ASSEMBLY {
    tag "$meta.id"
    label 'process_low'
    // Non-legionella or really low cov assemblies explode here otherwise
    //  Due to an issue in el_gato with samples that can't find any loci
    label 'error_ignore'

    conda "${params.el_gato_conda_build}"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        params.el_gato_singularity_container :
        params.el_gato_docker_container }"

    input:
    tuple val(meta), path(assembly)

    output:
    tuple val(meta), path("${meta.id}_ST.tsv"), emit: report
    tuple val(meta), path("${meta.id}_run.log"), emit: log
    tuple val(meta), path("${meta.id}_assembly.json"), emit: json
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    el_gato.py \\
        --threads $task.cpus \\
        --out out \\
        --sample ${meta.id} \\
        --header \\
        ${params.el_gato_sbt_path ? "--sbt " + params.el_gato_sbt_path : ""} \\
        ${params.el_gato_allele_profiles_path ? "--allele-profiles " + params.el_gato_allele_profiles_path : ""} \\        -- sbt SBT \\
        --assembly $assembly \\
    > ${meta.id}_ST.tsv

    # Rename outputs #
    mv out/run.log ${meta.id}_run.log
    mv out/report.json ${meta.id}_assembly.json

    cat << END_VERSIONS > versions.yml
    "${task.process}":
        el_gato: \$(el_gato.py --version | sed 's/^el_gato version: //')
        el_gato_sbt_name: ${params.el_gato_sbt_name}
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}_ST.tsv
    touch ${meta.id}_run.log
    touch ${meta.id}_assembly.json


    cat << END_VERSIONS > versions.yml
    "${task.process}":
        el_gato: \$(el_gato.py --version | sed 's/^el_gato version: //')
        el_gato_sbt_name: ${params.el_gato_sbt_name}
    END_VERSIONS
    """
}

process EL_GATO_REPORT {
    label 'process_low'

    conda "${params.el_gato_conda_build}"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        params.el_gato_singularity_container :
        params.el_gato_docker_container }"

    input:
    path read_jsons
    path assembly_jsons

    output:
    path "*.pdf", emit: pdf
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    elgato_report.py \\
        -i *.json \\
        -o el_gato_report.pdf

    cat << END_VERSIONS > versions.yml
    "${task.process}":
        el_gato: \$(el_gato.py --version | sed 's/^el_gato version: //')
        el_gato_sbt_name: ${params.el_gato_sbt_name}
    END_VERSIONS
    """    

    stub:
    """
    touch el_gato_report.pdf

    cat << END_VERSIONS > versions.yml
    "${task.process}":
        el_gato: \$(el_gato.py --version | sed 's/^el_gato version: //')
        el_gato_sbt_name: ${params.el_gato_sbt_name}
    END_VERSIONS
    """
}

process COMBINE_EL_GATO {
    label 'process_low'

    conda "${params.el_gato_pandas_conda_build}"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        params.el_gato_pandas_singularity_container :
        params.el_gato_pandas_docker_container }"

    input:
    path reads_st
    path assembly_st

    output:
    path "el_gato_st.tsv", emit: report
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

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

    stub:
    """
    touch el_gato_st.tsv
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        combine_el_gato: 0.1.0
    END_VERSIONS
    """
}
