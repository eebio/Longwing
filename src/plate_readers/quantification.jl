using GLM

abstract type AbstractQuantificationMethod <: AbstractPlateReaderMethod end

"""
    quantification(data_fl, time_fl, method::AbstractQuantificationMethod;
        plot_directory = nothing)

Convert DNA/RNA fluorescence measurements to absolute units (e.g. concentration).

# Arguments
- `data_fl`: a DataFrame of fluorescence measurements.
- `time_fl`: a DataFrame of times for the fluorescence measurements.
- `method`: the method to use for quantifying fluorescence.

# Keyword Arguments
- `plot_directory`: the directory to save plots to. If `nothing`, no plots are saved. If
    `:temp`, a temporary directory is created and used. Otherwise, describes a directory
    path to save plots to.
"""
function quantification end

@kwdef struct TMSD <: AbstractQuantificationMethod
    blank::DataFrame
    positive_controls::DataFrame
    init_time::Tuple{Float64, Float64}
    saturation_time::Tuple{Float64, Float64}
    positive_control_concentrations::Dict{String, Float64}
    concentration_reference::Float64
end

function quantification(data_fl, time_fl, method::TMSD; plot_directory=nothing)
    plot_directory = process_plot_directory(plot_directory)

    # calibrate all of data_fl with blank timeseries
    calibrated_data_fl = calibrate(data_fl, time_fl, TimeseriesBlank(method.blank, time_fl))
    p_corr = calculate_p_corr(method.positive_controls, method.blank, time_fl, method.init_time, method.positive_control_concentrations, method.concentration_reference)

    # computing h(t) - per well
    h = deepcopy(calibrated_data_fl)
    for name in names(h)
        f_raw = calibrated_data_fl[!, name]
        g = f_raw ./ p_corr # Timeseries blank calibration on fraw
        h[!, name] = g .* method.concentration_reference
    end

    # reactant concentration per well
    c = mean_in_window(h, time_fl, method.saturation_time)

    # Beta from initialisation phase
    h_init = mean_in_window(h, time_fl, method.init_time)
    # beta = h_init ./ c

    # Final product concentration per well
    for name in names(h)
        h[!, name] = (h[!, name] .- h_init[!, name]) ./ (1 .- h_init[!, name] ./ c[!, name])
    end
    if !isnothing(plot_directory)
        p = plot()
        for col in names(h)
            plot!(p, time_fl[!, 1], h[!, col], label=col)
        end
        plot_path = joinpath(plot_directory, "quantification_tmsd.png")
        savefig(p, plot_path)
        # TODO plot p_corr
    end
    return h
end

@kwdef struct HMSD <: AbstractQuantificationMethod
    blank::DataFrame
    positive_controls::DataFrame
    reference::DataFrame
    init_time::Tuple{Float64, Float64}
    positive_control_concentrations::Dict{String, Float64}
    concentration_reference::Float64
end

function quantification(data_fl, time_fl, method::HMSD; plot_directory=nothing)
    plot_directory = process_plot_directory(plot_directory)
    if !isnothing(plot_directory)

    end

    # calibrate all of data_fl with blank timeseries
    calibrated_data_fl = calibrate(data_fl, time_fl, TimeseriesBlank(method.blank, time_fl))
    calibrated_ref = calibrate(method.reference, time_fl, TimeseriesBlank(method.blank, time_fl))

    # computing h(t) - per well
    h = deepcopy(calibrated_data_fl)
    for name in names(h)
        f_raw = calibrated_data_fl[!, name]
        g = f_raw ./ calibrated_ref[!, 1] # TODO average over multiple negative controls
        h[!, name] = g .* method.concentration_reference
    end

    # reactant concentration per well
    c = mean_in_window(h, time_fl, method.init_time)

    # Beta from initialisation phase
    p_corr = calculate_p_corr(method.positive_controls, method.blank, time_fl, method.init_time, method.positive_control_concentrations, method.concentration_reference)
    p_corr = mean_in_window(DataFrame(:p_corr => p_corr), time_fl, method.init_time)
    calibrated_ref_init = mean_in_window(calibrated_ref, time_fl, method.init_time)
    beta = p_corr[1, :p_corr] / mean(eachcol(calibrated_ref_init))[1]

    # Final product concentration per well
    for name in names(h)
        h[!, name] = (c[!, name] .- h[!, name]) ./ (1-beta)
    end

    if !isnothing(plot_directory)
        p = plot()
        for col in names(h)
            plot!(p, time_fl[!, 1], h[!, col], label=col)
        end
        plot_path = joinpath(plot_directory, "quantification_hmsd.png")
        savefig(p, plot_path)
        # TODO plot p_corr
    end
    return h
