using NonlinearSolve
using Dierckx
using GLM
using Statistics
using StatsBase
using ForwardDiff
using NaNMath
using Measurements
using CurveFit
using Plots
using Longwing

abstract type AbstractGrowthRateMethod <: AbstractPlateReaderMethod end

"""
    doubling_time(df, time_col, method::AbstractGrowthRateMethod; kwargs...)

Calculates the doubling time of a given DataFrame. Returns result in minutes.

Arguments:
- `df::DataFrame`: DataFrame containing the data.
- `time_col::DataFrame`: DataFrame containing the times.
- `method::AbstractGrowthRateMethod`: Method to use for calculating growth rate.
- `kwargs...`: Additional keyword arguments to pass to the growth rate method.
"""
function doubling_time(args...; kwargs...)
    return log(2) ./ growth_rate(args...; kwargs...)
end

function perform_recalibration(df, time_col, recalibrate, offset)
    if recalibrate isa String
        recalibrate = Symbol(recalibrate)
    end
    if (recalibrate == :negative && any(skipmissing(df[:, 1]) .<= 0)) || recalibrate == true || (recalibrate == :offset && any(skipmissing(df[:, 1]) .<= offset))
        recalibrant = minimum(skipmissing(df[:, 1])) - offset
        df = calibrate(df, time_col, MinData(); offset=offset)
    elseif recalibrate == false
        mask = df[!, 1] .> 0
        df = df[mask, [1]]
        time_col = time_col[mask, :]
        recalibrant = 0.0
    else
        if recalibrate in [:negative, :offset, true, false]
            recalibrant = 0.0
        else
            error("Invalid value for `recalibrate=$recalibrate`. Must be one of :negative, :offset, true, or false.")
        end
    end
    return df, time_col, recalibrant
end

function process_plot_directory(plot_directory)
    if plot_directory == :temp
        plot_directory = mktempdir()
        @info "Saving plots to temporary directory: $plot_directory"
    end
    if !isnothing(plot_directory) && !isdir(plot_directory)
        # Is directory/path doesn't exist, create it
        mkpath(plot_directory)
    end
    return plot_directory
end

function stripmissing(missing_data, other_col)
    tmp = hcat(missing_data, other_col)
    tmp = dropmissing(tmp)
    missing_data = tmp[:, Not(names(other_col)[1])]
    other_col = tmp[:, [names(other_col)[1]]]
    return missing_data, other_col
end

"""
    growth_rate(df, time_col, method::AbstractGrowthRateMethod)

Calculates the growth rate of a given dataframe. Returns in min^-1 using base e.

Arguments:
- `df::DataFrame`: DataFrame containing the data.
- `time_col::DataFrame`: DataFrame containing the times.
- `method::AbstractGrowthRateMethod`: Method to use for calculating growth rate.

Keywords:
- `recalibrate`: Whether to recalibrate the data using `calibrate` before calculating growth rate. Default is :negative (only if negative values are present in the well). Available options are `:negative`, `:offset` (only if values below the offset are present in the well), true, and false.
- `offset::Number`: If data is recalibrated, this is the offset applied after calibration. Default is 0.001.
- `plot_directory`: If provided, this is the directory to save plots of the growth curves with the fitted growth rate. Default is nothing (no plots saved). If :temp, plots will be saved to a temporary directory.
- `uncertainty::Bool`: If true, the function will also return the uncertainty of the growth rate (standard error). Default is false.
"""
function growth_rate(df, time_col, method::AbstractGrowthRateMethod; recalibrate=:negative, offset::Number=0.001, plot_directory=nothing, uncertainty::Bool=false)
    plot_directory = process_plot_directory(plot_directory)

    dict_2 = Dict()
    for i in names(df)
        od, times, _ = perform_recalibration(df[:, [i]], time_col, recalibrate, offset)
        od, times = stripmissing(od, times)
        if nrow(od) == 0
            @warn "No positive values found for column $i after filtering and removing missing values. Returning NaN."
            dict_2[i] = NaN
            continue
        end
        if uncertainty
            tmp = _growth_rate(od, times, method; plot_directory=plot_directory, uncertainty=uncertainty)
            dict_2[i] = Measurements.measurement(tmp["growth_rate"], tmp["growth_rate_uncertainty"])
        else
            dict_2[i] = _growth_rate(od, times, method; plot_directory=plot_directory, uncertainty=uncertainty)["growth_rate"]
        end
    end
    return DataFrame(dict_2)
