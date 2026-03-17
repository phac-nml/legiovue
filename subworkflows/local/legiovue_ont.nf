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

include {KRAKEN2_CLASSIFY_NANOPORE          } from '../../modules/local/kraken.nf'
include {BRACKEN                            } from '../../modules/local/bracken.nf'
include {CREATE_ABUNDANCE_FILTER            } from '../../modules/local/utils.nf'
include {NANOPLOT                           } from '../../modules/local/nanoplot.nf'
include {NANOQ                              } from '../../modules/local/nanoq.nf'
include {NANOPLOT_TRIMMED                   } from '../../modules/local/nanoplot.nf'
include {DRAGONFLYE                         } from '../../modules/local/dragonflye.nf'
include {QUAST_NANOPORE                     } from '../../modules/local/quast.nf'
include {SCORE_QUAST_NANOPORE               } from '../../modules/local/quast.nf'
include {MINIMAP2_ASSEMBLY                  } from '../../modules/local/assembly_quality.nf'
include {SAMTOOLS_COVERAGE_ASSEMBLY         } from '../../modules/local/assembly_quality.nf'
include {EL_GATO_ASSEMBLY                   } from '../../modules/local/el_gato.nf'
include {EL_GATO_REPORT                     } from '../../modules/local/el_gato.nf'
include {MINIMAP2_ALLELES                   } from '../../modules/local/allele_quality.nf'
include {SAMTOOLS_COVERAGE_ALLELES          } from '../../modules/local/allele_quality.nf'
include {PYSAMSTATS_NANOPORE                } from '../../modules/local/allele_quality.nf'
include {PLOT_EL_GATO_ALLELES_NANOPORE      } from '../../modules/local/plotting.nf'
include {CHEWBBACA_PREP_EXTERNAL_SCHEMA     } from '../../modules/local/chewbbaca.nf'
include {CHEWBBACA_ALLELE_CALL              } from '../../modules/local/chewbbaca.nf'
include {CHEWBBACA_EXTRACT_CGMLST           } from '../../modules/local/chewbbaca.nf'
include {COMBINE_SAMPLE_DATA_NANOPORE       } from '../../modules/local/qc.nf'
include {CSVTK_CONCAT_QC_DATA               } from '../../modules/local/utils.nf'
include {CUSTOM_DUMPSOFTWAREVERSIONS        } from '../../modules/nf-core/custom/dumpsoftwareversions/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
INITIALIZE CHANNELS FROM PARAMS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_quast_ref = file(params.quast_ref, checkIfExists: true)
ch_kraken2_db = file(params.kraken2_db, checkIfExists: true)
ch_quast_ref = file(params.quast_ref, checkIfExists: true)
ch_prepped_schema = file(params.prepped_schema, type: 'dir', checkIfExists: true)
ch_schema_targets   = params.schema_targets ? file(params.schema_targets, type: 'dir', checkIfExists: true) : []

