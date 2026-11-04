using GLM

abstract type AbstractQuantificationMethod <: AbstractPlateReaderMethod end

"""
    quantification(data, time, method::AbstractQuantificationMethod;
        plot_directory = nothing)

Convert DNA/RNA fluorescence measurements to absolute units (e.g. concentration).

# Arguments
- `data`: a DataFrame of fluorescence measurements.
- `time`: a DataFrame of times for the fluorescence measurements.
- `method`: the method to use for quantifying fluorescence. The methods match the Clearissa
    software, and require a specific structure for the experimental design. See the
    documentation for each method (or the Clearissa software documentation) for details.

# Keyword Arguments
- `plot_directory`: the directory to save plots to. If `nothing`, no plots are saved. If
    `:temp`, a temporary directory is created and used. Otherwise, describes a directory
    path to save plots to.
"""
function quantification end

"""
    TMSD

Convert arbitrary fluorescence units to a concentration (in nM) for Toehold Mediated Strand
    Displacement (TMSD) reactions.

Arguments:
- `blank`: a DataFrame of blank fluorescence measurements.
- `positive_controls`: a DataFrame of positive control fluorescence measurements.
- `init_time`: a tuple of the form (start_time, end_time) describing the time window to use
    for the initialisation phase.
- `saturation_time`: a tuple of the form (start_time, end_time) describing the time window
    to use for the saturation phase.
- `positive_control_concentrations`: a Dict mapping the names of the positive control wells
    to their concentrations in nM.

Reaction has the form:
    B + A-x -> A-B + x

where:
- B is the invader strand
- A-x is the substrate complex
- A-B is the product complex

Total fluorescence is assumed to be of the form:
    h(t) = [A-B] + β[A-x]

This trajectory is estimated using:
    h(t) = (f_raw(t) - f_blank(t)) / p_corr(t) * C_ref
where:
- f_raw(t) is the raw fluorescence measurement being quantified
- f_blank(t) is the blank fluorescence measurement (calibration uses TimeseriesBlank)
- p_corr(t) is the positive control calibration trajectory
- C_ref is the concentration of the positive control

For TMSD, C_ref is not relevant since it cancels with the positive control calibration
    trajectory.

β is estimated as the ratio of the mean of h(t) over the initialisation phase (init_time)
    and [A-x]₀, the initial concentration of the substrate complex, estimated as the mean of
    h(t) over the saturation phase (saturation_time), since saturation should mean the
    reaction has gone to completion and all of the substrate complex has been converted to
    product complex.

Since [A-x]₀ = [A-B] + [A-x], we have that:
    [A-B] = (h(t) - β[A-x]₀) / (1 - β)
which is used to compute the final product concentration per well.
"""
@kwdef struct TMSD <: AbstractQuantificationMethod
    blank::DataFrame
    positive_controls::DataFrame
    init_time::Tuple{Float64, Float64}
    saturation_time::Tuple{Float64, Float64}
    positive_control_concentrations::Dict{String, Float64}
end

function quantification(data, time, method::TMSD; plot_directory=nothing)
    plot_directory = process_plot_directory(plot_directory)

    # calibrate all of data with blank timeseries
    calibrated_data = calibrate(data, time, TimeseriesBlank(method.blank, time))
    p_corr = calculate_p_corr(method.positive_controls, method.blank, time, method.init_time, method.positive_control_concentrations, 1.0) # C_ref is not relevant for TMSD

    # computing h(t) - per well
    h = deepcopy(calibrated_data)
    for name in names(h)
        f_raw = calibrated_data[!, name]
        g = f_raw ./ p_corr # Timeseries blank calibration on fraw
        h[!, name] = g
    end

    # reactant concentration per well
    c = mean_in_window(h, time, method.saturation_time)

    # Beta from initialisation phase
    h_init = mean_in_window(h, time, method.init_time)
    # beta = h_init ./ c

    # Final product concentration per well
    for name in names(h)
        h[!, name] = (h[!, name] .- h_init[!, name]) ./ (1 .- h_init[!, name] ./ c[!, name])
    end
    if !isnothing(plot_directory)
        p = plot()
        for col in names(h)
            plot!(p, time[!, 1], h[!, col], label=col)
        end
        plot_path = joinpath(plot_directory, "quantification_tmsd.png")
        savefig(p, plot_path)
    end
    return h
