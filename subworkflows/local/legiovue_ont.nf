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
include {ASSEMBLY_DEPTH                     } from './modules/local/Assembly_Depth.nf' // To Do
include {EL_GATO_ASSEMBLY                   } from './modules/local/el_gato.nf' // use existing 
include {ALLELE_DEPTH                       } from './modules/local/Allele_Depth.nf' // To Do
include {NANOPORE_QC_COLLECTION             } from './modules/local/Nanopore_QC_Collection.nf' // To Do
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
    
    //run NanoPlot
    NANOPLOT(ch_nanopore_fastqs)

    //create Nanoq to trim reads
    NANOQ(ch_nanopore_fastqs)

    //run Nanoplot on Trimmed Reads
    NANOPLOT_TRIMMED(NANOQ.out.trimmed_reads)

    //run dragonflye on Trimmed Reads
    DRAGONFLYE(NANOQ.out.trimmed_reads)

    //run Quast on Dragonflye assembly
    QUAST(DRAGONFLYE.out.assembly, ch_quast_ref)

    //run Quast scoring on Quast output
    SCORE_QUAST(QUAST.out.report)

    //run Assembly_Depth on Dragonflye assembly and Trimmed Reads
    ASSEMBLY_DEPTH(DRAGONFLYE.out.assembly, NANOQ.out.trimmed_reads)

    //run el_gato with Dragonflye assembly
    EL_GATO(DRAGONFLYE.out.assembly)

    //run Allele_Depth on El_gato alleles and Trimmed reads
    ALLELE_DEPTH(EL_GATO.out.identified_alleles, NANOQ.out.trimmed_reads)

    //Collect QC Data
    NANOPORE_QC_COLLECTION(NANOPLOT.out.untrimmed_NanoStats, NANOPLOT_TRIMMED.out.trimmed_NanoStats, QUAST.out.report, ASSEMBLY_DEPTH.out, ALLELE_DEPTH.out, SCORE_QUAST.out.report)
}