end

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

function quantification(data_fl, time_fl, method::InternalTMSD; plot_directory=nothing)
    plot_directory = process_plot_directory(plot_directory)
    if !isnothing(plot_directory)

    end

    # calibrate all of data_fl with blank timeseries
    calibrated_data_fl = calibrate(data_fl, time_fl, TimeseriesBlank(method.blank, time_fl))
    negative_controls = calibrate(method.negative_controls, time_fl, TimeseriesBlank(method.blank, time_fl))
    p_corr = calculate_p_corr(method.positive_controls, method.blank, time_fl, method.init_time, method.positive_control_concentrations, method.concentration_reference)

    # computing h(t) - per well
    h = deepcopy(calibrated_data_fl)
    for name in names(h)
        f_raw = calibrated_data_fl[!, name]
        g = f_raw ./ p_corr # Timeseries blank calibration on fraw
        h[!, name] = g .* method.concentration_reference
    end

    # reactant concentration per well
    c = mean_in_window(h, time_fl, method.saturation_time)

    # reactant concentration for whole plate
    c_plate = median(skipmissing(c[1,:]))

    # h_neg,base = mean(h_neg(t))
    h_neg = deepcopy(negative_controls)
    for name in names(h_neg)
        f_raw_neg = negative_controls[!, name]
        g = f_raw_neg ./ p_corr # Timeseries blank calibration on fraw
        h_neg[!, name] = g .* method.concentration_reference
    end
    h_neg_base = mean_in_window(h_neg, time_fl, method.stable_neg_time)
    h_neg_base = mean(skipmissing(h_neg_base[1,:])) # average over negative controls

    # Beta from negative controls
    beta = h_neg_base / c_plate

    # Final product concentration per well
    for name in names(h)
        h[!, name] = (h[!, name] .- beta .* c[!, name]) ./ (1 .- beta)
    end
    # Remove pre-trigger values as conversion is not valid before trigger time
    h = between_times(h, time_fl, mint=method.trigger_time)
    if !isnothing(plot_directory)
        p = plot()
        for col in names(h)
            plot!(p, time_fl[!, 1], h[!, col], label=col)
        end
        plot_path = joinpath(plot_directory, "quantification_internal_tmsd.png")
        savefig(p, plot_path)
        # TODO plot p_corr
    end
    return h
end

@kwdef struct RelativeFluorescence <: AbstractQuantificationMethod
    blank::DataFrame
    positive_controls::DataFrame
    negative_controls::DataFrame
    init_time::Tuple{Float64, Float64}
    stable_neg_time::Tuple{Float64, Float64}
    positive_control_concentrations::Dict{String, Float64}
    concentration_reference::Float64
end

function quantification(data_fl, time_fl, method::RelativeFluorescence; plot_directory=nothing)
    # calibrate all of data_fl with blank timeseries
    calibrated_data_fl = calibrate(data_fl, time_fl, TimeseriesBlank(method.blank, time_fl))
    negative_controls = calibrate(method.negative_controls, time_fl, TimeseriesBlank(method.blank, time_fl))
    p_corr = calculate_p_corr(method.positive_controls, method.blank, time_fl, method.init_time, method.positive_control_concentrations, method.concentration_reference)

    f_neg_base = mean_in_window(negative_controls, time_fl, method.stable_neg_time)
    f_neg_base = mean(skipmissing(f_neg_base[1, :])) # average over negative controls

    out = deepcopy(calibrated_data_fl)
    for name in names(calibrated_data_fl)
        f_raw = calibrated_data_fl[!, name]
        out[!, name] = (f_raw .- f_neg_base) ./ (p_corr .- f_neg_base)
    end

    if !isnothing(plot_directory)
        p = plot()
        for col in names(out)
            plot!(p, time_fl[!, 1], out[!, col], label=col)
        end
        plot_path = joinpath(plot_directory, "quantification_relative.png")
        savefig(p, plot_path)
        # TODO plot p_corr
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