end

"""
    HMSD

Convert arbitrary fluorescence units to a concentration (in nM) for Handhold Mediated Strand
    Displacement (HMSD) reactions.

Arguments:
- `blank`: a DataFrame of blank fluorescence measurements.
- `positive_controls`: a DataFrame of positive control fluorescence measurements.
- `reference`: a DataFrame of reference fluorescence measurements.
- `init_time`: a tuple of the form (start_time, end_time) describing the time window to use
    for the initialisation phase.
- `positive_control_concentrations`: a Dict mapping the names of the positive control wells
    to their concentrations in nM.
- `concentration_reference`: the concentration of the substrate-template in the reference control in nM.

Reaction has the form:
    S1-T + R1 -> S1-T-R1

where:
- S1-T is the substrate-template
- R1 is the reporter
- S1-T-R1 is the product complex

Total fluorescence is assumed to be of the form:
    h(t) = [S1-T] + β[S1-T-R1]

This trajectory is estimated using:
    h(t) = (f_raw(t) - f_blank(t)) / (f_ref(t) - f_blank(t)) * C_ref
where:
- f_raw(t) is the raw fluorescence measurement being quantified
- f_blank(t) is the blank fluorescence measurement (calibration uses TimeseriesBlank)
- f_ref(t) is the reference fluorescence measurement
- C_ref is the concentration of the substrate-template in the reference control

β is estimated as the ratio of the mean of p_corr(t) over the initialisation phase (init_time)
    and the mean of f_ref(t) - f_blank(t) over the initialisation phase. This value of β is
    used for the whole plate.

Since [S1-T]₀ = [S1-T] + [S1-T-R1], we have that:
    [S1-T-R1] = ([S1-T]₀ - h(t)) / (1 - β)
which is used to compute the final product concentration per well.
"""
@kwdef struct HMSD <: AbstractQuantificationMethod
    blank::DataFrame
    positive_controls::DataFrame
    reference::DataFrame
    init_time::Tuple{Float64, Float64}
    positive_control_concentrations::Dict{String, Float64}
    concentration_reference::Float64
end

function quantification(data, time, method::HMSD; plot_directory=nothing)
    plot_directory = process_plot_directory(plot_directory)
    if !isnothing(plot_directory)

    end

    # calibrate all of data with blank timeseries
    calibrated_data = calibrate(data, time, TimeseriesBlank(method.blank, time))
    calibrated_ref = calibrate(method.reference, time, TimeseriesBlank(method.blank, time))

    # computing h(t) - per well
    h = deepcopy(calibrated_data)
    for name in names(h)
        f_raw = calibrated_data[!, name]
        g = f_raw ./ mean(eachcol(calibrated_ref))
        h[!, name] = g .* method.concentration_reference
    end

    # reactant concentration per well
    c = mean_in_window(h, time, method.init_time)

    # Beta from initialisation phase
    p_corr = calculate_p_corr(method.positive_controls, method.blank, time, method.init_time, method.positive_control_concentrations, method.concentration_reference)
    p_corr = mean_in_window(DataFrame(:p_corr => p_corr), time, method.init_time)
    calibrated_ref_init = mean_in_window(calibrated_ref, time, method.init_time)
    beta = p_corr[1, :p_corr] / mean(eachcol(calibrated_ref_init))[1]

    # Final product concentration per well
    for name in names(h)
        h[!, name] = (c[!, name] .- h[!, name]) ./ (1-beta)
    end

    if !isnothing(plot_directory)
        p = plot()
        for col in names(h)
            plot!(p, time[!, 1], h[!, col], label=col)
        end
        plot_path = joinpath(plot_directory, "quantification_hmsd.png")
        savefig(p, plot_path)
    end
    return h
end