end

"""
    max_od(df, time_col, method::AbstractGrowthRateMethod)

Calculates the maximum OD of a given dataframe. This may depend on the growth rate method
used.

Arguments:
- `df::DataFrame`: DataFrame containing the data.
- `time_col::DataFrame`: DataFrame containing the times.
- `method::AbstractGrowthRateMethod`.

Keywords:
- `recalibrate`: Whether to recalibrate the data using `calibrate` before calculating growth rate. Default is :negative (only if negative values are present in the well). Available options are `:negative`, `:offset` (only if values below the offset are present in the well), true, and false.
- `offset::Number`: If data is recalibrated, this is the offset applied after calibration. Default is 0.001.
- `plot_directory`: If provided, this is the directory to save plots of the growth curves with the fitted growth rate. Default is nothing (no plots saved). If :temp, plots will be saved to a temporary directory.
"""
function max_od(df, time_col, method::AbstractGrowthRateMethod; recalibrate=:negative, offset::Number=0.001, plot_directory=nothing)
    plot_directory = process_plot_directory(plot_directory)

    dict_2 = Dict()
    for i in names(df)
        od, times, recalibrant = perform_recalibration(df[:, [i]], time_col, recalibrate, offset)
        od, times = stripmissing(od, times)
        if nrow(od) == 0
            @warn "No positive values found for column $i after filtering and removing missing values. Returning NaN."
            dict_2[i] = NaN
            continue
        end
        dict_2[i] = _growth_rate(od, times, method; plot_directory=plot_directory, uncertainty=false)["maxOD"] + recalibrant
    end
    return DataFrame(dict_2)
end

"""
    time_to_max_growth(df, time_col, method::AbstractGrowthRateMethod)

Calculates the time at which growth is maximised.

Arguments:
- `df::DataFrame`: DataFrame containing the data.
- `time_col::DataFrame`: DataFrame containing the times.
- `method::AbstractGrowthRateMethod`.

Keywords:
- `recalibrate`: Whether to recalibrate the data using `calibrate` before calculating growth rate. Default is :negative (only if negative values are present in the well). Available options are `:negative`, `:offset` (only if values below the offset are present in the well), true, and false.
- `offset::Number`: If data is recalibrated, this is the offset applied after calibration. Default is 0.001.
- `plot_directory`: If provided, this is the directory to save plots of the growth curves with the fitted growth rate. Default is nothing (no plots saved). If :temp, plots will be saved to a temporary directory.
"""
function time_to_max_growth(df, time_col, method::AbstractGrowthRateMethod; recalibrate=:negative, offset::Number=0.001, plot_directory=nothing)
    plot_directory = process_plot_directory(plot_directory)

    dict_2 = Dict()
    for i in names(df)
        od, times, _ = perform_recalibration(df[:, [i]], time_col, recalibrate, offset)
        od, times = stripmissing(od, times)
        if nrow(od) == 0
            @warn "No positive values found for column $i after filtering and removing missing values. Returning NaN."
            dict_2[i] = NaN
            continue
        end
        dict_2[i] = _growth_rate(od, times, method; plot_directory=plot_directory, uncertainty=false)["time_to_max_growth"]
    end
    return DataFrame(dict_2)
end

