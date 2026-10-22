using StatsBase
using KernelDensity
using Meshes

abstract type AbstractGatingMethod <: AbstractLongwingMethod end

abstract type AbstractAutoGate <: AbstractGatingMethod end

abstract type AbstractManualGate <: AbstractGatingMethod end

abstract type AbstractLogicalGate <: AbstractGatingMethod end

"""
    gate(data, method::AbstractGatingMethod)

Filter `data` to only include events within the gate defined by `method`.

Arguments:
- `data::DataFrame`: Longwing population data.
- `method::AbstractGatingMethod`: The method and settings to use for gating.
"""
function gate end

@kwdef struct KDE <: AbstractAutoGate
    channels::Vector{String}
    gate_frac::Float64 = 0.65
    nbins::Int64 = 1024
    transform_x::Union{Function,Transform} = Logicle()
    transform_y::Union{Function,Transform} = Logicle()
end

function gate(data, method::KDE)
    data = deepcopy(data)
    channels = method.channels
    gate_frac = method.gate_frac
    nbins = method.nbins
    length(channels) == 2 || error("2 channels must be specified for density gating.")
    x = data[!, [channels[1]]]
    y = data[!, [channels[2]]]
    trans_x = method.transform_x
    trans_y = method.transform_y
    if trans_x isa Function
        trans_x = Transform(method.transform_x, identity)
    end
    if trans_y isa Function
        trans_y = Transform(method.transform_y, identity)
    end
    x = transform(x, trans_x)[!, channels[1]]
    y = transform(y, trans_y)[!, channels[2]]
    N = length(x)

    train_x = x[.!isnan.(x) .& .!isnan.(y) .& .!isinf.(x) .& .!isinf.(y)]
    train_y = y[.!isnan.(x) .& .!isnan.(y) .& .!isinf.(x) .& .!isinf.(y)]
    kd = kde((train_x, train_y))

    ik = InterpKDE(kd)

    x_bins = range(minimum(train_x), stop=maximum(train_x), length=nbins + 1)
    y_bins = range(minimum(train_y), stop=maximum(train_y), length=nbins + 1)

    x_mids = (x_bins[1:(end-1)] .+ x_bins[2:end]) ./ 2
    y_mids = (y_bins[1:(end-1)] .+ y_bins[2:end]) ./ 2

    density_values = [pdf(ik, xi, yi) for xi in x_mids for yi in y_mids]

    # Compute the bin index for each point in the data
    bin_indices = Int[]
    for j in 1:N
        x_j = x[j]
        y_j = y[j]
        x_bin_idx = argmin(abs.(x_mids .- x_j))
        y_bin_idx = argmin(abs.(y_mids .- y_j))
        combined_index = (x_bin_idx - 1) * length(y_mids) + y_bin_idx
        push!(bin_indices, combined_index)
    end

    fraction_to_keep = gate_frac
    sorted_indices = sortperm(density_values, rev=true)

    # Group point indices by bin so each bin's points can be looked up in O(1)
    points_in_bin = Dict{Int,Vector{Int}}()
    for j in 1:N
        push!(get!(points_in_bin, bin_indices[j], Int[]), j)
    end

    indicies_to_keep = Int[]
    while length(indicies_to_keep) < ceil(Int, fraction_to_keep * N) &&
        !isempty(sorted_indices)
        i = popfirst!(sorted_indices)
        append!(indicies_to_keep, get(points_in_bin, i, Int[]))
    end

    return data[sort(indicies_to_keep), :]
end

@kwdef struct HighLowGate <: AbstractManualGate
    channel::String
    max::Float64 = Inf
    min::Float64 = -Inf
end

function gate(data, method::HighLowGate)
    dat_mask = method.min .<= data[!, method.channel] .< method.max
    return data[dat_mask, :]
end

@kwdef struct RectangleGate <: AbstractManualGate
    channel_x::String
    channel_y::String
    x_min::Float64
    x_max::Float64
    y_min::Float64
    y_max::Float64
end

function gate(data, method::RectangleGate)
    dat_mask = (method.x_min .<= data[!, method.channel_x] .< method.x_max) .&
        (method.y_min .<= data[!, method.channel_y] .< method.y_max)
    return data[dat_mask, :]
end

@kwdef struct QuadrantGate <: AbstractManualGate
    channel_x::String
    channel_y::String
    x_cutoff::Float64
    y_cutoff::Float64
    quadrant::Int64
end

function gate(data, method::QuadrantGate)
    if method.quadrant == 1
        dat_mask = (data[!, method.channel_x] .>= method.x_cutoff) .&
            (data[!, method.channel_y] .>= method.y_cutoff)
    elseif method.quadrant == 2
        dat_mask = (data[!, method.channel_x] .>= method.x_cutoff) .&
            (data[!, method.channel_y] .< method.y_cutoff)
    elseif method.quadrant == 3
        dat_mask = (data[!, method.channel_x] .< method.x_cutoff) .&
            (data[!, method.channel_y] .< method.y_cutoff)
    elseif method.quadrant == 4
        dat_mask = (data[!, method.channel_x] .< method.x_cutoff) .&
            (data[!, method.channel_y] .>= method.y_cutoff)
    else
        error("Quadrant must be between 1 and 4.")
    end
    return data[dat_mask, :]
