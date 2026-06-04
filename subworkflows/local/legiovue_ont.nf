/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include {KRAKEN2_CLASSIFY_NANOPORE              } from '../../modules/local/kraken.nf'
include {BRACKEN_NANOPORE                       } from '../../modules/local/bracken.nf'
include {CREATE_ABUNDANCE_FILTER                } from '../../modules/local/utils.nf'
include {NANOPLOT                               } from '../../modules/local/nanoplot.nf'
include {NANOQ                                  } from '../../modules/local/nanoq.nf'
include {DRAGONFLYE                             } from '../../modules/local/dragonflye.nf'
include {QUAST_NANOPORE                         } from '../../modules/local/quast.nf'
include {SCORE_QUAST_NANOPORE                   } from '../../modules/local/quast.nf'
include {MINIMAP2_ASSEMBLY                      } from '../../modules/local/assembly_quality.nf'
include {SAMTOOLS_COVERAGE_ASSEMBLY             } from '../../modules/local/assembly_quality.nf'
include {EL_GATO_ASSEMBLY                       } from '../../modules/local/el_gato.nf'
include {EL_GATO_REPORT_NANOPORE                } from '../../modules/local/el_gato.nf'
include {CSVTK_CONCAT_SBT_DATA_NANOPORE         } from '../../modules/local/utils.nf'
include {MINIMAP2_ALLELES                       } from '../../modules/local/allele_quality.nf'
include {SAMTOOLS_COVERAGE_ALLELES              } from '../../modules/local/allele_quality.nf'
include {PYSAMSTATS_NANOPORE                    } from '../../modules/local/allele_quality.nf'
include {PLOT_EL_GATO_ALLELES_NANOPORE          } from '../../modules/local/plotting.nf'
include {CHEWBBACA_PREP_EXTERNAL_SCHEMA         } from '../../modules/local/chewbbaca.nf'
include {CHEWBBACA_ALLELE_CALL_NANOPORE         } from '../../modules/local/chewbbaca.nf'
include {CHEWBBACA_EXTRACT_CGMLST_NANOPORE      } from '../../modules/local/chewbbaca.nf'
include {COMBINE_SAMPLE_DATA_NANOPORE           } from '../../modules/local/qc.nf'
include {CSVTK_CONCAT_QC_DATA_NANOPORE          } from '../../modules/local/utils.nf'
include {CUSTOM_DUMPSOFTWAREVERSIONS_NANOPORE   } from '../../modules/nf-core/custom/dumpsoftwareversions/main'
include {MULTIQC_NANOPORE                       } from '../../modules/local/multiqc.nf'

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
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    INITIALIZE CHANNELS FROM PARAMS
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    ch_quast_ref                = file(params.quast_ref, checkIfExists: true)
    ch_kraken2_db               = file(params.kraken2_db, checkIfExists: true)
    ch_quast_ref                = file(params.quast_ref, checkIfExists: true)
    ch_el_gato_sbt              = params.el_gato_sbt ? file(params.el_gato_sbt, checkIfExists: true) : []
    ch_el_gato_profile          = params.el_gato_profile ? file(params.el_gato_profile, checkIfExists: true) : []
    ch_multiqc_config_nanopore  = file(params.multiqc_config_nanopore, checkIfExists:true)
    ch_prepped_schema           = file(params.prepped_schema, type: 'dir', checkIfExists: true)
    ch_schema_targets           = params.schema_targets ? file(params.schema_targets, type: 'dir', checkIfExists: true) : []

    // Empty version channel
    ch_versions = channel.empty()

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
    BRACKEN_NANOPORE(
        KRAKEN2_CLASSIFY_NANOPORE.out.report,
        ch_kraken2_db
    )
    ch_versions = ch_versions.mix(BRACKEN_NANOPORE.out.versions)

    //create abundance filter for downstream analysis
    CREATE_ABUNDANCE_FILTER(
        BRACKEN_NANOPORE.out.abundance
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
        DRAGONFLYE.out.assembly
            .collect{ it[1] },
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
    //initialize el_gato output channels to allow for conditional execution of el_gato downstream steps
    ch_nanopore_sbt = channel.value([])
    ch_allele_quality = channel.value([])

    //run el_gato with Dragonflye assembly
    if ( ! params.skip_el_gato ){
        EL_GATO_ASSEMBLY(
            DRAGONFLYE.out.assembly,
            ch_el_gato_sbt,
            ch_el_gato_profile
        )
        ch_versions = ch_versions.mix(EL_GATO_ASSEMBLY.out.versions)

        //create el_gato report with elgato_report.py
        EL_GATO_REPORT_NANOPORE(
            EL_GATO_ASSEMBLY.out.json
                .collect{ it[1] }
        )
        ch_versions = ch_versions.mix(EL_GATO_REPORT_NANOPORE.out.versions)

        //concat all el gato results into single tsv
        CSVTK_CONCAT_SBT_DATA_NANOPORE(
            EL_GATO_ASSEMBLY.out.report
                .collect{ it[1] }
        )

        //set output channel for el_gato results to allow for conditional execution
        ch_nanopore_sbt = CSVTK_CONCAT_SBT_DATA_NANOPORE.out.tsv.collect().ifEmpty([])

        //map trimmed reads to el_gato alleles with minimap2
        if ( ! params.skip_plotting ){
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

        //set output channel for allele quality to allow for conditional execution
        ch_allele_quality = SAMTOOLS_COVERAGE_ALLELES.out.alleles_coverage

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

        }

    }

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
    CHEWBBACA_ALLELE_CALL_NANOPORE(
        DRAGONFLYE.out.assembly.collect{ it[1] },
        ch_prepped_schema
    )
    ch_versions = ch_versions.mix(CHEWBBACA_ALLELE_CALL_NANOPORE.out.versions)

    CHEWBBACA_EXTRACT_CGMLST_NANOPORE(
        CHEWBBACA_ALLELE_CALL_NANOPORE.out.results_alleles
    )
    ch_versions = ch_versions.mix(CHEWBBACA_EXTRACT_CGMLST_NANOPORE.out.versions)

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    QC Collection
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    //create channels for outputs with all samples included
    ch_nanopore_quast_report     = QUAST_NANOPORE.out.report.collect().ifEmpty([])
    ch_nanopore_quast_score      = SCORE_QUAST_NANOPORE.out.report.collect().ifEmpty([])
    ch_nanopore_cgmlst_stats     = CHEWBBACA_ALLELE_CALL_NANOPORE.out.statistics.collect().ifEmpty([])

    // Group all singular inputs by sample before combining
    grouped_inputs = BRACKEN_NANOPORE.out.abundance
        .join(NANOPLOT.out.untrimmed_NanoStats)
        .join(NANOQ.out.report)
        .join(SAMTOOLS_COVERAGE_ASSEMBLY.out.assembly_coverage)
        .join(ch_allele_quality)

    //input for collection of all qc data into single csv per sample
    COMBINE_SAMPLE_DATA_NANOPORE(
        grouped_inputs,
        ch_nanopore_quast_report,
        ch_nanopore_quast_score,
        ch_nanopore_sbt,
        ch_nanopore_cgmlst_stats
    )
    ch_versions = ch_versions.mix(COMBINE_SAMPLE_DATA_NANOPORE.out.versions)

    //combine all individual qc csvs into single csv for all samples
    CSVTK_CONCAT_QC_DATA_NANOPORE(
        COMBINE_SAMPLE_DATA_NANOPORE.out.csv
            .collect{ it[1] }
    )
    ch_versions = ch_versions.mix(CSVTK_CONCAT_QC_DATA_NANOPORE.out.versions)


    CUSTOM_DUMPSOFTWAREVERSIONS_NANOPORE(
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    MultiQC Summary HTML
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    MULTIQC_NANOPORE(
        ch_multiqc_config_nanopore,
        NANOPLOT.out.untrimmed_NanoStats
            .collect{ it[1] },
        SCORE_QUAST_NANOPORE.out.report
            .ifEmpty([]),
        ch_nanopore_sbt
            .ifEmpty([]),
        BRACKEN_NANOPORE.out.breakdown
            .collect{ it[1] },
        NANOQ.out.report
            .collect{ it[1] },
        CHEWBBACA_ALLELE_CALL_NANOPORE.out.statistics
            .ifEmpty([]),
        CSVTK_CONCAT_QC_DATA_NANOPORE.out.csv
            .ifEmpty([]),
        CUSTOM_DUMPSOFTWAREVERSIONS_NANOPORE.out.mqc_yml
    )
    ch_versions = ch_versions.mix(MULTIQC_NANOPORE.out.versions)
}
