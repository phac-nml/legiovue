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
    if ( params.fastq_dir ) {
        // Just adapting to the metamap format using fromFilePairs
        Channel
            .fromFilePairs("${params.fastq_dir}/*_{R1,R2}*.fastq*", checkIfExists:true)
            .map { it -> [ [id: it[0]], it[1] ] }
            .set { ch_paired_fastqs }
    } else {
        // Matching the above formatting by creating a list of the fastq file pairs
        //  Schema requires pairs at the moment so this is ok. If we want to support ONT
        //  data later will need to adjust the logic
        Channel.fromList(samplesheetToList(params.input, "assets/schema_input.json"))
            .map { it -> [ it[0], [it[1], it[2]] ] }
            .set { ch_paired_fastqs }
    }

    emit:
    pass = ch_paired_fastqs      // channel: [ val(meta), file(fastq_1), file(fastq_2) ]
}