"""
    InternalTMSD

Convert arbitrary fluorescence units to a concentration (in nM) for Internal Toehold Mediated Strand
    Displacement (Internal TMSD) reactions.

Arguments:
- `blank`: a DataFrame of blank fluorescence measurements.
- `positive_controls`: a DataFrame of positive control fluorescence measurements.
- `negative_controls`: a DataFrame of negative control fluorescence measurements.
- `init_time`: a tuple of the form (start_time, end_time) describing the time window to use
    for the initialisation phase.
- `saturation_time`: a tuple of the form (start_time, end_time) describing the time window
    to use for the saturation phase.
- `stable_neg_time`: a tuple of the form (start_time, end_time) describing the time window
    to use for the stable negative phase.
- `positive_control_concentrations`: a Dict mapping the names of the positive control wells
    to their concentrations in nM.
- `trigger_time`: the time at which the reaction is triggered. All values before this time
    are removed from the final output. Should be after the initialisation phase.

Reaction has the form:
    A-B-T + F -> A-B-F + T

where:
- A-B-T is the substrate
- F is the invader/fuel
- A-B-F is the fluorescent product
- T is the template

Total fluorescence is assumed to be of the form:
    h(t) = [A-B-F] + β[A-B-T]

This trajectory is estimated using:
    h(t) = (f_raw(t) - f_blank(t)) / p_corr(t) * C_ref
where:
- f_raw(t) is the raw fluorescence measurement being quantified
- f_blank(t) is the blank fluorescence measurement (calibration uses TimeseriesBlank)
- p_corr(t) is the positive control calibration trajectory
- C_ref is the concentration of the positive control

For InternalTMSD, C_ref is not relevant since it cancels with the positive control
    calibration trajectory.

[A-B-T]₀, the initial concentration of the substrate complex, is estimated as the mean of
    h(t) over the saturation phase (saturation_time), since saturation should mean the
    reaction has gone to completion and all of the substrate complex has been converted to
    product complex.

The negative controls are used to estimate β, which is the ratio of the mean of h(t) over
    the stable negative phase (stable_neg_time) and the median of [A-B-T]₀ across all wells.

Since [A-B-T]₀ = [A-B-T] + [A-B-F], we have that:
    [A-B-F] = (h(t) - β[A-B-T]₀) / (1 - β)
which is used to compute the final product concentration per well.
"""
@kwdef struct InternalTMSD <: AbstractQuantificationMethod
    blank::DataFrame
    positive_controls::DataFrame
    negative_controls::DataFrame
    init_time::Tuple{Float64, Float64}
    saturation_time::Tuple{Float64, Float64}
    stable_neg_time::Tuple{Float64, Float64}
    positive_control_concentrations::Dict{String, Float64}
    concentration_reference::Float64
    trigger_time::Float64
end

function quantification(data, time, method::InternalTMSD; plot_directory=nothing)
    plot_directory = process_plot_directory(plot_directory)
    if !isnothing(plot_directory)

    end

    # calibrate all of data with blank timeseries
    calibrated_data = calibrate(data, time, TimeseriesBlank(method.blank, time))
    negative_controls = calibrate(method.negative_controls, time, TimeseriesBlank(method.blank, time))
    p_corr = calculate_p_corr(method.positive_controls, method.blank, time, method.init_time, method.positive_control_concentrations, 1.0)

    # computing h(t) - per well
    h = deepcopy(calibrated_data)
    for name in names(h)
        f_raw = calibrated_data[!, name]
        g = f_raw ./ p_corr # Timeseries blank calibration on fraw
        h[!, name] = g
    end

    # reactant concentration per well
    c = mean_in_window(h, time, method.saturation_time)

    # reactant concentration for whole plate
    c_plate = median(skipmissing(c[1,:]))

    # h_neg,base = mean(h_neg(t))
    h_neg = deepcopy(negative_controls)
    for name in names(h_neg)
        f_raw_neg = negative_controls[!, name]
        g = f_raw_neg ./ p_corr # Timeseries blank calibration on fraw
        h_neg[!, name] = g
    end
    h_neg_base = mean_in_window(h_neg, time, method.stable_neg_time)
    h_neg_base = mean(skipmissing(h_neg_base[1,:])) # average over negative controls

    # Beta from negative controls
    beta = h_neg_base / c_plate

    # Final product concentration per well
    for name in names(h)
        h[!, name] = (h[!, name] .- beta .* c[!, name]) ./ (1 .- beta)
    end
    # Remove pre-trigger values as conversion is not valid before trigger time
    h = between_times(h, time, mint=method.trigger_time)
    if !isnothing(plot_directory)
        p = plot()
        for col in names(h)
            plot!(p, time[!, 1], h[!, col], label=col)
        end
        plot_path = joinpath(plot_directory, "quantification_internal_tmsd.png")
        savefig(p, plot_path)
    end
    return h
