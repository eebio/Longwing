abstract type AbstractFluorescenceMethod <: AbstractPlateReaderMethod end

"""
    fluorescence(data_fl, time_fl, data_od, time_od, method::AbstractFluorescenceMethod;
        plot_directory = nothing)

Calculate fluorescence per cell (normalised by OD).

# Arguments
- `data_fl`: a DataFrame of fluorescence measurements.
- `time_fl`: a DataFrame of times for the fluorescence measurements.
- `data_od`: a DataFrame of OD measurements.
- `time_od`: a DataFrame of times for the OD measurements.
- `method`: the method to use for calculating fluorescence per cell.

# Keyword Arguments
- `plot_directory`: the directory to save plots to. If `nothing`, no plots are saved. If
    `:temp`, a temporary directory is created and used. Otherwise, describes a directory
    path to save plots to.
"""
function fluorescence end

@kwdef struct RatioAtTime <: AbstractFluorescenceMethod
    time::Float64
end

function fluorescence(data_fl, time_fl, data_od, time_od, method::RatioAtTime; plot_directory=nothing)
    plot_directory = process_plot_directory(plot_directory)
    time = method.time
    fluorescence_at_time = at_time(data_fl, time_fl, time)
    od_at_time = at_time(data_od, time_od, time)
    out = DataFrame()
    if !isnothing(plot_directory)
        t = sort(union(skipmissing(time_fl[:, 1]), skipmissing(time_od[:, 1]))) ./ 60000
        t = t[t .>= max(minimum(skipmissing(time_fl[:, 1])), minimum(skipmissing(time_od[:, 1]))) ./ 60000]
        fl_new = [DataFrame(at_time(data_fl, time_fl, t[i])) for i in 1:length(t)]
        od_new = [DataFrame(at_time(data_od, time_od, t[i])) for i in 1:length(t)]
        fl_new = vcat(fl_new...)
        od_new = vcat(od_new...)
    end
    for col in names(od_at_time)
        if isnan(time) || ! (fluorescence_at_time isa DataFrameRow) || ! (od_at_time isa DataFrameRow)
            @warn "Invalid time of $time specified for fluorescence per cell. Returning NaN for column $col."
            out[!, col] = [NaN]
            continue
        end
        out[!, col] = [fluorescence_at_time[col] / od_at_time[col]]
        if !isnothing(plot_directory)
            plot_path = joinpath(plot_directory, "fluorescence_per_cell_$col.png")
            # Create a time vector that is the union of the two
            p = plot(t, fl_new[:, col] ./ od_new[:, col], label="Fluorescence/OD", xlabel="Time", ylabel="Fluorescence/OD", title="Fluorescence per OD at $(round(time; digits = 1)) min for $col")
            vline!([time], label="Time of interest", color=:red, legend=:best)
            savefig(p, plot_path)
        end
    end
    return out
end

struct RatioAtMaxGrowth <: AbstractFluorescenceMethod
    method::AbstractGrowthRateMethod
    kwargs::Dict{Symbol,Any}
end

function RatioAtMaxGrowth(method::AbstractGrowthRateMethod; kwargs...)
    return RatioAtMaxGrowth(method, kwargs)
end

function RatioAtMaxGrowth(; method::AbstractGrowthRateMethod, kwargs...)
    return RatioAtMaxGrowth(method; kwargs...)
end

function fluorescence(data_fl, time_fl, data_od, time_od, method::RatioAtMaxGrowth; plot_directory=nothing)
    time = time_to_max_growth(data_od, time_od, method.method; method.kwargs...)
    out = DataFrame()
    for col in names(data_od)
        out[!, col] = Longwing.fluorescence(data_fl[:, [col]], time_fl, data_od[:, [col]], time_od, RatioAtTime(time[1, col]); plot_directory=plot_directory)[:, col]
    end
    return out
end