"""
    od_at_max_growth(df, time_col, method::AbstractGrowthRateMethod)

The OD at which growth is maximised.

Arguments:
- `df::DataFrame`: DataFrame containing the data.
- `time_col::DataFrame`: DataFrame containing the times.
- `method::AbstractGrowthRateMethod`.

Keywords:
- `recalibrate`: Whether to recalibrate the data using `calibrate` before calculating growth rate. Default is :negative (only if negative values are present in the well). Available options are `:negative`, `:offset` (only if values below the offset are present in the well), true, and false.
- `offset::Number`: If data is recalibrated, this is the offset applied after calibration. Default is 0.001.
- `plot_directory`: If provided, this is the directory to save plots of the growth curves with the fitted growth rate. Default is nothing (no plots saved). If :temp, plots will be saved to a temporary directory.
"""
function od_at_max_growth(df, time_col, method::AbstractGrowthRateMethod; recalibrate=:negative, offset::Number=0.001, plot_directory=nothing)
    plot_directory = process_plot_directory(plot_directory)

    dict_2 = Dict()
    for i in names(df)
        od, times, recalibrant = perform_recalibration(df[:, [i]], time_col, recalibrate, offset)
        od, times = stripmissing(od, times)
        if nrow(od) == 0
            @warn "No positive values found for column $i after filtering and removing missing values. Returning NaN."
            dict_2[i] = NaN
            continue
        end
        dict_2[i] = _growth_rate(od, times, method; plot_directory=plot_directory, uncertainty=false)["od_at_max_growth"] + recalibrant
    end
    return DataFrame(dict_2)
end

"""
    lag_time(df, time_col, method::AbstractGrowthRateMethod)

Calculates the lag time of the growth curve. This is given as the t-axis intercept of the
tangent at the point of maximum growth (defined by the growth rate, time to max growth, and
od at max growth).

Arguments:
- `df::DataFrame`: DataFrame containing the data.
- `time_col::DataFrame`: DataFrame containing the times.
- `method::AbstractGrowthRateMethod`.

Keywords:
- `recalibrate`: Whether to recalibrate the data using `calibrate` before calculating growth rate. Default is :negative (only if negative values are present in the well). Available options are `:negative`, `:offset` (only if values below the offset are present in the well), true, and false.
- `offset::Number`: If data is recalibrated, this is the offset applied after calibration. Default is 0.001.
- `plot_directory`: If provided, this is the directory to save plots of the growth curves with the fitted growth rate. Default is nothing (no plots saved). If :temp, plots will be saved to a temporary directory.
"""
function lag_time(df, time_col, method::AbstractGrowthRateMethod; recalibrate=:negative, offset::Number=0.001, plot_directory=nothing)
    plot_directory = process_plot_directory(plot_directory)

    dict_2 = Dict()
    for i in names(df)
        od, times, recalibrant = perform_recalibration(df[:, [i]], time_col, recalibrate, offset)
        od, times = stripmissing(od, times)
        if nrow(od) == 0
            @warn "No positive values found for column $i after filtering and removing missing values. Returning NaN."
            dict_2[i] = NaN
            continue
        end
        tmp = _growth_rate(od, times, method; plot_directory=plot_directory, uncertainty=false)
        dict_2[i] = _lagtime(tmp["time_to_max_growth"], tmp["growth_rate"],
            tmp["od_at_max_growth"] + recalibrant, od[1, 1] + recalibrant)
    end
    return DataFrame(dict_2)
end

function _lagtime(time_at_max, growth_rate, od_at_max, od_at_start)
    lag_time = time_at_max - (1 / growth_rate) * NaNMath.log(od_at_max / od_at_start)
    return lag_time
end

@kwdef struct Endpoints <: AbstractGrowthRateMethod
    start_time::Float64
    end_time::Float64
end

function _growth_rate(df, time_col, method::Endpoints; plot_directory=nothing, uncertainty=false)
    if uncertainty
        throw(ArgumentError("Uncertainty estimation is not implemented for Endpoints method."))
    end
    start_od = at_time(df, time_col, method.start_time)
    end_od = at_time(df, time_col, method.end_time)
    if isempty(start_od) || isempty(end_od)
        @warn "When processing column $(names(df)[1]), no data points found before start_time=$(method.start_time). First timepoint is at $(first(time_col[:, 1]) / 60000) minutes. Returning NaN."
        return Dict(
            "growth_rate" => NaN,
            "time_to_max_growth" => NaN,
            "od_at_max_growth" => NaN,
            "maxOD" => NaN,
            "growth_rate_uncertainty" => NaN
        )
    end
    start_od = start_od[1]
    end_od = end_od[1]
    start_time = at_time(time_col, time_col, method.start_time)[1] / 60000
    end_time = at_time(time_col, time_col, method.end_time)[1] / 60000
    growth_rate = (NaNMath.log(end_od) - NaNMath.log(start_od)) /
        ((end_time) - (start_time))
    time_to_max_growth = (start_time + end_time) / 2
    od_at_max_growth = exp((NaNMath.log(start_od) + NaNMath.log(end_od)) / 2)
    summaries = Dict(
        "growth_rate" => growth_rate,
        "time_to_max_growth" => time_to_max_growth,
        "od_at_max_growth" => od_at_max_growth,
        "maxOD" => maximum(df[!, 1]),
        "growth_rate_uncertainty" => NaN,
    )
    if !isnothing(plot_directory)
        p = growth_plot(df, time_col ./ 60000, summaries)
        vline!(p, [start_time, end_time], label="Fitting Window", color=:blue, linestyle=:dot)
        savefig(p, joinpath(plot_directory, "growth_curve_$(nameof(typeof(method)))_$(names(df)[1]).png"))
    end
    return summaries
