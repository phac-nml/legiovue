process CHEWBBACA_PREP_EXTERNAL_SCHEMA {
    label 'process_low'

    conda "bioconda::chewbbaca=3.3.5"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/chewbbaca:3.3.5--pyhdfd78af_0':
        'biocontainers/chewbbaca:3.3.5--pyhdfd78af_0' }"

    input:
    path targets

    output:
    path "prepped_schema", emit: schema
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

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

    stub:
    """
    mkdir prepped_schema

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        chewbbaca: \$(echo \$(chewBBACA.py --version 2>&1 | sed 's/^.*chewBBACA version: //g; s/Using.*\$//' ))
    END_VERSIONS
    """
}

process CHEWBBACA_ALLELE_CALL {
    label 'process_medium'

    conda "bioconda::chewbbaca=3.3.5"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/chewbbaca:3.3.5--pyhdfd78af_0':
        'biocontainers/chewbbaca:3.3.5--pyhdfd78af_0' }"

    input:
    path assemblies
    path schema

    output:
    path "allele_calls/results_alleles.tsv", emit: results_alleles
    path "allele_calls/results_statistics.tsv", emit: statistics
    path "allele_calls/cds_coordinates.tsv", emit: cds_coords
    path "allele_calls/loci_summary_stats.tsv", emit: loci_summary
    path "allele_calls/paralogous_counts.tsv", emit: paralogous_counts
    path "allele_calls/paralogous_loci.tsv", emit: paralogous_loci
    path "allele_calls/results_contigsInfo.tsv", emit: contig_info
    path "allele_calls/*.txt", emit: allele_call_txt
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

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

    stub:
    """
    mkdir allele_calls
    touch allele_calls/results_statistics.tsv
    touch allele_calls/results_alleles.tsv
    touch allele_calls/cds_coordinates.tsv
    touch allele_calls/loci_summary_stats.tsv
    touch allele_calls/paralogous_counts.tsv
    touch allele_calls/paralogous_loci.tsv
    touch allele_calls/results_contigsInfo.tsv
    touch allele_calls/invalid_cds.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        chewbbaca: \$(echo \$(chewBBACA.py --version 2>&1 | sed 's/^.*chewBBACA version: //g; s/Using.*\$//' ))
    END_VERSIONS
    """
}

process CHEWBBACA_EXTRACT_CGMLST {
    label 'process_low'

    conda "bioconda::chewbbaca=3.3.5"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/chewbbaca:3.3.5--pyhdfd78af_0':
        'biocontainers/chewbbaca:3.3.5--pyhdfd78af_0' }"

    input:
    path results_alleles

    output:
    path "cgMLST/*", emit: cgmlst
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    chewBBACA.py \\
        ExtractCgMLST \\
        -i $results_alleles \\
        -o cgMLST

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        chewbbaca: \$(echo \$(chewBBACA.py --version 2>&1 | sed 's/^.*chewBBACA version: //g; s/Using.*\$//' ))
    END_VERSIONS
    """

    stub:
    """
    mkdir cgMLST
    touch cgMLST/cgMLST99.tsv
    touch cgMLST/cgMLST100.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        chewbbaca: \$(echo \$(chewBBACA.py --version 2>&1 | sed 's/^.*chewBBACA version: //g; s/Using.*\$//' ))
    END_VERSIONS
    """
}