end

@kwdef struct PolygonGate <: AbstractManualGate
    channel_x::String
    channel_y::String
    points::Vector{Tuple{Float64,Float64}}
end

function gate(data, method::PolygonGate)
    poly = PolyArea(method.points)
    combined_data = zip(data[!, method.channel_x], data[!, method.channel_y])
    dat_mask = [Point(xi, yi) ∈ poly for (xi, yi) in combined_data]
    return data[dat_mask, :]
end

struct EllipseGate <: AbstractManualGate
    channel_x::String
    channel_y::String
    center::Tuple{Float64,Float64}
    a::Float64
    b::Float64
    angle::Float64
end

function EllipseGate(; channel_x::String, channel_y::String, center=nothing, points)
    n = length(points)
    if (n < 3 && !isnothing(center)) || (n < 5 && isnothing(center))
        error("At least 3 points and a center or 5 points without a center are required to \
            fit an ellipse.")
    end
    # Fit ellipse to points
    xs = [p[1] for p in points]
    ys = [p[2] for p in points]
    if length(points) < 5
        # Add extra points on ellipse until we have 5
        for i in (length(points)+1):5
            point = points[i-length(points)]
            push!(xs, point[1] + 2 * (center[1] - point[1]))
            push!(ys, point[2] + 2 * (center[2] - point[2]))
        end
        points = zip(xs, ys)
    end
    # Fit ellipse to 5 points
    xs = [p[1] for p in points]
    ys = [p[2] for p in points]
    a, b, θ, centerx, centery = fit_ellipse(xs, ys)
    center = (centerx, centery)
    angle = rad2deg(θ)
    return EllipseGate(channel_x, channel_y, center, a, b, angle)
end

function gate(data, method::EllipseGate)
    cos_angle = cosd(method.angle)
    sin_angle = sind(method.angle)
    cx, cy = method.center
    a, b = method.a, method.b
    dat_mask = zeros(Bool, length(data[!, method.channel_x]))
    for (i, xi, yi) in zip(1:event_count(data), data[!, method.channel_x],
        data[!, method.channel_y])
        # Rotate points onto ellipse axes
        x_rot = cos_angle * (xi - cx) + sin_angle * (yi - cy)
        y_rot = -sin_angle * (xi - cx) + cos_angle * (yi - cy)
        # Check against canonical ellipse equation
        val = (x_rot^2) / (a^2) + (y_rot^2) / (b^2)
        dat_mask[i] = val <= 1.0
    end
    return data[dat_mask, :]
end

"""
    event_count(data)

Count the number of events in the flow cytometry data.

Arguments:
- `data::DataFrame`: Longwing population data.
"""
function event_count(data)
    return nrow(data)
end

"""
    gated_proportion(data, gate)
    gated_proportion(data_before, data_after)

Calculate the proportion of events remaining after gating.

Arguments:
- `data::DataFrame`: Longwing population data.
- `gate::AbstractGatingMethod`: A gating method to report on.
- `data_before::DataFrame`: Longwing population data before gating.
- `data_after::DataFrame`: Longwing population data after gating.
"""
function gated_proportion(data, method::AbstractGatingMethod)
    total_events = event_count(data)
    gated_data = gate(data, method)
    gated_events = event_count(gated_data)
    return gated_events / total_events
end

function gated_proportion(data_before, data_after)
    total_events = event_count(data_before)
    gated_events = event_count(data_after)
    return gated_events / total_events
end

# Logical operations on gates
struct AndGate{X,Y} <:
    AbstractLogicalGate where {X<:AbstractGatingMethod,Y<:AbstractGatingMethod}
    gate1::X
    gate2::Y
end

struct OrGate{X,Y} <:
    AbstractLogicalGate where {X<:AbstractGatingMethod,Y<:AbstractGatingMethod}
    gate1::X
    gate2::Y
end

struct NotGate{X} <: AbstractLogicalGate where {X<:AbstractGatingMethod}
    gate1::X
end

function Base.:&(g1::AbstractGatingMethod, g2::AbstractGatingMethod)
    return AndGate(g1, g2)
end

function Base.:|(g1::AbstractGatingMethod, g2::AbstractGatingMethod)
    return OrGate(g1, g2)
end

function Base.:!(g::AbstractGatingMethod)
    return NotGate(g)
end

function and(g1::AbstractGatingMethod, g2::AbstractGatingMethod)
    return g1 & g2
end
function or(g1::AbstractGatingMethod, g2::AbstractGatingMethod)
    return g1 | g2
end

function not(g::AbstractGatingMethod)
    return !g
end

function gate(data, method::AndGate)
    data = gate(data, method.gate1)
    data = gate(data, method.gate2)
    return data
end

function gate(data, method::OrGate)
    data1 = gate(data, method.gate1)
    data2 = gate(data, method.gate2)
    mask1 = [id ∈ data1.id for id in data.id]
    mask2 = [id ∈ data2.id for id in data.id]
    final_mask = mask1 .| mask2
    return data[final_mask, :]
end

function gate(data, method::NotGate)
    data1 = gate(data, method.gate1)
    mask1 = [id ∈ data1.id for id in data.id]
    final_mask = .!mask1
    return data[final_mask, :]
end
