# phac-nml/LegioVue: Usage

## Introduction

This pipeline is intended to be run on _Legionella pneumophila_ paired illumina isolate sequencing data. It generates _de novo_ assemblies using [`SPAdes`](https://github.com/ablab/spades), sequence types (ST) using [`el_gato`](https://github.com/appliedbinf/el_gato), cgMLST calls with [`chewBBACA`](https://chewbbaca.readthedocs.io/en/latest/index.html), and a summary QC report. The outputs of the pipeline can be used for other downstream applications. All parameters have been determined based on outbreak dataset testing.

## Index

- [Profiles](#profiles)
- [Running the Pipeline](#running-the-pipeline)
  - [`--fastq_dir`](#fastq_dir)
  - [`--input`](#input)
- [All Parameters](#all-parameters)
  - [Required](#required)
  - [Optional](#optional)
- [Core Nextflow Arguments](#core-nextflow-arguments)
  - [`-resume`](#resume)
  - [`-c`](#c)
    - [Resource Labels](#resource-labels)
- [Other Run Notes](#other-run-notes)
  - [Updating the pipeline](#updating-the-pipeline)
  - [Reproducibility](#reproducibility)

## Profiles

Profiles are used to specify dependency installation, resources, and how to handle pipeline jobs. You can specify more than one profile but _avoid_ passing in more than one dependency managment profile (Ex. Do not use both `singularity` and `mamba`). They can be passed with `-profile <PROFILE>`

Available:

- `conda`: Utilize conda to install dependencies and environment management
- `mamba`: Utilize mamba to install dependencies and environment management
- `singularity`: Utilize singularity for dependencies and environment management
- `docker`: Utilize docker to for dependencies and environment management

For testing the pipeline functions correctly, you can use the `test` or `test_full` profile

## Running the Pipeline

To get started, one of the following commands may be used to run the pipeline:

Directory Input:

```bash
nextflow run phac-nml/legiovue \
    -profile <PROFILE> \
    --fastq_dir </PATH/TO/PAIRED_FASTQS> \
    [Optional Args]
```

Samplesheet CSV Input:

```bash
nextflow run phac-nml/legiovue \
    -profile <PROFILE> \
    --input </PATH/TO/INPUT.csv> \
    [Optional Args]
```

### `--fastq_dir`

Specify a directory to where paired FASTQ-formatted files are found. FASTQs must be formatted as `<NAME>_{R1,R2}\*.fastq\*` so that they can be paired up correctly based on the file name. Note that at the moment everything before the first `_R1/_R2` is kept as the sample name.

Example directory with 3 samples:

```
<fastq_pairs>
├── TDS-01_R1.fastq.gz
├── TDS-01_R2.fastq.gz
├── ex-sample_R1.fastq
├── ex-sample_R2.fastq
├── another-sample_S1_L001_R1_001.fastq.gz
└── another-sample_S1_L001_R2_001.fastq.gz
```

### `--input`

Specify a CSV samplesheet containing information about each sample including the sample name and the FASTQ-formatted reads associated with the sample.

The outputs are named based on the given sample name and the FASTQ data is input based on the path specified under `fastq_1` and `fastq_2`. The input FASTQ files can end with `.fq`, `.fq.gz`, `.fastq`, or `.fastq.gz` to be valid inputs.

Example:
| sample | fastq_1 | fastq_2 |
| - | - | - |
| sample1 | fastqs/sample1_R1.fastq.gz | fastqs/sample1_R1.fastq.gz |
| sample2 | fastqs/sample2_R1.fastq.gz | fastqs/sample2_R2.fastq.gz |
| other-sample | other_samples/other-sample_R1.fq.gz | other_samples/other-sample_R2.fq.gz |
| more_sample_data | fastqs/more_sample_data_R1.fq | fastqs/more_sample_data_R2.fq |

## All Parameters

Use `--help` to see all options formatted on the command line

Use `--version` to see version information
All of the required and optional parameters are defined as follows:

### Required

It is required to pick one of the following to get fastq data into the pipeline
| Parameter | Description | Type | Default | Notes |
| - | - | - | - | - |
| --fastq_dir | Path to directory containing paired fastq files | Path | null | See [--fastq_dir](#fastq_dir) |
| --input | Path to CSV file containing information on the paired fastq files | Path | null | See [--input](#input) |

### Optional

| Parameter               | Description                                                                           | Type   | Default                    | Notes                                                                                                                  |
| ----------------------- | ------------------------------------------------------------------------------------- | ------ | -------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| --outdir                | Directory name to output results to                                                   | Str    | 'results'                  |                                                                                                                        |
| --min_abundance_percent | Minimum _L. pneumophila_ abundance required after bracken to continue sample on       | Float  | 10.0                       | Very permissive for now                                                                                                |
| --min_reads             | Minimum reads required after trimmomatic to continue sample on                        | Int    | 60,000                     | Under 150,000 reads samples don't usually provide enough info for proper clustering / STs                              |
| --kraken2_db            | Path to standard `kraken2` database for detecting _L. pneumophila_ reads              | Path   |                            | You will need to get your own database. The 8GB database from s3://genome-idx/kraken/standard_08gb_20240904 works well |
| --quast_ref             | Path to reference sequence for some of the `QUAST` metrics                            | Path   | data/C9_S.reference.fna    | C9 was picked as a default reference but any good sequence will work                                                   |
| --max_contigs           | Threshold for the number of contigs > 500bp assembled by SPAdes to get scoring points | 100    | Int                        |                                                                                                                        |
| --min_align_percent     | Thresold for minimum QUAST genome fraction percentage to get scoring points           | 75     | Float                      |                                                                                                                        |
| --min_reads_warn        | Threshold for minimum number of reads that will be given a QC warning                 | 150000 | Int                        |                                                                                                                        |
| --min_n50_score         | Thresold for minimum QUAST N50 value to obtain scoring points                         | 80000  | Int                        |                                                                                                                        |
| --max_n50_score         | Thresold for maximum QUAST N50 score to get max scoring points                        | 220000 | Int                        |                                                                                                                        |
| skip_el_gato            | Flag to skip running el_gato sequence typing                                          | Bool   | False                      |                                                                                                                        |
| skip_plotting           | Flag to skip running the el_gato allele plotting                                      | Bool   | False                      |                                                                                                                        |
| --prepped_schema        | Path to a prepped `chewBBACA` schema to save running the prep command                 | Path   | data/SeqSphere_1521_schema | Provided with pipeline                                                                                                 |
| --schema_targets        | Path to schema targets to prep for `chewBBACA`                                        | Path   | null                       |                                                                                                                        |
| --publish_dir_mode      | Specifies how intermediate files should be saved to the output directory              | Str    | copy                       |                                                                                                                        |
| --max_memory            | Maximum memory allowed to be given to a job                                           | Str    | 128.GB                     |                                                                                                                        |
| --max_cpus              | Maximum cpus allowed to be given to a job                                             | Int    | 16                         |                                                                                                                        |
| --max_time              | Maximum time allowed to be given to a job                                             | Str    | 240.h'                     |                                                                                                                        |

## Core Nextflow Arguments

> [!NOTE]
> These options are part of Nextflow and use a _single_ hyphen (pipeline parameters use a double-hyphen).

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously. For input to be considered the same, not only the names must be identical but the files' contents as well. For more info about this parameter, see [this blog post](https://www.nextflow.io/blog/2019/demystifying-nextflow-resume.html).

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

### `-c`

Specify the path to a specific config file (this is a core Nextflow command). See the [nf-core website documentation](https://nf-co.re/usage/configuration) for more information.

#### Resource Labels

The following resource labels can be adjusted in a custom config file:

- `process_single` - Default: 1cpus, 4GB memory
- `process_low` - Default: 2cpus, 8GB memory
- `process_medium` - Default: 4cpus, 24GB memory
- `process_high` - Default: 8cpus, 48GB memory

## Other Run Notes

If you wish to repeatedly use the same parameters for multiple runs, rather than specifying each flag in the command, you can specify these in a params file.

Pipeline settings can be provided in a `yaml` or `json` file via `-params-file <file>`.

> [!WARNING]
> Do not use `-c <file>` to specify parameters as this will result in errors. Custom config files specified with `-c` must only be used for [tuning process resource specifications](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources), other infrastructural tweaks (such as output directories), or module arguments (args).

The above pipeline run specified with a params file in yaml format:

```bash
nextflow run phac-nml/legiovue -profile docker -params-file params.yaml
```

with `params.yaml` containing:

```yaml
fastq_dir: "./fastqs"
outdir: "./results/"
```

### Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it will always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```bash
nextflow pull phac-nml/legiovue
```

### Reproducibility

It is a good idea to specify a pipeline version when running the pipeline on your data. This ensures that a specific version of the pipeline code and software are used when you run your pipeline. If you keep using the same tag, you'll be running the same version of the pipeline, even if there have been changes to the code since.