end

@kwdef struct MovingWindow <: AbstractGrowthRateMethod
    window_size::Int = 10
    method::Symbol = :Endpoints
end

function _growth_rate(df, time_col, method::MovingWindow; plot_directory=nothing, uncertainty=false)
    window_size = method.window_size
    max_rate = -Inf
    time_to_max_growth = NaN
    growth_rate_se = NaN
    od_at_max_growth = NaN
    best_window = nothing
    for j in 1:(nrow(df)-window_size+1)
        start_time = time_col[j, 1] / 60000
        end_time = time_col[j+window_size-1, 1] / 60000
        if method.method == :Endpoints
            rate = _growth_rate(df, time_col, Endpoints(start_time, end_time); uncertainty=uncertainty)
        elseif method.method == :LinearOnLog
            rate = _growth_rate(df, time_col, LinearOnLog(start_time, end_time); uncertainty=uncertainty)
        else
            error("Unknown moving window method: $(method.method).")
        end
        if rate["growth_rate"] > max_rate && !isinf(rate["growth_rate"])
            best_window = [start_time, end_time]
            max_rate = rate["growth_rate"]
            growth_rate_se = rate["growth_rate_uncertainty"]
            time_to_max_growth = (start_time + end_time) / 2
            od_at_max_growth = exp((NaNMath.log(at_time(df, time_col, start_time)[1]) +
                NaNMath.log(at_time(df, time_col, end_time)[1])) / 2)
        end
    end
    summaries = Dict(
        "growth_rate" => max_rate,
        "time_to_max_growth" => time_to_max_growth,
        "od_at_max_growth" => od_at_max_growth,
        "maxOD" => maximum(df[!, 1]),
        "growth_rate_uncertainty" => growth_rate_se
    )
    if !isnothing(plot_directory)
        p = growth_plot(df, time_col ./ 60000, summaries)
        if !isnothing(best_window)
            vline!(p, best_window, label="Fitting Window", color=:blue, linestyle=:dot)
        end
        savefig(p, joinpath(plot_directory, "growth_curve_$(nameof(typeof(method)))_$(method.method)_$(names(df)[1]).png"))
    end
    return summaries
end

@kwdef struct LinearOnLog <: AbstractGrowthRateMethod
    start_time::Float64
    end_time::Float64
end

