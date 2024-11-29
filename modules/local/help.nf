// Temp help statement
def printHelp() {
  log.info"""
Usage:
  nextflow run phac-nml/legiovue -profile <PROFILE> --fastq_dir <PATH/TO/PAIRED_FASTQS>

Description:
  Pipeline to generates Legionella pneumophila de novo assemblies, ST types, cgMLST calls, and QC summaries for clustering and reporting

Nextflow arguments (single DASH):
  -profile                  Allowed values: conda, mamba, singularity, apptainer, docker
  -c                        Add in custom config files for resources or own cluster

Mandatory workflow arguments:
  --fastq_dir               Path to directory containing paired legionella fastq data

Optional:
  ## Basic Args ##
  --outdir                  Output directory (Default: ./results)

  ## Filtering ##
  --min_abundance_percent   Minimum L. pneumophila abundance required (Default: 10.0)
  --min_reads               Minimum reads required after trimmomatic (Default: 150000)

  ## Kraken/Bracken ##
  --kraken2_db              Path to standard kraken2 database
                              (Default: s3://genome-idx/kraken/standard_08gb_20240904)

  ## Quast ##
  --quast_ref               Path to reference sequence for some of the quast metrics
                              (Default data/C9_S.reference.fna)

  ## Chewbbaca ##
  --prepped_schema          Path to a prepped chewbbaca schema to save running the prep command
                              (Default: data/SeqSphere_1521_schema)
  --schema_targets          Path to schema targets to prep for chewbbaca if not using the default SeqSphere_1521

  ## Other Generic Args ##
  --help                    Prints this statement
  --version                 Prints the pipeline version
  --max_memory              Maximum memory to allow to be allocated when running processes (Default: 128G)
  --max_cpus                Maximum cpus to allow to be allocated when running processes (Default: 16)
  --max_time                Maximum time to allow to be allocated when running processes (Default: 240.h)
""".stripIndent()
}
