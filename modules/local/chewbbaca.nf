process CHEWBBACA_PREP_EXTERNAL_SCHEMA {
    label 'process_low'

    publishDir "${params.outdir}/chewbbaca", pattern: "prepped_schema", mode: 'copy'

    conda "bioconda::chewbbaca=3.3.5"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/chewbbaca:3.3.5--pyhdfd78af_0':
        'biocontainers/chewbbaca:3.3.5--pyhdfd78af_0' }"

    input:
    path targets

    output:
    path "prepped_schema", emit: schema
    path "versions.yml", emit: versions

    script:
    """
    chewBBACA.py \\
        PrepExternalSchema \\
        -g $targets \\
        -o prepped_schema \\
        --cpu ${task.cpus}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        chewbbaca: \$(echo \$(chewBBACA.py --version 2>&1 | sed 's/^.*chewBBACA version: //g; s/Using.*\$//' ))
    END_VERSIONS
    """
}

process CHEWBBACA_ALLELE_CALL {
    label 'process_medium'

    publishDir "${params.outdir}/chewbbaca", pattern: "allele_calls", mode: 'copy'

    conda "bioconda::chewbbaca=3.3.5"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/chewbbaca:3.3.5--pyhdfd78af_0':
        'biocontainers/chewbbaca:3.3.5--pyhdfd78af_0' }"

    input:
    path assemblies
    path schema

    output:
    path "allele_calls", emit: allele_calls
    path "allele_calls/results_statistics.tsv", emit: statistics
    path "versions.yml", emit: versions

    script:
    """
    # Move all assemblies to a directory
    mkdir -p assemblies
    mv $assemblies assemblies/

    # Run chewBBACA with no-inferred to not affect schema
    chewBBACA.py \\
        AlleleCall \\
        -i assemblies \\
        -g $schema \\
        --no-inferred \\
        -o allele_calls \\
        --cpu ${task.cpus}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        chewbbaca: \$(echo \$(chewBBACA.py --version 2>&1 | sed 's/^.*chewBBACA version: //g; s/Using.*\$//' ))
    END_VERSIONS
    """
}

process CHEWBBACA_EXTRACT_CGMLST {
    label 'process_low'

    publishDir "${params.outdir}/chewbbaca/$allele_calls", pattern: "cgMLST", mode: 'copy'

    conda "bioconda::chewbbaca=3.3.5"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/chewbbaca:3.3.5--pyhdfd78af_0':
        'biocontainers/chewbbaca:3.3.5--pyhdfd78af_0' }"

    input:
    path allele_calls

    output:
    path "cgMLST", emit: cgmlst
    path "versions.yml", emit: versions

    script:
    """
    chewBBACA.py \\
        ExtractCgMLST \\
        -i $allele_calls/results_alleles.tsv \\
        -o cgMLST

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        chewbbaca: \$(echo \$(chewBBACA.py --version 2>&1 | sed 's/^.*chewBBACA version: //g; s/Using.*\$//' ))
    END_VERSIONS
    """
}
