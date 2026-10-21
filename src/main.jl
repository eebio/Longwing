"""
    remove_subcols(df, sub)

Gets rid of certain sub col ids in the col names.

e.g. \n
    remove flo
    a1.flo -> a1
"""
function remove_subcols(df, sub)
    df = rename(s -> replace(s, Regex("." * string(sub)) => ""), df)
    return df
end

"""
    filter_row(lw, group)

Filter the original lw.samples dataframe by a specific group defined in the Longwing file.

Arguments:
- `lw::lw_zones`: The Longwing data to filter.
- `group::Union{String,Vector}`: what group/groups to filter by.
"""
function filter_row(lw, group)
    return lw.samples[lw.samples[!, group] .== true, :]
end

function filter_channel(df::DataFrame, channel)
    channel = string(channel)
    if !any(occursin.(".", names(df)))
        error("DataFrame does not contain any channels. It has already been channel-indexed.")
    end
    return remove_subcols(df[:, filter(colname -> channel in split(colname, ".") || colname == "id" || colname == "longwing_well", names(df))], channel)
end

"""
    filter_col(df, reg_l)

Filters a df by a set of columns or parts of columns given in reg_l.
reg_l is joined to form regex using `|`.

Arguments:
- `df::DataFrame`: DataFrame to filter.
- `reg_l::Vector{String}`: Vector of strings to filter by.
"""
function filter_col(df::DataFrame, reg_l)
    reg_l = Regex(join(string.(reg_l), "|"))
    return df[:, filter(colname -> occursin(reg_l, string(colname)), names(df))]
end

function filter_col(df::Expr, reg_l)
    return filter_col(eval(df), reg_l)
end

"""
    form_df(df)

Creates the data frame from the dataframe it is passed.
This is to turn the lw.samples.values arrays into dfs.

Arguments:
- `df::DataFrame`: A dataframe of lw.samples to parse.
"""
function form_df(df::DataFrame)
    max_dat = maximum(length.(df.values))
    return hcat([DataFrame(j.name => [j.values; fill(missing, max_dat - length(j.values))])
                 for j in eachrow(df)]...)
end

function form_df(df::Expr)
    return form_df(eval(df))
end

"""
    find_group(lw,grn)

Finds a specific group from the original lw.groups dataframe.
Returns the sample names.

Arguments:
- `lw::lw_zones`: The data set to search.
- `grn::String`: A string of a group name which can be used to filter the original
    dataframe.
"""
function find_group(lw, grn)
    return lw.groups[lw.groups.group .== grn, :sample_IDs][1]
end

function get_group(lw, grn)
    # Is the group a flow group?
    sample_types = lw.samples.type[getproperty(lw.samples, grn)]
    if all(sample_types .== "population")
        data = [deepcopy(Longwing.to_rfi(lw, sample)) for sample in find_group(lw, string(grn))]
        # Check the data is compatible
        # All samples must have the same channels
        @assert all([sort(names(d))==sort(names(data[1])) for d in data]) "Samples in group $grn have different channels."
        tmp = data[1]
        for d in data[2:end]
            id_offset = maximum(tmp.id)
            d.id .+= id_offset
            tmp = vcat(tmp, d)
        end
        return tmp
    elseif all(sample_types .== "timeseries")
        return Longwing.form_df(Longwing.filter_row(lw, grn))
    else
        error("Group $grn contains mixed sample types (population and timeseries).")
    end
end

function get_sample(lw, sample)
    # Is the sample a flow sample?
    sample_types = lw.samples[sample .== get_sample_id.(lw.samples.name), "type"]
    if all(sample_types .== "population")
        return Longwing.to_rfi(lw, sample)
    end
    # Otherwise return DataFrame
    return Longwing.form_df(lw.samples[sample .== get_sample_id.(lw.samples.name), :])
end

function get_sample_id(sample)
    return first(splitext(sample))
end

function index_between_vals(df; minv=(-Inf), maxv=Inf)
    if all(ismissing.(df[:, 1])) || count(x -> minv <= x <= maxv, skipmissing(df[:, 1])) == 0
        return nothing, nothing
    end
    return findfirst(x -> minv <= x <= maxv, skipmissing(df[:, 1])), findlast(x -> minv <= x <= maxv, collect(skipmissing(df[:, 1])))
end

"""
    between_times(df, time_col; mint=-Inf, maxt=Inf)

Returns the DataFrame between two timepoints.

All other data is set to `missing`.

Arguments:
- `df::DataFrame`: DataFrame to work on.
- `time_col::DataFrame`: DataFrame of time values.
- `mint::Float64=-Inf`: Minimum time in mins.
- `maxt::Float64=Inf`: Max time in mins.
"""
function between_times(df::DataFrame, time_col::DataFrame; mint=(-Inf), maxt=Inf)
    # Do time calculations in seconds to avoid floating point math
    return between(df, time_col; min_value=mint * 60000, max_value=maxt * 60000)
end

