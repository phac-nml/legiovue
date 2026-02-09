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

include {KRAKEN2_CLASSIFICATION_NANOPORE    } from '../modules/local/kraken.nf'
include {BRACKEN                            } from '../modules/local/bracken.nf'
include {NANOPLOT                           } from '../modules/local/nanoplot.nf'
include {NANOQ                              } from '../modules/local/nanoq.nf'
include {NANOPLOT_TRIMMED                   } from '../modules/local/nanoplot.nf'
include {DRAGONFLYE                         } from '../modules/local/dragonflye.nf'
include {QUAST                              } from '../modules/local/quast.nf'
include {SCORE_QUAST_NANOPORE               } from '../modules/local/quast.nf'
include {MINIMAP2_ASSEMBLY                  } from '../modules/local/assembly_quality.nf'
include {SAMTOOLS_COVERAGE_ASSEMBLY         } from '../modules/local/assembly_quality.nf'
include {EL_GATO_ASSEMBLY                   } from '../modules/local/el_gato.nf'
include {MINIMAP2_ALLELES                   } from '../modules/local/allele_quality.nf'
include {SAMTOOLS_COVERAGE_ALLELES          } from '../modules/local/allele_quality.nf'
include {PYSAMSTATS_NANOPORE                } from '../modules/local/allele_quality.nf'
include {PLOT_EL_GATO_ALLELES               } from '../modules/local/plotting.nf'
include {CHEWBBACA_PREP_EXTERNAL_SCHEMA     } from '../modules/local/chewbbaca.nf'
include {CHEWBBACA_ALLELE_CALL              } from '../modules/local/chewbbaca.nf'
include {CHEWBBACA_EXTRACT_CGMLST           } from '../modules/local/chewbbaca.nf'
include {COMBINE_SAMPLE_DATA_NANOPORE       } from '../modules/local/qc.nf'
include {CSVTK_CONCAT_QC_DATA               } from '../modules/local/csvtk.nf'
include {CUSTOM_DUMPSOFTWAREVERSIONS        } from '../modules/nf-core/custom/dumpsoftwareversions/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
INITIALIZE CHANNELS FROM PARAMS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_quast_ref = file(params.quast_ref, checkIfExists: true)
ch_kraken2_db = file(params.kraken2_db, checkIfExists: true)
ch_min_abundance = params.min_abundance
ch_quast_ref = file(params.quast_ref, checkIfExists: true)
ch_max_contigs_nanopore = params.max_contigs_nanopore
ch_min_align_percent_nanopore = params.min_align_percent_nanopore
ch_min_n50_score_nanopore = params.min_n50_score_nanopore
ch_max_n50_score_nanopore = params.max_n50_score_nanopore
ch_prepped_schema = file(params.prepped_schema, type: 'dir', checkIfExists: true)
ch_schema_targets   = params.schema_targets ? file(params.schema_targets, type: 'dir', checkIfExists: true) : []

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
RUN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow LEGIOVUE_ONT {
    take:
    nanopore

    main:
    
    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Kraken2 and Bracken Classification and Abundance Filtering
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    //run kraken2 on nanopore reads
    KRAKEN2_CLASSIFICATION_NANOPORE(
        nanopore,
        ch_kraken2_db
    )

    //run bracken on kraken2 output
    BRACKEN(
        KRAKEN2_CLASSIFICATION_NANOPORE.out.report,
        ch_kraken2_db
    )
    
    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    INITIAL READ QC AND ASSEMBLY
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    //run NanoPlot
    NANOPLOT(
        nanopore
    )

    //Nanoq to trim reads under 1000bp in length
    NANOQ(
        nanopore
    )

    //run Nanoplot on Trimmed Reads
    NANOPLOT_TRIMMED(
        NANOQ.out.trimmed_reads
    )

    //run dragonflye on Trimmed Reads
    DRAGONFLYE(
        NANOQ.out.trimmed_reads
    )

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ASSEMBLY QUALITY EVALUATION
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    //run Quast on Dragonflye assembly
    QUAST(
        DRAGONFLYE.out.assembly,
        ch_quast_ref
    )

    //run Quast scoring on Quast output
    SCORE_QUAST_NANOPORE(
        QUAST.out.report
    )

    //remove contig flags with awk to create single contig assembly
    //map trimmed reads to single contig assembly with minimap2
    MINIMAP2_ASSEMBLY(
        DRAGONFLYE.out.assembly,
        NANOQ.out.trimmed_reads
    )

    //calculate coverage with samtools
    SAMTOOLS_COVERAGE_ASSEMBLY(
        MINIMAP2_ASSEMBLY.out.assembly_sam
    )

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SBT ALLELE ASSIGNMENT AND QUALITY EVALUATION
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    //run el_gato with Dragonflye assembly
    EL_GATO_ASSEMBLY(
        DRAGONFLYE.out.assembly
    )

    //map trimmed reads to el_gato alleles with minimap2
    MINIMAP2_ALLELES(
        EL_GATO_ASSEMBLY.out.report,
        NANOQ.out.trimmed_reads
    )

    //calculate coverage with samtools
    SAMTOOLS_COVERAGE_ALLELES(
        MINIMAP2_ALLELES.out.alleles_sam
    )

    //determine per base depth and qscore for alleles with pysamstats
    PYSAMSTATS_NANOPORE(
        SAMTOOLS_COVERAGE_ALLELES.out.alleles_bam
    )

    //plot allele depth and qscore with plotting utility
    PLOT_EL_GATO_ALLELES(
        PYSAMSTATS_NANOPORE.out.allele_stats_tsv
    )

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CHEWBBACA cgMLST ANALYSIS
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    if ( params.schema_targets ){
        CHEWBBACA_PREP_EXTERNAL_SCHEMA(
            ch_schema_targets
        )
        ch_prepped_schema = CHEWBBACA_PREP_EXTERNAL_SCHEMA.out.schema
        ch_versions = ch_versions.mix(CHEWBBACA_PREP_EXTERNAL_SCHEMA.out.versions)
    }
    CHEWBBACA_ALLELE_CALL(
        DRAGONFLYE.out.assembly,
            .collect{ it[1] },
        ch_prepped_schema
    )
    ch_versions = ch_versions.mix(CHEWBBACA_ALLELE_CALL.out.versions)

    CHEWBBACA_EXTRACT_CGMLST(
        CHEWBBACA_ALLELE_CALL.out.results_alleles
    )
    ch_versions = ch_versions.mix(CHEWBBACA_EXTRACT_CGMLST.out.versions)

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    QC Collection
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    //combine QC data into single csv per sample
    COMBINE_SAMPLE_DATA_NANOPORE(
        BRACKEN.out.abundance,
        NANOPLOT.out.untrimmed_NanoStats,
        NANOPLOT_TRIMMED.out.trimmed_NanoStats,
        QUAST.out.report,
        SCORE_QUAST_NANOPORE.out.report,
        SAMTOOLS_COVERAGE_ASSEMBLY.out.assembly_coverage,
        SAMTOOLS_COVERAGE_ALLELES.out.alleles_coverage,
        EL_GATO_ASSEMBLY.out.report,
        CHEWBBACA_ALLELE_CALL.out.results_alleles
    )

    //combine all individual qc csvs into single csv for all samples
    CSVTK_CONCAT_QC_DATA(
        COMBINE_SAMPLE_DATA_NANOPORE.out.csv
    )

    CUSTOM_DUMPSOFTWAREVERSIONS(
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

}