function _growth_rate(df, time_col, method::LinearOnLog; plot_directory=nothing, uncertainty=false)
    start_time = method.start_time
    end_time = method.end_time

    n = length(time_col[!, 1])
    if n < 2
        @warn "Not enough data points ($n) after log scaling and removing ≤ 0 values."
        return Dict(
            "growth_rate" => NaN,
            "time_to_max_growth" => NaN,
            "od_at_max_growth" => NaN,
            "maxOD" => NaN,
            "growth_rate_uncertainty" => NaN
        )
    end

    # Get the indexes for the time range
    indexes = index_between_vals(
        time_col; minv=start_time * 60000, maxv=end_time * 60000)

    if isnothing(indexes[1]) || isnothing(indexes[2])
        @warn "No data points found between start_time=$(start_time) and \
        end_time=$(end_time). This may be due to negative OD values being removed."
        return Dict(
            "growth_rate" => NaN,
            "time_to_max_growth" => NaN,
            "od_at_max_growth" => NaN,
            "maxOD" => NaN,
            "growth_rate_uncertainty" => NaN
        )
    end
    indexes = indexes[1]:indexes[2]

    lm_df = DataFrame(
        time=time_col[indexes, 1] ./ 60000, log_od=NaNMath.log.(df[indexes, 1] ./ first(df[:, 1])))

    # Weight residuals due to log scale warping noise
    lm_model = lm(@formula(log_od~time), lm_df)
    weights = exp.(predict(lm_model))
    weights = weights .^ 2 ./ mean(weights .^ 2)
    lm_model = lm(@formula(log_od~time), lm_df; weights=aweights(weights))
    growth_rate = coef(lm_model)[2]
    time_to_max_growth = (start_time + end_time) / 2

    od_at_max_growth = geomean(skipmissing(between_times(df, time_col; mint=start_time, maxt=end_time)[:, 1]))
    se = stderror(lm_model)[2]
    summaries = Dict(
        "growth_rate" => growth_rate,
        "time_to_max_growth" => time_to_max_growth,
        "od_at_max_growth" => od_at_max_growth,
        "maxOD" => maximum(df[!, 1]),
        "growth_rate_uncertainty" => isnothing(uncertainty) ? NaN : se
    )
    if !isnothing(plot_directory)
        p = growth_plot(df, time_col ./ 60000, summaries)
        vline!(p, [start_time, end_time], label="Fitting Window", color=:blue, linestyle=:dot)
        savefig(p, joinpath(plot_directory, "growth_curve_$(nameof(typeof(method)))_$(names(df)[1]).png"))
    end
    return summaries
end

@kwdef struct ExpandingWindow <: AbstractGrowthRateMethod
    window_size::Int = 5
    growth_threshold::Float64 = 0.95
end

function _growth_rate(df, time_col, method::ExpandingWindow; plot_directory=nothing, uncertainty=false)
    window_size = method.window_size
    growth_threshold = method.growth_threshold

    n = length(time_col[!, 1])
    if n < 2
        @warn "Not enough data points ($n) after log scaling and removing ≤ 0 values."
        return Dict(
            "growth_rate" => NaN,
            "time_to_max_growth" => NaN,
            "od_at_max_growth" => NaN,
            "maxOD" => NaN,
            "growth_rate_uncertainty" => NaN
        )
    end

    gr = Dict{Tuple{Int,Int},Float64}()
    for j in 1:(nrow(df)-window_size+1)
        start_time = time_col[j, 1] / 60000
        end_time = time_col[j+window_size-1, 1] / 60000
        rate = _growth_rate(df, time_col, LinearOnLog(start_time, end_time))
        gr[(j, j + window_size - 1)] = rate["growth_rate"]
    end

    # Find the maximum growth rate and corresponding window
    growth_rate, max_window = findmax(gr)
    # Threshold for including windows in the linear fit (e.g. 90% of max growth rate)
    threshold = growth_threshold * growth_rate
    # Get windows that are above the threshold
    included_windows = [window for (window, rate) in gr if rate >= threshold]
    included_windows = sort(included_windows, by=x -> x[1])

    # Remove windows that are not contiguous with the max window
    new_included_windows = [included_windows[1]]
    if included_windows[1] == max_window
        seen_max_window = true
    else
        seen_max_window = false
    end
    for i in 2:length(included_windows)
        if included_windows[i] == max_window
            seen_max_window = true
        end
        last_window = included_windows[i-1]
        next_window = included_windows[i]
        if next_window[1] == last_window[1] + 1
            push!(new_included_windows, next_window)
        else
            if seen_max_window
                break
            else
                new_included_windows = [included_windows[i]]
            end
        end
    end
    full_window = (new_included_windows[1][1], new_included_windows[end][2])

    start_time = time_col[full_window[1], 1] / 60000
    end_time = time_col[full_window[2], 1] / 60000

    summaries = _growth_rate(df, time_col, LinearOnLog(start_time, end_time))
    if !isnothing(plot_directory)
        p = growth_plot(df, time_col ./ 60000, summaries)
        vline!(p, [start_time, end_time], label="Fitting Window",
            color=:blue, linestyle=:dot)
        savefig(p, joinpath(plot_directory, "growth_curve_$(nameof(typeof(method)))_$(names(df)[1]).png"))
    end
    return summaries