// Empty version channel
ch_versions = Channel.empty()

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
    KRAKEN2_CLASSIFY_NANOPORE(
        nanopore,
        ch_kraken2_db
    )
    ch_versions = ch_versions.mix(KRAKEN2_CLASSIFY_NANOPORE.out.versions)

    //run bracken on kraken2 output
    BRACKEN(
        KRAKEN2_CLASSIFY_NANOPORE.out.report,
        ch_kraken2_db
    )
    ch_versions = ch_versions.mix(BRACKEN.out.versions)

    //create abundance filter for downstream analysis
    CREATE_ABUNDANCE_FILTER(
        BRACKEN.out.abundance
    )
    ch_versions = ch_versions.mix(CREATE_ABUNDANCE_FILTER.out.versions)

    //split samples into pass and fail based on abundance filter results
    CREATE_ABUNDANCE_FILTER.out.abundance_check
        .splitCsv(header:true, sep:',')
        .branch{ meta, row ->
            pass: row.pass == 'YES'
                return meta                     // To join the passing fastqs on
            fail: true
                return tuple(meta, [])          // To allow tracking samples failures later on
        }.set{ ch_abundance_filter }
    
    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    INITIAL READ QC AND ASSEMBLY
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    //run NanoPlot
    NANOPLOT(
        ch_abundance_filter.pass
            .join(nanopore, by: [0])
    )
    ch_versions = ch_versions.mix(NANOPLOT.out.versions)

    //Nanoq to trim reads under 1000bp in length
    NANOQ(
        ch_abundance_filter.pass
            .join(nanopore, by: [0])
    )
    ch_versions = ch_versions.mix(NANOQ.out.versions)

    //run Nanoplot on Trimmed Reads
    NANOPLOT_TRIMMED(
        NANOQ.out.trimmed_reads
    )
    ch_versions = ch_versions.mix(NANOPLOT_TRIMMED.out.versions)

    //run dragonflye on Trimmed Reads
    DRAGONFLYE(
        NANOQ.out.trimmed_reads
    )
    ch_versions = ch_versions.mix(DRAGONFLYE.out.versions)

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ASSEMBLY QUALITY EVALUATION
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    //run Quast on Dragonflye assembly
    QUAST_NANOPORE(
        DRAGONFLYE.out.assembly,
        ch_quast_ref
    )
    ch_versions = ch_versions.mix(QUAST_NANOPORE.out.versions)

    //run Quast scoring on Quast output
    SCORE_QUAST_NANOPORE(
        QUAST_NANOPORE.out.report
    )
    ch_versions = ch_versions.mix(SCORE_QUAST_NANOPORE.out.versions)

    //remove contig flags with awk to create single contig assembly
    //map trimmed reads to single contig assembly with minimap2
    MINIMAP2_ASSEMBLY(
        DRAGONFLYE.out.assembly,
        NANOQ.out.trimmed_reads
    )
    ch_versions = ch_versions.mix(MINIMAP2_ASSEMBLY.out.versions)

    //calculate coverage with samtools
    SAMTOOLS_COVERAGE_ASSEMBLY(
        MINIMAP2_ASSEMBLY.out.assembly_sam
    )
    ch_versions = ch_versions.mix(SAMTOOLS_COVERAGE_ASSEMBLY.out.versions)

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SBT ALLELE ASSIGNMENT AND QUALITY EVALUATION
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    //run el_gato with Dragonflye assembly
    EL_GATO_ASSEMBLY(
        DRAGONFLYE.out.assembly
    )
    ch_versions = ch_versions.mix(EL_GATO_ASSEMBLY.out.versions)

    EL_GATO_REPORT(
        EL_GATO_ASSEMBLY.out.json
    )
    ch_versions = ch_versions.mix(EL_GATO_REPORT.out.versions)

    //map trimmed reads to el_gato alleles with minimap2
    MINIMAP2_ALLELES(
        EL_GATO_ASSEMBLY.out.alleles,
        NANOQ.out.trimmed_reads
    )
    ch_versions = ch_versions.mix(MINIMAP2_ALLELES.out.versions)

    //calculate coverage with samtools
    SAMTOOLS_COVERAGE_ALLELES(
        MINIMAP2_ALLELES.out.alleles_sam
    )
    ch_versions = ch_versions.mix(SAMTOOLS_COVERAGE_ALLELES.out.versions)

    //determine per base depth and qscore for alleles with pysamstats
    PYSAMSTATS_NANOPORE(
        SAMTOOLS_COVERAGE_ALLELES.out.alleles_bam
    )
    ch_versions = ch_versions.mix(PYSAMSTATS_NANOPORE.out.versions)

    //plot allele depth and qscore with plotting utility
    PLOT_EL_GATO_ALLELES_NANOPORE(
        PYSAMSTATS_NANOPORE.out.allele_stats_tsv
    )
    ch_versions = ch_versions.mix(PLOT_EL_GATO_ALLELES_NANOPORE.out.versions)

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
        DRAGONFLYE.out.assembly.collect{ it[1] },
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
        QUAST_NANOPORE.out.report,
        SCORE_QUAST_NANOPORE.out.report,
        SAMTOOLS_COVERAGE_ASSEMBLY.out.assembly_coverage,
        SAMTOOLS_COVERAGE_ALLELES.out.alleles_coverage,
        EL_GATO_ASSEMBLY.out.report,
        CHEWBBACA_ALLELE_CALL.out.statistics
    )
    ch_versions = ch_versions.mix(COMBINE_SAMPLE_DATA_NANOPORE.out.versions)

    //combine all individual qc csvs into single csv for all samples
    CSVTK_CONCAT_QC_DATA(
        COMBINE_SAMPLE_DATA_NANOPORE.out.csv
            .collect{ it[1] }
    )
    ch_versions = ch_versions.mix(CSVTK_CONCAT_QC_DATA.out.versions)


    CUSTOM_DUMPSOFTWAREVERSIONS(
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

}