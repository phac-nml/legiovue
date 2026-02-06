#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PIPELINE PARAMETERS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
params.fastq_dir = "./"
params.input = "samples.csv"

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include {NANOPLOT                           } from './modules/local/nanoplot.nf' //Initial commit
include {NANOQ                              } from './modules/local/nanoq.nf' //Initial commit
include {NANOPLOT_TRIMMED                   } from './modules/local/nanoplot.nf' //Initial commit
include {KRAKEN2_CLASSIFICATION_NANOPORE    } from './modules/local/kraken.nf' // Initial commit, modified for nanopore
include {DRAGONFLYE                         } from './modules/local/dragonflye.nf' //Initial commit
include {QUAST                              } from './modules/local/quast.nf' // use existing, confirm input/output
include {SCORE_QUAST_NANOPORE               } from './modules/local/quast.nf' // Initial commit, modified for nanopore
include {MINIMAP2_ASSEMBLY                  } from './modules/local/assembly_quality.nf' // Initial commit
include {SAMTOOLS_COVERAGE_ASSEMBLY         } from './modules/local/assembly_quality.nf' // Initial commit
include {EL_GATO_ASSEMBLY                   } from './modules/local/el_gato.nf' // use existing 
include {MINIMAP2_ALLELES                   } from './modules/local/allele_quality.nf' // Initial commit
include {SAMTOOLS_COVERAGE_ALLELES          } from './modules/local/allele_quality.nf' // Initial commit
include {PYSAMSTATS_NANOPORE                } from './modules/local/allele_quality.nf' // Initial commit
include {PLOT_EL_GATO_ALLELES               } from './modules/local/plotting.nf' // use existing

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
INITIALIZE CHANNELS FROM PARAMS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_quast_ref = file(params.quast_ref, checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
RUN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow LEGIOVUE_ONT {
    take:
    ch_nanopore_fastqs

    main: 
    
    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    INITIAL READ QC AND ASSEMBLY
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    //run NanoPlot
    NANOPLOT(ch_nanopore_fastqs)

    //create Nanoq to trim reads
    NANOQ(ch_nanopore_fastqs)

    //run Nanoplot on Trimmed Reads
    NANOPLOT_TRIMMED(NANOQ.out.trimmed_reads)

    //run dragonflye on Trimmed Reads
    DRAGONFLYE(NANOQ.out.trimmed_reads)

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ASSEMBLY QUALITY EVALUATION
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    //run Quast on Dragonflye assembly
    QUAST(DRAGONFLYE.out.assembly, ch_quast_ref)

    //run Quast scoring on Quast output
    SCORE_QUAST(QUAST.out.report)

    //remove contig flags with awk map trimmed reads to single contig assembly with minimap2
    MINIMAP2_ASSEMBLY(ch_assembly, ch_trimmed_reads)

    //calculate coverage with samtools
    SAMTOOLS_COVERAGE_ASSEMBLY(MINIMAP2.out.assembly_sam)

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SBT ALLELE ASSIGNMENT AND QUALITY EVALUATION
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    //run el_gato with Dragonflye assembly
    EL_GATO(DRAGONFLYE.out.assembly)

    //map trimmed reads to el_gato alleles with minimap2
    MINIMAP2_ALLELES(ch_alleles, ch_trimmed_reads)

    //calculate coverage with samtools
    SAMTOOLS_COVERAGE_ALLELES(MINIMAP2_ALLELES.out.alleles_sam)

    //determine per base depth and qscore for alleles with pysamstats
    PYSAMSTATS_NANOPORE(SAMTOOLS_COVERAGE_ALLELES.out.alleles_bam)

    //plot allele depth and qscore with plotting utility
    PLOT_EL_GATO_ALLELES(PYSAMSTATS_NANOPORE.out.allele_stats_tsv)

}