end

struct ParametricGrowthRate <: AbstractGrowthRateMethod
    func::Function
    initial_params::Vector{Float64}
    name::String
    lower_limit_flexible::Bool
end

function Logistic(; lower_limit_flexible=false)
    return ParametricGrowthRate(
        (p, t) -> p[4] .+ p[2] ./ (1 .+ exp.(4 * p[1] / p[2] .* (p[3] .- t) .+ 2)),
        [1.0, 4.0, 5.0, 0.0], "Logistic", lower_limit_flexible)
end

function Gompertz(; lower_limit_flexible=false)
    return ParametricGrowthRate(
        (p, t) -> p[4] .+ p[2] .* exp.(-exp.(p[1] .* exp(1) ./ p[2] .* (p[3] .- t) .+ 1)),
        [1.0, 4.0, 5.0, 0.0], "Gompertz", lower_limit_flexible)
end

function ModifiedGompertz(; lower_limit_flexible=false)
    return ParametricGrowthRate(
        (p, t) -> p[6] .+ p[2] .* exp.(-exp.((p[1] .* exp(1) ./ p[2]) .* (p[3] .- t) .+ 1)) .+
            p[2] .* exp.(p[4] * (t .- p[5])),
        [1.0, 4.0, 5.0, 0.001, 4.0, 0.0], "Modified_Gompertz", lower_limit_flexible)
end

function Richards(; lower_limit_flexible=false)
    return ParametricGrowthRate(
        (p, t) -> p[5] .+ p[2] ./ ((1 .+
            exp(p[4]) .* exp(1 + exp(p[4])) .*
            exp.(p[1] / p[2] .* (1 + exp(p[4]))^(1 + 1 / exp(p[4])) .*
            (p[3] .- t))) .^ (1 ./ exp(p[4]))),
        [1.0, 4.0, 5.0, 0.0, 0.0], "Richards", lower_limit_flexible)
end

function _growth_rate(df, time_col, method::ParametricGrowthRate; plot_directory=nothing, uncertainty=false)
    time_col = time_col ./ 60000
    t = time_col[!, 1]
    y = df[!, 1]

    t = t[y .> 0]
    y = y[y .> 0]
    ly = log.(y ./ first(y))

    n = length(t)
    if n < 2
        @warn "Not enough data points ($n) after log scaling and removing ≤ 0 values."
        return Dict(
            "growth_rate" => NaN,
            "time_to_max_growth" => NaN,
            "od_at_max_growth" => NaN,
            "growth_rate_uncertainty" => NaN,
            "maxOD" => NaN
        )
    end

    # initial guess: A ~ max(y), b small, c ~ end of time
    if method.lower_limit_flexible
        func = method.func
        u0 = method.initial_params
    else
        func = (p, t) -> method.func([p..., 0.0], t)
        u0 = method.initial_params[1:(end-1)]
    end

    prob = NonlinearCurveFitProblem(func, u0, t, ly)
    sol = solve(prob)

    weights = exp.(predict(sol))
    weights = 1 ./ weights

    prob = NonlinearCurveFitProblem(func, u0, t, ly, weights)
    sol = solve(prob)

    psol = coef(sol)
    growth_rate = psol[1]
    t_refined = range(first(t), last(t), length=100 * n)
    dOD = ForwardDiff.derivative.(ti -> func(psol, ti), t_refined)
    time_to_max_growth = t_refined[findmin(abs.(dOD .- growth_rate))[2]]
    od_at_max_growth = exp(func(psol, time_to_max_growth)) * first(y)
    if method.lower_limit_flexible
        maxOD = exp(psol[2] + psol[end]) * first(y)
    else
        maxOD = exp(psol[2]) * first(y)
    end

    summaries = Dict(
        "growth_rate" => growth_rate,
        "time_to_max_growth" => time_to_max_growth,
        "od_at_max_growth" => od_at_max_growth,
        "maxOD" => maxOD,
        "growth_rate_uncertainty" => uncertainty ? stderror(sol)[1] : NaN
    )
    if !isnothing(plot_directory)
        p = growth_plot(df, time_col, summaries)
        plot!(p, t_refined, ti -> func(psol, ti), label="Parametric Fit", color=:blue, linestyle=:dot)
        savefig(p, joinpath(plot_directory, "growth_curve_$(nameof(typeof(method)))_$(method.name)_$(names(df)[1]).png"))
    end
    return summaries