end

"""
    RelativeFluorescence

Convert arbitrary fluorescence units to a relative fluorescence value (where 0 is defined by
    a negative control and 1 is defined by positive controls).

Arguments:
- `blank`: a DataFrame of blank fluorescence measurements.
- `positive_controls`: a DataFrame of positive control fluorescence measurements.
- `negative_controls`: a DataFrame of negative control fluorescence measurements.
- `init_time`: a tuple of the form (start_time, end_time) describing the time window to use
    for the initialisation phase.
- `stable_neg_time`: a tuple of the form (start_time, end_time) describing the time window
    to use for the stable negative phase.
- `positive_control_concentrations`: a Dict mapping the names of the positive control wells
    to their concentrations in nM.
- `concentration_reference`: the concentration of the positive control in nM.

All data is calibrated with the blank timeseries using TimeseriesBlank.

The negative control baseline, f_neg,base, is calculated as the mean of the negative control
    fluorescence measurements over the stable negative phase.

The relative fluorescence is calculated as:
    RF(t) = (f_raw(t) - f_neg,base) / (p_corr(t) - f_neg,base)
where:
- f_raw(t) is the raw fluorescence measurement (after calibration) being quantified
- f_neg,base is the negative control baseline
- p_corr(t) is the positive control calibration trajectory
"""
@kwdef struct RelativeFluorescence <: AbstractQuantificationMethod
    blank::DataFrame
    positive_controls::DataFrame
    negative_controls::DataFrame
    init_time::Tuple{Float64, Float64}
    stable_neg_time::Tuple{Float64, Float64}
    positive_control_concentrations::Dict{String, Float64}
    concentration_reference::Float64
end

function quantification(data, time, method::RelativeFluorescence; plot_directory=nothing)
    # calibrate all of data with blank timeseries
    calibrated_data = calibrate(data, time, TimeseriesBlank(method.blank, time))
    negative_controls = calibrate(method.negative_controls, time, TimeseriesBlank(method.blank, time))
    p_corr = calculate_p_corr(method.positive_controls, method.blank, time, method.init_time, method.positive_control_concentrations, method.concentration_reference)

    f_neg_base = mean_in_window(negative_controls, time, method.stable_neg_time)
    f_neg_base = mean(skipmissing(f_neg_base[1, :])) # average over negative controls

    out = deepcopy(calibrated_data)
    for name in names(calibrated_data)
        f_raw = calibrated_data[!, name]
        out[!, name] = (f_raw .- f_neg_base) ./ (p_corr .- f_neg_base)
    end

    if !isnothing(plot_directory)
        p = plot()
        for col in names(out)
            plot!(p, time[!, 1], out[!, col], label=col)
        end
        plot_path = joinpath(plot_directory, "quantification_relative.png")
        savefig(p, plot_path)
    end
    return out
end

function calculate_p_corr(positive_controls, blanks, time, init_time, positive_control_concentrations, concentration_reference)
    calibrated_positive_control = calibrate(positive_controls, time, TimeseriesBlank(blanks, time))

    # Average over initialisation phase and normalise by it
    f_pos_init = mean_in_window(calibrated_positive_control, time, init_time)
    for col in names(calibrated_positive_control)
        calibrated_positive_control[!, col] ./= f_pos_init[!, col]
    end

    # Linear regression between f_pos_init and concentrations
    model = lm(reshape([positive_control_concentrations[name] for name in names(calibrated_positive_control)], :, 1), collect(f_pos_init[1, :])) # this will need to be fixed
    c_io = coef(model)[1]

    p_corr = c_io .* concentration_reference .* mean(eachcol(calibrated_positive_control))
    return p_corr
end

function mean_in_window(data, time, window)
    # Average over a time window
    data_window = between_times(data, time; mint = window[1], maxt = window[2])
    data_window = combine(data_window, All() .=> mean ∘ skipmissing; renamecols=false)
    return data_window
end
