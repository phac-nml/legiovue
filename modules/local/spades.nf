process SPADES {
    tag "$meta.id"
    label 'process_high'

    publishDir "${params.outdir}/spades", pattern: "*.fa", mode: 'copy'
    publishDir "${params.outdir}/spades", pattern: "*.log", mode: 'copy'

    conda "bioconda::spades=4.0.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/spades:4.0.0--h5fb382e_1' :
        'biocontainers/spades:4.0.0--h5fb382e_1' }"

    input:
    tuple val(meta), path(reads_paired), path(reads_single)

    output:
    tuple val(meta), path('*.scaffolds.fa'), optional:true, emit: scaffolds
    tuple val(meta), path('*.contigs.fa'), optional:true, emit: contigs
    tuple val(meta), path('*.warnings.log'), optional:true, emit: warnings
    tuple val(meta), path('*.spades.log'), emit: log
    path "versions.yml", emit: versions

    script:
    def reads_paired_in = "-1 ${reads_paired[0]} -2 ${reads_paired[1]}"
    def reads_unpaired_in = "--s1 ${reads_single[0]} --s2 ${reads_single[1]}"
    """
    # We found that using --careful works best for Legionella
    spades.py \\
        --threads $task.cpus \\
        $reads_paired_in \\
        $reads_unpaired_in \\
        --careful \\
        -o ./

    # Output naming
    mv spades.log ${meta.id}.spades.log

    if [ -f scaffolds.fasta ]; then
        mv scaffolds.fasta ${meta.id}.scaffolds.fa
    fi

    if [ -f contigs.fasta ]; then
        mv contigs.fasta ${meta.id}.contigs.fa
    fi

    if [ -f warnings.log ]; then
        mv warnings.log ${meta.id}.warnings.log
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        spades: \$(spades.py --version 2>&1 | sed -n 's/^.*SPAdes genome assembler v//p')
    END_VERSION
    """
}
