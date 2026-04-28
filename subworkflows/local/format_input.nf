/*
    Subworkflow to format input fastq files/folders from either directories or samplesheet

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include {samplesheetToList } from 'plugin/nf-schema'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    INITIALIZE CHANNELS FROM PARAMS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN SUBWORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
workflow FORMAT_INPUT {
    main:
    // ensure channels exist in all code paths so they're visible to emit
    ch_paired_fastqs = Channel.empty()
    ch_nanopore_fastqs = Channel.empty()
    if ( params.fastq_dir ) {
        // Try paired-end pattern first; don't fail if none found
        Channel
            .fromFilePairs("${params.fastq_dir}/*_{R1,R2}*.fastq*", checkIfExists:false)
            .map { it ->
                def meta = [ id: it[0], irida_id: it[0] ]
                return [ meta.id, meta, it[1] ]
            }
            .ifEmpty {
                // Fallback: map all files in the dir as single-end (e.g. nanopore)
                Channel.fromPath("${params.fastq_dir}/*.fastq*")
                    .map { reads ->
                        def id = reads.baseName.replaceAll(/\.fastq.*\$/, '')
                        def meta = [ id: id, irida_id: id ]
                        return [ meta.id, meta, [ file(reads) ] ]
                    }
            }
            .set { ch_maybe_paired }

        // Split into paired vs single (nanopore) channels based on file count
        ch_maybe_paired
            .filter { meta, fastqs -> fastqs.size() == 2 }
            .set { ch_paired_fastqs }

        ch_maybe_paired
            .filter { meta, fastqs -> fastqs.size() == 1 }
            .set { ch_nanopore_fastqs }
    } else {
        // Matching the above formatting by creating a list of the fastq file pairs
        //  Schema requires pairs at the moment so this is ok. If we want to support ONT
        //  data later will need to adjust the logic
        def processedIDs = [] as Set
        ch_paired_fastqs = Channel
            .fromList(samplesheetToList(params.input, "assets/schema_input.json"))
            .map { meta, fastq_1, fastq_2 ->
                if (!meta.id) {
                    meta.id = meta.irida_id
                } else {
                    // Non-alphanumeric characters (excluding _,-,.) will be replaced with "_"
                    meta.id = meta.id.replaceAll(/[^A-Za-z0-9_.\-]/, '_')
                }
                // Ensure ID is unique by appending meta.irida_id if needed
                while (processedIDs.contains(meta.id)) {
                    meta.id = "${meta.id}_${meta.irida_id}"
                }
                // Add the ID to the set of processed IDs
                processedIDs << meta.id

                // Used in the groupTuple below to ensure where multiple reads are provided for a sample, they are grouped together
                if (!fastq_2) {
                    meta = meta + [ single_end: true ]
                    return [ meta.id, meta, [ fastq_1 ] ]
                } else {
                    meta = meta + [ single_end: false ]
                    return [ meta.id, meta, [ fastq_1, fastq_2 ] ]
                }
            }
            .groupTuple()
            .map { samplesheet ->
                validateInputSamplesheet(samplesheet)
            }
            .map { meta, fastqs ->
                return [ meta, fastqs.flatten() ]
            }
            .set { ch_all_fastqs }

        // Split samples into single-end and paired-end channels
        ch_all_fastqs
            .filter { meta, fastqs -> meta.single_end == true }
            .set { ch_nanopore_fastqs }

        ch_all_fastqs
            .filter { meta, fastqs -> meta.single_end == false }
            .set { ch_paired_fastqs }
    }

    // Check after channel is made for the too long ids
    //  That way we can group them up to report all of them
    def tooLongIDs = [] as Set
    ch_paired_fastqs
        .subscribe(
            onNext: { meta, _fastqs ->
                if (meta.id.size() > params.max_name_length) {
                    tooLongIDs << meta.id
                }
            },
            onComplete: {
                if (tooLongIDs) {
                    error("The following sample names are too long (>${params.max_name_length} chars): ${tooLongIDs}. Please shorten them or adjust '--max_name_length'")
                }
            }
        )

    emit:
    paired = ch_paired_fastqs // channel of tuples: [ sample_id, meta, [fastq_1, fastq_2] ]
    nanopore = ch_nanopore_fastqs // channel of tuples: [ sample_id, meta, [fastq_1] ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
//
// Validate channels from input samplesheet
//
def validateInputSamplesheet(input) {
    def (metas, fastqs) = input[1..2]

    // Check that multiple runs of the same sample are of the same datatype i.e. single-end / paired-end
    def endedness_ok = metas.collect{ meta -> meta.single_end }.unique().size == 1
    if (!endedness_ok) {
        error("Please check input samplesheet -> Multiple runs of a sample must be of the same datatype i.e. single-end or paired-end: ${metas[0].id}")
    }

    return [ metas[0], fastqs ]
}
