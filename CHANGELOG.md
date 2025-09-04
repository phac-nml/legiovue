# phac-nml/LegioVue: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0]

Updates focusing on getting LegioVue setup to run in IRIDA-Next along with fixing updating to some best-practices and bumping the minimum nextflow version

### `Added`

- MultiQC module added to create html report

### `Changed`

- Bumped minimum nextflow version to 24.04.1
- Addition of Quast values to the `scored_quast_report.csv` file
- Changed the `final_qc_score` column's name and order within the `overall.qc.csv` file to make it clearer visually that the QC score does not take into account allele calling and cgMLST stats
- Organization of the `nextflow_schema.json` file by moving results and adjusting input/output options
- Naming convention in pipeline itself (all lowercase)
- Tests updated

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

[0.1.0]: https://github.com/phac-nml/legiovue/releases/tag/0.1.0
[0.2.0]: https://github.com/phac-nml/legiovue/releases/tag/0.2.0
