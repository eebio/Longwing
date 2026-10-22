# MEF Calibration

For calibrating flow cytometer fluorescence, we provide a method similar to that of [FlowCal](https://flowcal.readthedocs.io/en/latest/). This method involves generating a standard curve from flow cytometer beads, to convert fluorescence channels from units of RFI to MEF. The method uses the function signature of `calibrate(df, MEF(beads = ..., channel = ..., mef = ...))`.

- `beads` is a `DataFrame` of flow cytometry data of rainbow beads used for calibration.
- `channel` is the fluorescence channel that will be used for calibration - the same channel name should be used in both `df` and `beads`.
- `mef` is a `Vector` of values corresponding to the MEF values (or other equilavent units) for each peak.

You can also provide some additional arguments to `MEF()` which have some default values:

- `summary=median` is a function for calculating the "average" fluorescence of a peak. Other examples include `mean` or `StatsBase.geomean`.
- `seed=0`, the clustering used is inherently random so a fixed seed is always set. Since you may need to try the clustering a few times to find a suitable match, this can be done by changing the `seed`.
- `nInit=100` is the number of iterations of kmeans clustering to set the initial conditions for the Gaussian Mixture Models clustering.
- `nIter=100` is the number of iterations of Expectation Maximisation for fine tuning the GMM.
- `nRepeats=10` is the number of times the clustering is repeated (both kmeans and EM) with the final clustering being the one that maximises the likelihood.
- `transform=Logicle()` is a transform applied to the bead data before clustering. This can be useful if the bead peaks are not well separated on a linear scale. Any of the transforms from the [Transforms](@ref) page can be used, for example `MEF(..., transform=Hyperlog())`.

You can also provide a `plot_directory` arguement to calibrate (`calibrate(df, MEF(...); plot_directory=...)`) to generate plots of the standard curve and histograms of the data, before and after clustering. You can provide a filepath where the plots will be saved, or `plot_directory=:temp`, in which case they will be saved to a temporary directory.

If you already know the positions of each of the peaks, you can instead use the function signature `calibrate(df, peaks, MEF(...))` to skip the clustering step.