end

@kwdef struct FiniteDiff <: AbstractGrowthRateMethod
    type = :central
end

function _growth_rate(df, time_col, method::FiniteDiff; plot_directory=nothing, uncertainty=false)
    if uncertainty
        throw(ArgumentError("Uncertainty estimation is not implemented for FiniteDiff method."))
    end
    type = method.type
    time_col = time_col ./ 60000
    t = time_col[!, 1]
    y = df[!, 1]
    t = t[y .> 0]
    y = y[y .> 0]
    ly = log.(y ./ first(y))

    n = length(t)
    if n < 2
        @warn "Not enough data points ($n) after log scaling and removing ≤ 0 values."
        return Dict(
            "growth_rate" => NaN,
            "time_to_max_growth" => NaN,
            "od_at_max_growth" => NaN,
            "maxOD" => NaN,
            "growth_rate_uncertainty" => NaN
        )
    end

    growth_rate = 0.0
    time_to_max_growth = NaN
    od_at_max_growth = NaN

    if type == :central
        # first and last use one-sided differences
        for k in 2:(n-1)
            deriv = (ly[k+1] - ly[k-1]) / (t[k+1] - t[k-1])
            if deriv > growth_rate
                growth_rate = deriv
                time_to_max_growth = t[k]
                od_at_max_growth = y[k]
            end
        end
    elseif type == :onesided
        for k in 1:(n-1)
            deriv = (ly[k+1] - ly[k]) / (t[k+1] - t[k])
            if deriv > growth_rate
                growth_rate = deriv
                time_to_max_growth = (t[k] + t[k+1]) / 2
                od_at_max_growth = exp((ly[k] + ly[k+1]) / 2) * first(y)
            end
        end
    else
        error("Unknown finite difference type: $type")
    end

    summaries = Dict(
        "growth_rate" => growth_rate,
        "time_to_max_growth" => time_to_max_growth,
        "od_at_max_growth" => od_at_max_growth,
        "maxOD" => maximum(df[!, 1]),
        "growth_rate_uncertainty" => NaN
    )
    if !isnothing(plot_directory)
        p = growth_plot(df, time_col, summaries)
        savefig(p, joinpath(plot_directory, "growth_curve_$(nameof(typeof(method)))_$(method.type)_$(names(df)[1]).png"))
    end
    return summaries
end

@kwdef struct SmoothedSpline <: AbstractGrowthRateMethod
    order::Int = 3
    smoothness::Float64 = 0.01
    knots::Union{Nothing,Vector{Float64}} = nothing
end

