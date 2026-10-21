using GaussianMixtures
using NonlinearSolve
using StatsBase
using Plots
using NaNMath
using Random

function cluster(data, method; plot_directory = nothing)
    n = length(method.mef)

    # Perform clustering
    maxll = -Inf
    local best_gmm
    for _ in 1:method.nRepeats
        gmm = GMM(n, data; nInit = method.nInit, nIter=0)
        em!(gmm, data; nIter = method.nIter, varfloor = 1e-8)
        ll = avll(gmm, data)
        if ll > maxll
            best_gmm = gmm
            maxll = ll
        end
    end
    gmm = best_gmm

    # Plot data
    if !isnothing(plot_directory)
        datarange = maximum(data) - minimum(data)
        # Check for 1 very large bin
        h = fit(Histogram, data[:, 1], range(minimum(data) - datarange/500, stop=maximum(data) + datarange/500, length=500))
        sorted_weights = sort(h.weights, rev=true)
        if sorted_weights[1] > 2 * sorted_weights[2]
            ylims = (0, sorted_weights[2] * 1.5)
        else
            ylims = nothing
        end
        p = histogram(data; ylims=ylims, bins = range(minimum(data) - datarange/500, stop = maximum(data) + datarange/500, length = 500),
            linecolor=nothing, label=nothing, xlabel = "Transform('$(method.channel)') (RFI)",
            ylabel = "Count", title = "MEF Calibration: Fluorescence Data",
        )
        savefig(p, joinpath(plot_directory, "mef_calibration_fluorescence_data.png"))
    end

    # Collect into clusters
    prob_pos = gmmposterior(gmm, data)[1]
    ass = [findmax(prob_pos[i, :])[2] for i in 1:size(data, 1)] # Vector of cluster indexes
    clusters = [data[ass .== i, 1] for i in 1:n]

    # Sort clusters by median
    summaries = [isempty(c) ? NaN : method.summary(c) for c in clusters]
    if any(isnan.(summaries))
        err = true
        summaries = summaries[.!isnan.(summaries)]
    else
        err = false
    end
    sorted_idx = sortperm(summaries)
    sorted_clusters = clusters[sorted_idx]
    sorted_summaries = summaries[sorted_idx]

    if !isnothing(plot_directory)
        # Plot data split by clusters
        p = histogram(xlabel = "Transform('$(method.channel)') (RFI)",
            ylabel = "Count", title = "MEF Calibration: Clusters")
        for i in eachindex(sorted_clusters)
            c = sorted_clusters[i]
            if length(c) == 0
                continue
            end
            histogram!(p, c;
                ylims=ylims,
                bins = range(minimum(data) - datarange/500, stop = maximum(data) + datarange/500, length = 500),
                linecolour = nothing, colour = i, label = "Cluster $i") # If any data includes 0, it'll break here
            vline!(p, [method.summary(c)]; linecolour = i, linestyle = :dash, label=nothing)
        end
        savefig(p, joinpath(plot_directory, "mef_calibration_clusters.png"))
    end

    if err
        error("MEF clustering failed. One or more clusters were empty. Try adjusting the gating, seed, or nRepeats. Alternatively, you can manually specify the calibration points with calibrate(df::DataFrame, summaries::Vector, method::MEF; plot_directory = nothing).")
    end

    return sorted_clusters, sorted_summaries
end

@kwdef struct MEF
    beads::DataFrame
    mef::Vector
    channel::String
    summary::Function = median
    seed::Int = 0
    nInit::Int = 100
    nIter::Int = 100
    nRepeats::Int = 10
    transform::Transform = Identity()
end

