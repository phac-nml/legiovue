/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { KRAKEN2_CLASSIFY                  } from '../modules/local/kraken.nf'
include { BRACKEN                           } from '../modules/local/bracken.nf'
include { CREATE_ABUNDANCE_FILTER           } from '../modules/local/utils.nf'
include { TRIMMOMATIC                       } from '../modules/local/trimmomatic.nf'
include { FASTQC                            } from '../modules/nf-core/fastqc'
include { SPADES                            } from '../modules/local/spades.nf'
include { QUAST                             } from '../modules/local/quast.nf'
include { SCORE_QUAST                       } from '../modules/local/quast.nf'
include { EL_GATO_READS                     } from '../modules/local/el_gato.nf'
include { EL_GATO_ASSEMBLY                  } from '../modules/local/el_gato.nf'
include { COMBINE_EL_GATO                   } from '../modules/local/el_gato.nf'
include { EL_GATO_REPORT                    } from '../modules/local/el_gato.nf'
include { CHEWBBACA_PREP_EXTERNAL_SCHEMA    } from '../modules/local/chewbbaca.nf'
include { CHEWBBACA_ALLELE_CALL             } from '../modules/local/chewbbaca.nf'
include { CHEWBBACA_EXTRACT_CGMLST          } from '../modules/local/chewbbaca.nf'
include { PYSAMSTATS as PYSAMSTATS_MAPQ     } from '../modules/local/pysamstats.nf'
include { PYSAMSTATS as PYSAMSTATS_BASEQ    } from '../modules/local/pysamstats.nf'
include { CSVTK_COMBINE_STATS               } from '../modules/local/utils.nf'
include { PLOT_PYSAMSTATS_TSV               } from '../modules/local/plotting.nf'
include { COMBINE_SAMPLE_DATA               } from '../modules/local/qc.nf'
include { CSVTK_COMBINE                     } from '../modules/local/utils.nf'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    INITIALIZE CHANNELS FROM PARAMS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
ch_kraken2_db       = file(params.kraken2_db, checkIfExists: true)
ch_quast_ref        = file(params.quast_ref, checkIfExists: true)
ch_prepped_schema   = file(params.prepped_schema, type: 'dir', checkIfExists: true)
ch_schema_targets   = params.schema_targets ? file(params.schema_targets, type: 'dir', checkIfExists: true) : []
// ch_metadata         = params.metadata ? file(params.metadata, checkIfExists: true) : []

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
workflow LEGIOVUE {
    take:
    ch_paired_fastqs       // channel: [ val(meta), [ file(fastq_1), file(fastq_2) ] ]

    main:
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ //
    // 1. Kraken and Bracken Check with maybe(?) Host Removal (TODO)
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ //
    // Classification and Abundance
    KRAKEN2_CLASSIFY(
        ch_paired_fastqs,
        ch_kraken2_db
    )
    BRACKEN(
        KRAKEN2_CLASSIFY.out.report,
        ch_kraken2_db
    )

    // Remove NON L.pn samples to allow good clustering
    //  This is a temp python/process solution until we
    //  decide we want to figure out the nextflow operator/
    //  groovy steps needed to do it /shrug
    CREATE_ABUNDANCE_FILTER(
        BRACKEN.out.abundance
    )
    CREATE_ABUNDANCE_FILTER.out.abundance_check
        .splitCsv(header:true, sep:',')
        .branch{ meta, row ->
            pass: row.pass == 'YES'
                return meta                     // To join the passing fastqs on
            fail: true
                return tuple(meta, [])          // To allow tracking samples failures later on
        }.set{ ch_abundance_filter }

    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ //
    // 2. Trimmomatic
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ //
    // Initial filter for read count
    //  Just use R1 fastq count as even if there are a lot of singletons in
    //  it or its missing some after trimming those will be rechecked
    TRIMMOMATIC(
        ch_abundance_filter.pass
            .join(ch_paired_fastqs, by: [0])
    )

    // Filter by min count
    TRIMMOMATIC.out.trimmed_reads
        .branch{
            pass: it[1][1].countFastq() >= params.min_reads
            fail: true
        }.set{ ch_filtered_paired_fastqs }

    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ //
    // 3. FastQC
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ //
    FASTQC(
        ch_filtered_paired_fastqs.pass
    )

    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ //
    // 4. SPAdes
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ //
    SPADES(
        ch_filtered_paired_fastqs.pass
            .join(TRIMMOMATIC.out.unpaired_reads, by: [0])
    )

    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ //
    // 5. Quast
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ //
    QUAST(
        SPADES.out.contigs
            .collect{ it[1] },
        ch_quast_ref
    )
    SCORE_QUAST(
        QUAST.out.report
    )

    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ //
    // 6. El_Gato - Second round with assemblies for failing samples only
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ //
    if ( ! params.skip_el_gato ){
        EL_GATO_READS(
            ch_filtered_paired_fastqs.pass
        )

        // El_gato consensus is only for samples where the reads output an
        //  inconclusive ST as it has been found to potentially call one
        EL_GATO_READS.out.report
            .splitCsv(header:true, sep:'\t')
            .branch{ meta, row ->
                rerun: row.ST in ['MD-', 'MA?']
                assigned: true
            }.set{ rerun_samples }

        EL_GATO_ASSEMBLY(
            rerun_samples.rerun
                .map{ it -> it[0] }
                .join(SPADES.out.contigs, by:[0])
        )

        // Combine and add in the approach used
        COMBINE_EL_GATO(
            EL_GATO_READS.out.report
                .map{ it[1] }
                .collectFile(name: 'read_st.tsv', keepHeader: true),
            EL_GATO_ASSEMBLY.out.report
                .map{ it[1] }
                .collectFile(name: 'assembly_st.tsv', keepHeader: true)
                .ifEmpty([])
        )

        // PDF Report
        //  Have to rejoin the el_gato reads output as its hard to remake a csv
        //  file from the splitCsv output from my current understanding
        EL_GATO_REPORT(
            EL_GATO_READS.out.json
                .collect{ it[1] },
            EL_GATO_ASSEMBLY.out.json
                .collect{ it[1] }
                .ifEmpty([])
        )

        // Alleles Stats with pysamstats and plots
        //  Visualize the called alleles to help
        //  investigate potential issue calls
        PYSAMSTATS_MAPQ(
            EL_GATO_READS.out.bam_bai,
            "mapq"
        )
        PYSAMSTATS_BASEQ(
            EL_GATO_READS.out.bam_bai,
            "baseq"
        )
        CSVTK_COMBINE_STATS(
            PYSAMSTATS_MAPQ.out.tsv
                .join(PYSAMSTATS_BASEQ.out.tsv, by:[0])
        )
        PLOT_PYSAMSTATS_TSV(
            CSVTK_COMBINE_STATS.out.tsv
        )
    }

    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ //
    // 7. Chewbacca cgMLST
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ //
    if ( params.schema_targets ){
        CHEWBBACA_PREP_EXTERNAL_SCHEMA(
            ch_schema_targets
        )
        ch_prepped_schema = CHEWBBACA_PREP_EXTERNAL_SCHEMA.out.schema
    }
    CHEWBBACA_ALLELE_CALL(
        SPADES.out.contigs
            .collect{ it[1] },
        ch_prepped_schema
    )
    CHEWBBACA_EXTRACT_CGMLST(
        CHEWBBACA_ALLELE_CALL.out.allele_calls
    )

    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ //
    // 8. QC + Summaries
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ //
    // To track the non-Lp failing samples have to mix in abundance filter fail
    //  It was reformatted earlier to match the [ val(meta), file() ]
    //  structure of the trimmomatic summary output
    ch_trimmomatic      = TRIMMOMATIC.out.summary.mix(ch_abundance_filter.fail)

    // Create some value channels using `.collect()`
    ch_quast_report     = QUAST.out.report.collect().ifEmpty([])
    ch_quast_score      = SCORE_QUAST.out.report.collect().ifEmpty([])
    ch_el_gato_report   = COMBINE_EL_GATO.out.report.collect().ifEmpty([])
    ch_quast_report     = QUAST.out.report.collect().ifEmpty([])
    ch_allele_stats     = CHEWBBACA_ALLELE_CALL.out.statistics.collect().ifEmpty([])

    // Single QC and then Summary QC
    COMBINE_SAMPLE_DATA(
        BRACKEN.out.abundance
            .join(ch_trimmomatic, by:[0]),
        ch_quast_report,
        ch_quast_score,
        ch_el_gato_report,
        ch_allele_stats
    )

    CSVTK_COMBINE(
        COMBINE_SAMPLE_DATA.out.tsv
            .collect{ it[1] }
    )

    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ //
    // 9. Clustering (TO-DO)
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ //
    // chewbacca -> reportree -> manual vis (right now)
    // As reportree isn't easy to get installed in pipeline
    //  Its current container is missing PS which nextflow needs

    // ReporTree container and conda env are not going to play nice
    // REPORTREE(
    //     CHEWBBACA_EXTRACT_CGMLST.out.cgmlst,
    //     ch_metadata
    // )
}
