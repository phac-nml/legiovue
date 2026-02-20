#!/usr/bin/env nextflow
process DRAGONFLYE {
    label 'process_medium'

    conda "bioconda::dragonflye=1.2.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/dragonflye:1.2.1--hdfd78af_0' :
        'biocontainers/dragonflye:1.2.1--hdfd78af_0' }"

    publishDir '3.Dragonflye_Assembly', mode: 'copy'

    input: 
        tuple val(meta), path(trimmed_reads) 

    output: 
        tuple val(meta), path("./${meta.id}.fasta"), emit: assembly
        tuple val(meta), path("./${meta.id}_dragonflye.log"), emit: log
        path "versions.yml", emit: versions
    
    script:
    """
    dragonflye \\
        --depth 0 \\
        --gsize 3.5M \\
        --reads $trimmed_reads \\
        --outdir ./out/ \\
        --force \\
    && \\
    cp \\
        ./out/contigs.reoriented.fa \\
        ./${meta.id}.fasta \\
    && \\
    cp \\
        ./out/dragonflye.log \\
        ./${meta.id}_dragonflye.log \\

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dragonflye: \$(echo \$(dragonflye --version 2>&1 | sed 's/^.*dragonflye //' ))
    END_VERSIONS
    """
}