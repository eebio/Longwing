# Workflows

A common structure for analyzing biological data is through workflows. Pipelines in which raw input data is sent through to produce final summary statistics. This can be achieved in Longwing by having pre-made templates for a particular type of analysis. Each of these templates include a set of pre-defined but customizable transformations and views for analyzing data in a particular way. You can then input your data into the Samples sheet and fill in the pre-defined groups and channel map required for the analysis. The final step is to translate this template and generate views, which will include validation plots whereever possible.

- [Growth Rates using blanks to correct data](https://github.com/eebio/longwing/raw/refs/heads/main/docs/src/assets/worflows/growth_rates_blanks.xlsx)
- [Growth Rates without using blanks to correct data](https://github.com/eebio/longwing/raw/refs/heads/main/docs/src/assets/worflows/growth_rates_no_blanks.xlsx)
- [Fluorescence per cell using blanks to correct data](https://github.com/eebio/longwing/raw/refs/heads/main/docs/src/assets/worflows/fluorescence_blanks.xlsx)
- [Fluorescence per cell without using blanks to correct data](https://github.com/eebio/longwing/raw/refs/heads/main/docs/src/assets/worflows/fluorescence_no_blanks.xlsx)
- [Autogating of flow cytometry data](https://github.com/eebio/longwing/raw/refs/heads/main/docs/src/assets/worflows/autogate.xlsx)
- [Bead calibration of flow cytometry data](https://github.com/eebio/longwing/raw/refs/heads/main/docs/src/assets/worflows/bead_calibration.xlsx) (this also requires specifying some values for the transformations, i.e. the MEF values for the beads and the channel which you want to calibrate to MEF units)