"""
    between(df, range_df; min_value=-Inf, max_value=Inf)
    between(df; min_value=-Inf, max_value=Inf)

Replace out of range values with `missing`.

Out of range values are determined by `min_value` .<= `range_col` .<= `max_value`.
If `range_col` is not provided, by `min_value` .<= df .<= `max_value`.

If `range_col` has one column, the associate row indexes with `min_value` .<= `range_col` .<= `max_value` are broadcast along all columns of `df`.
If `range_col` has multiple columns, the column names should match those of `df`.

Arguments:
- `df::DataFrame`: DataFrame to subset.
- `range_df::DataFrame`: DataFrame of values to filter by.
- `min_value=-Inf`: Minimum value.
- `max_value=Inf`: Maximum value.
"""
function between(df::DataFrame, range_df; min_value=(-Inf), max_value=Inf)
    df = deepcopy(df)
    allowmissing!(df)
    if range_df isa AbstractVector || ncol(range_df) == 1
        # Find indicies in range_df and replace out of range values with missing
        indicies = index_between_vals(range_df; minv=min_value, maxv=max_value)
        for col in names(df)
            for i in 1:nrow(df)
                if isnothing(indicies[1]) || isnothing(indicies[2])
                    df[i, col] = missing
                else
                    df[i, col] = ifelse(i < indicies[1] || i > indicies[2], missing, df[i, col])
                end
            end
        end
    else
        @assert issetequal(names(df), names(range_df)) "DataFrame columns must match for range filtering."
        for col in names(df)
            indicies = index_between_vals(range_df[!, col]; minv=min_value, maxv=max_value)
            for i in 1:nrow(df)
                if isnothing(indicies[1]) || isnothing(indicies[2])
                    df[i, col] = missing
                else
                    df[i, col] = ifelse(i < indicies[1] || i > indicies[2], missing, df[i, col])
                end
            end
        end
    end
    return df
end

function between(df::DataFrame; min_value=(-Inf), max_value=Inf)
    df = deepcopy(df)
    allowmissing!(df)
    for col in names(df)
        indicies = index_between_vals(df[!, [col]]; minv=min_value, maxv=max_value)
        for i in 1:nrow(df)
            if isnothing(indicies[1]) || isnothing(indicies[2])
                df[i, col] = missing
            else
                df[i, col] = ifelse(i < indicies[1] || i > indicies[2], missing, df[i, col])
            end
        end
    end
    return df
end

"""
    at_time(df, time_col, time_point)

Returns values at a specific time point.
If no value at specific timepoint, return the last recording before the timepoint.
If `time_point < minimum(time_col)`, return `nothing`.

Arguments:
- `df::DataFrame`: DataFrame on which to work.
- `time_col::DataFrame`: Time values in a DataFrame.
- `time_point::Float64`: Time point in mins at which to report the measurement.
"""
function at_time(df::DataFrame, time_col::DataFrame, time_point)
    tvals = index_between_vals(time_col; minv=0, maxv=round(time_point * 60000))
    if isnothing(tvals[2])
        @warn "No values found at or before $time_point."
        # Return empty dataframe of the same type
        return df[1:0, :]
    end
    return df[tvals[2], :]
end

"""
    at(df, range_df, target_value)

Return the values of `df` at the index of `range_df` where `range_df` is equal to `target_value`.

If no value in `range_df` is equal to `target_value`, return the last recording before the `target_value`.

If `range_df` has one column, the same index will be applied to all columns of `df`.
If `range_df` has multiple columns, the column names should match those of `df` and a new index will be computed for each column.

Arguments:

- `df::DataFrame`: The DataFrame you are getting the indexes from.
- `range_df`: The data frame by which to filter.
- `target_value::Number`: Defines the threshold value for filtering.
"""
function at(df::DataFrame, range_df, target_value)
    dict_2 = Dict()
    if range_df isa AbstractVector || ncol(range_df) == 1
        for i in names(df)
            if all(ismissing.(range_df[:, 1])) || target_value < minimum(skipmissing(range_df[:, 1]))
                @warn "No values found at or before $target_value."
                dict_2[i] = missing
            else
                dict_2[i] = df[findlast(x -> x <= target_value, collect(skipmissing(range_df[:, 1]))), i]
            end
        end
    else
        @assert issetequal(names(df), names(range_df)) "DataFrame columns must match for `at` filtering."
        for i in names(df)
            if all(ismissing.(range_df[!, i])) || target_value < minimum(skipmissing(range_df[!, i]))
                @warn "No values found at or before $target_value for column $i."
                dict_2[i] = missing
            else
                dict_2[i] = df[findlast(x -> x <= target_value, collect(skipmissing(range_df[!, i]))), i]
            end
        end
    end
    return DataFrame(dict_2)
end

function format_channel(channel)
    # Replace any non-alphanumeric character with _
    channel = replace(channel, r"[^a-zA-Z0-9]" => "_")
    # Remove any leading or trailing _ separators
    channel = strip(channel, '_')
    # Remove any duplicate _ separators
    channel = replace(channel, r"_+" => "_")
    return channel
end