function calibrate(df, method::MEF; plot_directory = nothing)
    if plot_directory == :temp
        plot_directory = mktempdir()
        @info "Plot directory for MEF calibration set to temporary directory: $plot_directory"
    end
    if !isnothing(plot_directory) && !isdir(plot_directory)
        # Is directory/path doesn't exist, create it
        mkpath(plot_directory)
    end

    mef = deepcopy(method.mef)

    # Transform the data and collect into a vector
    data = transform(method.beads, method.transform)[:, method.channel]
    data = reshape(data, :, 1)
    data = convert(Matrix{Float64}, data)

    # Cluster data
    # GaussianMixtures doesn't support an rng argument, so we have to set the global seed
    Random.seed!(method.seed)
    clusters, summaries = cluster(data, method; plot_directory)
    # Untransform summaries to original scale for later use in curve fitting
    summaries = untransform(summaries, method.transform)

    # Are any populations too close to max or min
    keep_population = fill(true, length(clusters))
    min_channel = method.channel * ".min"
    max_channel = method.channel * ".max"
    for i in eachindex(clusters)
        cluster = clusters[i]
        if length(cluster) == 0
            continue
        end
        μ = mean(cluster)
        σ = std(cluster)
        lb = transform(method.beads[1, min_channel], method.transform)
        ub = transform(method.beads[1, max_channel], method.transform)
        if μ - 2.5 * σ < lb || μ + 2.5 * σ > ub
            keep_population[i] = false
        end
        if isnothing(mef[i])
            keep_population[i] = false
        end
    end
    if any(keep_population .== false)
        @info "Removing population(s) $(findall(keep_population .== false)) from MEF calibration."
    end
    if sum(keep_population) < 3
        error("Not enough populations to calibrate. Populations too close to max or min are removed. Need at least 3 populations to fit but only $(length(clusters)) remain.")
    end
    mef = mef[keep_population]
    clusters = clusters[keep_population]
    summaries = summaries[keep_population]

    method = MEF(method.beads,
        mef, # Keep only the MEF values for the populations that are kept
        method.channel, method.summary, method.seed, method.nInit,
        method.nIter, method.nRepeats, method.transform)

    return calibrate(df, summaries, method; plot_directory)
end

function calibrate(df::DataFrame, summaries::Vector, method::MEF; plot_directory = nothing)
    to_mef = fit_standard_curve(summaries, method.mef, method, plot_directory)

    df = deepcopy(df)

    # Apply standard curve to data
    df[!, method.channel] = to_mef.(df[!, method.channel])
    df[!, "$(method.channel).min"] = to_mef.(df[!, "$(method.channel).min"])
    df[!, "$(method.channel).max"] = to_mef.(df[!, "$(method.channel).max"])
    return df
end

function fit_standard_curve(summaries, mef, method, plot_directory)
    # Setup
    # u = [m, b, log(bead_auto_fluorescence)]
    residuals! = function (res, u, _)
        for mefi in eachindex(mef)
            res[mefi] = NaNMath.log(mef[mefi] + exp(u[3])) -
                        u[1] * NaNMath.log(summaries[mefi]) - u[2]
        end
        return nothing
    end

    # Initial guesses:
    # - m estimated from final two points,
    # - b estimated from final point and initial m,
    # - auto_flu estimated from first point
    m = (NaNMath.log(mef[end]) - NaNMath.log(mef[end - 1])) /
        (NaNMath.log(summaries[end]) - NaNMath.log(summaries[end - 1]))
    b = NaNMath.log(mef[end]) - m * NaNMath.log(summaries[end])
    log_auto_flu = log(mef[1])

    # Solve for MLE parameters
    u0 = [m, b, log_auto_flu]
    nonlinfun = NonlinearFunction(residuals!, resid_prototype = zeros(length(mef)))
    prob = NonlinearLeastSquaresProblem(nonlinfun, u0)
    sol = NonlinearSolve.solve(prob; verbose = false, maxiters = 200)

    # Standard curve function
    function to_mef(x)
        return sign.(x) .* exp(sol.u[2]) .* (abs.(x) .^ sol.u[1])
    end

    # Plot standard curve
    if !isnothing(plot_directory)
        p = scatter(summaries, mef; label = "Beads: $(method.summary)",
            xlabel = "$(method.channel) (RFI)", ylabel = "$(method.channel) (MEF)",
            xscale = :log10, yscale = :log10, legend = :bottomright,
            title = "MEF Calibration: Standard Curve")
        plot!(p, logrange(summaries[1]/100, summaries[end]*10, length = 100), to_mef;
            label = "Standard curve", xscale = :log10, yscale = :log10)
        plot!(p, logrange(summaries[1]/100, summaries[end]*10, length = 100),
            x -> (to_mef(x) - exp(sol.u[3]) > 0 ? to_mef(x) - exp(sol.u[3]) : NaN);
            label = "Beads model", xscale = :log10, yscale = :log10)
        savefig(p, joinpath(plot_directory, "mef_calibration_standard_curve.png"))
    end

    return to_mef
end