function _growth_rate(df, time_col, method::SmoothedSpline; plot_directory=nothing, uncertainty=false)
    time_col = time_col ./ 60000
    t = time_col[!, 1]
    y = df[!, 1]

    t = t[y .> 0]
    y = y[y .> 0]
    ly = log.(y ./ first(y))

    n = length(t)
    if n < 2
        @warn "Not enough data points ($n) after log scaling and removing ≤ 0 values."
        return Dict(
            "growth_rate" => NaN,
            "time_to_max_growth" => NaN,
            "od_at_max_growth" => NaN,
            "maxOD" => NaN,
            "growth_rate_uncertainty" => NaN
        )
    end
    if isnothing(method.knots)
        spl = Dierckx.Spline1D(t, ly; k=method.order, s=method.smoothness)
    else
        spl = Dierckx.Spline1D(t, ly, method.knots; k=method.order)
    end

    t_refined = range(first(t), last(t), length=100 * n)
    weights = exp.(spl(t))
    weights = weights ./ mean(weights)
    if isnothing(method.knots)
        spl = Dierckx.Spline1D(t, ly; k=method.order, w=weights, s=method.smoothness)
    else
        spl = Dierckx.Spline1D(t, ly, method.knots; k=method.order, w=weights)
    end
    deriv = Dierckx.derivative(spl, t_refined)
    # maximum derivative (growth rate)
    growth_rate, i = findmax(deriv)
    time_to_max_growth = t_refined[i]
    od_at_max_growth = exp(spl(time_to_max_growth)) * first(y)
    if uncertainty
        # Estimate uncertainty using bootstrap resampling
        bootstrap_growth_rates = zeros(1000)
        # Calculate residuals
        fitted_values = spl(t)
        residuals = ly .- fitted_values
        knots = get_knots(spl)
        if length(knots) <= 2
            knots = [t[end]/2]
        else
            knots = knots[2:(end-1)]
        end
        rng = Xoshiro(0)
        for b in eachindex(bootstrap_growth_rates)
            resampled_residuals = sample(rng, residuals, n; replace=true) # add seeded rng
            new_data = fitted_values .+ resampled_residuals
            try
                new_spl = Dierckx.Spline1D(t, new_data, knots; k=method.order)
                weights = exp.(new_spl(t))
                weights = weights ./ mean(weights)
                new_spl = Dierckx.Spline1D(t, new_data, knots; k=method.order, w=weights)
                new_deriv = Dierckx.derivative(new_spl, t_refined)
                bootstrap_growth_rates[b] = maximum(new_deriv)
            catch e
                if contains(string(e), "The maximal number of iterations maxit")
                    bootstrap_growth_rates[b] = NaN
                    continue
                else
                    rethrow(e)
                end
            end
        end
        if all(isnan.(bootstrap_growth_rates))
            @warn "All bootstrap samples failed to converge for column $(names(df)[1]). Returning NaN for growth rate uncertainty."
            growth_rate_uncertainty = NaN
        else
            growth_rate_uncertainty = std(bootstrap_growth_rates[.!isnan.(bootstrap_growth_rates)])
        end
    else
        growth_rate_uncertainty = NaN
    end
    summaries = Dict(
        "growth_rate" => growth_rate,
        "time_to_max_growth" => time_to_max_growth,
        "od_at_max_growth" => od_at_max_growth,
        "maxOD" => maximum([exp(spl(ti)) * first(y) for ti in t_refined]),
        "growth_rate_uncertainty" => growth_rate_uncertainty
    )
    if !isnothing(plot_directory)
        p = growth_plot(df, time_col, summaries)
        plot!(p, t_refined, spl(t_refined), label = "Smoothed Spline Fit", color = :blue, linestyle = :dot)
        savefig(p, joinpath(plot_directory, "growth_curve_$(nameof(typeof(method)))_$(names(df)[1]).png"))
    end
    return summaries
end

function growth_plot(df, times, datapoints)
    p = plot(times[!, 1], log.(df[!, 1] ./ first(df[!, 1])), label="Data", xlabel="Time (min)", ylabel="log(OD/OD₀)", title="Growth curve: $(names(df)[1])", color=:black)
    lagtime = _lagtime(datapoints["time_to_max_growth"], datapoints["growth_rate"], datapoints["od_at_max_growth"], first(df[!, 1]))
    dydx = log(datapoints["od_at_max_growth"] ./ first(df[!, 1])) / (datapoints["time_to_max_growth"] - lagtime)
    x_low = lagtime
    x_high = log(datapoints["maxOD"] ./ first(df[!, 1]))/dydx + lagtime
    y_low = 0.0
    y_high = log(datapoints["maxOD"] ./ first(df[!, 1]))
    plot!(p, [x_low, x_high], [y_low, y_high], label="Max Growth Rate", color=:mediumorchid)
    hline!(p, [log(datapoints["maxOD"] ./ first(df[!, 1]))], label="Max OD", color=:red, linestyle=:dash)
    vline!(p, [lagtime], label="Lag Time", color=:green, linestyle=:dash)
    scatter!(p, [datapoints["time_to_max_growth"]], [log(datapoints["od_at_max_growth"] ./ first(df[!, 1]))], label="Max Growth Point", color=:red, marker=:x)
    plot!(p, legend=:best)
    return p
end
