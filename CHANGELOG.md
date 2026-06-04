# phac-nml/LegioVue: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0]

Update to include support for nanopore sequencing data.

### `Added`

- `legiovue_ont.nf` new subworkflow to handle nanopore reads and associated modules.
- `dragonflye.nf`, `nanoplot.nf`, `nanoq.nf`, `assembly_quality.nf`, and `allele_quality.nf` new modules to support the nanopore sequence analysis.
- `nanopore_combine_qc_data.py`, `nanopore_plot_genome_cov.R`, and `nanopore_quast_analyzer.py` to handle qc collection and, allele plotting, and assembly analysis.
- `multiqc_config_nanopore.yaml` to produce multiqc report for the nanopore branch.

### `Changed`

- `nextflow.config` added nanopore parameters to match existing illumina parameters.
- `modules.config` addition of new nanopore specific modules and updated publish directory paths to improve output organization.
- `format_input.nf` adjusted to differentiate between single-end and paired-end reads.
- `main.nf` adjustment to handle both paired-end and single-end sequence data and add `legiovue_ont.nf` subworkflow.
- `bracken.nf`, `chewbbaca.nf`, `el_gato.nf`, `kraken.nf`, `multiqc.nf`, `plotting.nf`, `qc.nf`, `quast.nf`, and `utils.nf` all updated to contain processes to support nanopore sequencing data.

## [0.4.0]

Overall small adjustments and bugfixes to:

- modules
- containers
- labels
- workflow best practices

### `Changed`

- `quast_analyzer.py` `--min_align_percent` argument changed from an integer to float to match up with the `nextflow_schema.json` definition [#27](https://github.com/phac-nml/legiovue/pull/27)
- Added the final multiqc report to the `iridanext.config` file [#27](https://github.com/phac-nml/legiovue/pull/27)
- Removal of `quay.io` prefix from some containers [#27](https://github.com/phac-nml/legiovue/pull/27)
- Adjusted `legiovue.nf` closures to be more detailed [#27](https://github.com/phac-nml/legiovue/pull/27)
- Small multiqc module adjustments to save IO resources [#32](https://github.com/phac-nml/legiovue/pull/32)
- ChewBBACA update to 3.5.3 [#32](https://github.com/phac-nml/legiovue/pull/32)
  - Had to update final QC summary to capture the change to `.configs` in the FILE column
- Add el_gato ST database as a parameter [#32](https://github.com/phac-nml/legiovue/pull/32)
  - As `--el_gato_sbt` and `--el_gato_profile`
- Added in a profile to hopefully address issue [#30] - config specification - that is available with `-profile env_params` [#32](https://github.com/phac-nml/legiovue/pull/32)
  - It adds in params to set the el_gato version/containers and the ChewBBACA version and container
  - It does always warn that the docker based params are null but they do work

### `Removed`

- Unused `slackreport.json` removed [#27](https://github.com/phac-nml/legiovue/pull/27)

### `Fixes`

- [#29](https://github.com/phac-nml/legiovue/issues/29) - Plot3 column mislabeled in multiqc report as plot5
- [#28](https://github.com/phac-nml/legiovue/issues/28) - Long names failing after SPAdes assemble / for ChewBBACA late into pipeline
- [#21](https://github.com/phac-nml/legiovue/issues/21) - ChewBBACA plotly issue

## [0.3.0]

Updates focusing on getting LegioVue setup to run in IRIDA-Next along with fixing updating to some best-practices and bumping the minimum nextflow version

### `Added`

- MultiQC module added to create html report [#23](https://github.com/phac-nml/legiovue/pull/23)
- New column for samplesheet input and logic to use it for irida-next upload [#25](https://github.com/phac-nml/legiovue/pull/25)

### `Changed`

- Bumped minimum nextflow version to 24.04.1 [#23](https://github.com/phac-nml/legiovue/pull/23)
- Addition of Quast values to the `scored_quast_report.csv` file [#23](https://github.com/phac-nml/legiovue/pull/23)
- Changed the `final_qc_score` column's name and order within the `overall.qc.csv` file to make it clearer visually that the QC score does not take into account allele calling and cgMLST stats [#23](https://github.com/phac-nml/legiovue/pull/23)
- Organization of the `nextflow_schema.json` file by moving results and adjusting input/output options [#23](https://github.com/phac-nml/legiovue/pull/23)
- Naming convention in pipeline itself (all lowercase) [#23](https://github.com/phac-nml/legiovue/pull/23)
- Tests updated [#23](https://github.com/phac-nml/legiovue/pull/23) [#25](https://github.com/phac-nml/legiovue/pull/25)
- Test kraken2 database from the amazon link to custom tiny Legionella pneumophila only one [#25](https://github.com/phac-nml/legiovue/pull/25)
  - This should only be used for running CI tests, not production data unless you do not care about the classification stats!

### `Fixes`

- [#10](https://github.com/phac-nml/legiovue/issues/10)
- [#12](https://github.com/phac-nml/legiovue/issues/12)
- [#19](https://github.com/phac-nml/legiovue/issues/19)
- [#20](https://github.com/phac-nml/legiovue/issues/20)

## [0.2.0] - 2025-01-24

### `Added`

- `nf-schema` plugin and associated functions
  - Schemas
  - Param summary, param help, version
  - samplesheetToList
- `params.input <CSV>` to allow input samplesheets
- `iridanext` plugin
- `nf-prov` plugin
- Required nf-core files
- CI tests and linting
- Added in quality parameters to allow more user freedom:
  - max_contigs
  - min_align_percent
  - min_reads_warn
  - min_n50_score
  - max_n50_score

### `Changed`

- Final quality metrics output is a CSV now to work with IRIDA next
- Logic for input data
- Logic for skipping specific modules
  - Allowed to skip el_gato ST
  - Allowed to skip el_gato allele plotting
- All process publishDir now in the `modules.conf` file
- Container for allele plotting
- Adjusted default warn and fail parameters for quality module based on testing
  - `min_reads` to 60,000 from 150,000

### `Updated`

- Usage and README docs for the input adjustments

## [0.1.0] - Beta-Test-2024-11-29

### `Added`

- LegioVue pipeline created and initial beta code added

[0.4.0]: https://github.com/phac-nml/legiovue/releases/tag/0.4.0
[0.3.0]: https://github.com/phac-nml/legiovue/releases/tag/0.3.0
[0.2.0]: https://github.com/phac-nml/legiovue/releases/tag/0.2.0
[0.1.0]: https://github.com/phac-nml/legiovue/releases/tag/0.1.0
