# phac-nml/LegioVue: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v0.2.0 - [2025-01-03]

### `Added`

- `nf-schema` plugin and associated functions
  - Schemas
  - Param summary, param help, version
  - samplesheetToList
- `params.input <CSV>` to allow input samplesheets
- `iridanext` plugin
  - The associated data will come out in 0.3.0
- Most of the required nf-core files
- CI tests and linting

### `Changed`

- Final quality metrics output is a CSV now to work with IRIDA next
- Logic for input data
- Logic for skipping specific modules
  - Allowed to skip el_gato ST
  - Allowed to skip el_gato allele plotting

### `Updated`

- Usage and README docs for the input adjustments

## v0.1.0 - [Beta-Test-2024-11-29]

### `Added`

- LegioVue pipeline created and initial beta code added
