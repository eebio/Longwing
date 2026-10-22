using CSV
using Printf
using XLSX
using StringEncodings
using Dates
import Base.read

"""
    read_pr(samples,sample_dict,channels,broad_g,channel_map)

Reads plate reader data.

Arguments:
- `samples::DataFrame`: Dataframe of samples to be read into sample_dict.
- `sample_dict::Dict`: A dictionary of the samples.
- `channels::Vector`: Channels to use.
- `broad_g::Vector`: The larger plate that this belongs to.
- `channel_map::Dict`: What to rename the channel to.
"""
function read_pr(samples, sample_dict, channels, broad_g, channel_map)
    @info "Processing plate reader data from plate $(unique(samples.Plate)[1])"
    # Check there is only one loc
    loc = unique(samples[!, "Data Location"])
    # Check what the plate-reader type is
    ptype = unique(samples[!, "Plate brand"])
    length(loc) == 1 ||
        error("Please give the location of only one folder containing all the CSVs for one \
        plate. \nLocations given here are: $(Set(samples[!,"Data Location"])...)")
    length(ptype) == 1 ||
        error("Only one plate type can be used per plate. \
        $(Set(samples[!,"Plate brand"])...) given.")
    data, raw_metadata = read_multipr_file("$(loc...)", ptype[1], channels, channel_map)
    channels = keys(data)
    # Just so that the broader physical group can be defined using the set difference
    pre = keys(sample_dict)
    sample_dict = merge(sample_dict,
        OrderedDict("plate_0$(samples.Plate[1])_$(lowercase(k))" => Dict( # TODO Plate[1] could be >9
                        "type" => "timeseries",
                        "values" => Dict(i => data[i][!, k]
                        for i in channels if k in names(data[i])),
                        "metadata" => Dict{String, Any}("raw_metadata" => raw_metadata))
        for k in names(data[Vector([channels...])[1]]) if isvalid(k)))
    broad_g = [i for i in keys(sample_dict) if !(i in pre)]
    return sample_dict, broad_g
end

"""
    read_multipr_file(file,ptype,channels,channel_map)

Function for reading files containing multiple reads from multple channels from a single CSV
    file.
Returns a Dictionary of DataFrames with keys being the channels.

Arguments:
- `file::String`: File to read from.
- `ptype::String`: The plate reader type being used.
- `channels::Vector`: Channels to be read in.
- `channel_map`: The new names for the channels.
"""
function read_multipr_file(file, ptype, channels, channel_map)
    if lowercase(ptype) == "spectramax"
        ptype = SpectraMax()
    elseif lowercase(ptype) == "biotek"
        ptype = BioTek()
    elseif lowercase(ptype) == "tecan"
        ptype = Tecan()
    elseif lowercase(ptype) == "bmg"
        ptype = BMG()
    elseif lowercase(ptype) == "generic"
        ptype = GenericTabular()
    else
        error("Unknown plate reader type: $ptype.")
    end
    if isempty(channels)
        channels = nothing
    end
    o_dict, raw_metadata = read(file, ptype; channels = channels)
    # Check that no channels are requested but missing
    if !isnothing(channels)
        for k in channels
            if !haskey(o_dict, k)
                error("Requested channel $k not found in file $file.")
            end
        end
    end
    # Apply channel map
    o_dict = Dict(get(channel_map, k, k) => v for (k, v) in o_dict)
    for k in keys(o_dict)
        isnothing(match(r"^[a-zA-Z][a-zA-Z0-9_]*$", k)) && error("Channel name $k is not a valid channel name. Channel names should only contain letters, numbers, and underscores, starting with a letter. Please rename the channel in the channel map.")
    end
    return o_dict, raw_metadata
end

function read_into_lines(file)
    encodings = ["UTF-16", "UTF-8", "windows-1252", "ISO-8859-1", "ASCII"]
    true_encoding = ""
    bytes = read(file)
    for enc in encodings
        try
            str = decode(bytes, enc)
            if occursin("Time", str)
                true_encoding = enc
                break
            end
        catch
        end
    end
    true_encoding == "" &&
        error("Could not determine encoding for file $file.")
    str = decode(bytes, true_encoding)
    str = replace(str, "\r\n" => "\n")  # Normalize line endings
    str = replace(str, "\r" => "\n")    # Handle any remaining carriage returns
    return split(str, r"\n")
end

function runlength(a, i)
    if i == length(a)
        return 1
    elseif a[i] == 1
        return runlength(a, i + 1) + 1
    else
        return 0
    end
end

function read_standard(file, offset; time_regex=r"\d{1,2}:\d\d:\d\d")
    # file is string for file path to read
    # offset is the number of lines between the metadata header and the first line containing "Time"
    f = read_into_lines(file)
    containsTime = [occursin(time_regex, j) ? 1 : 0 for j in f]
    rl = [runlength(containsTime, i) for i in eachindex(containsTime)]
    datalocations = findall(x -> x == maximum(rl), rl)
    raw_metadata = join(f[1:(datalocations[1] - 2)], "\n")
    # Trim the data to only the relevant parts
    data = []
    for i in datalocations
        table = []
        # Push header onto table (first row before i that contains Time and row above)
        for j in (i - 1):-1:1
            if occursin("Time", f[j])
                push!(table, f[j - offset])
                push!(table, f[j])
                break
            end
        end
        # Find and push the data onto table
        for j in i:length(f)
            if containsTime[j] == 1
                push!(table, f[j])
            else
                break
            end
        end
        push!(data, table)
    end
    return data, raw_metadata
end

function correct_data_length(data, delim)
    for d in data
        # Find the most common number of columns
        col_lengths = [length(split(row, delim)) for row in d]
        max_length = maximum(col_lengths)
        # Fill in missing columns with empty cells
        for i in eachindex(d)
            current_length = length(split(d[i], delim))
            if current_length < max_length
                num_missing = max_length - current_length
                d[i] *= repeat(delim, num_missing)
            end
        end
    end
    return data
end

function coerce_numeric_string_columns!(df)
    for name in names(df)
        col = df[!, name]
        parsed = Vector{Union{Missing, Float64}}(undef, length(col))
        ok = true
        for idx in eachindex(col)
            x = col[idx]
            if ismissing(x)
                parsed[idx] = missing
            elseif x isa Number
                parsed[idx] = Float64(x)
            elseif x isa AbstractString
                s = strip(x)
                if isempty(s)
                    parsed[idx] = missing
                else
                    y = tryparse(Float64, s)
                    if isnothing(y)
                        ok = false
                        break
                    end
                    parsed[idx] = y
                end
            else
                ok = false
                break
            end
        end
        if ok
            df[!, name] = parsed
        end
    end
    return df
end

struct SpectraMax <: AbstractPlateReader end

"""
    read(file::AbstractString, ::AbstractPlateReader; channels)

Read data from plate reader file `file` of assuming the format of `AbstractPlateReader`.

Arguments:
- `file::AbstractString`: File to read from.
- `::AbstractPlateReader`: Plate reader type.
- `channels`: Vector of channels (as strings) to be read in. Defaults to nothing (all
    channels).

Returns:
- `Dict{String, DataFrame}`: A dictionary with keys being the channel names and values
    being the dataframes containing the data for each channel.
- `String`: The plate reader raw metadata.
"""
function Base.read(file::AbstractString, ::SpectraMax; channels = nothing)
    data, _ = read_standard(file, 1; time_regex=r"(\d{1,2}:\d\d:\d\d|NaN)") # Raw metadata is incorrect here, no file level metadata. NaN is used if a timepoint failed to record
    data = correct_data_length(data, "\t")
    # Create the dataframes
    out = Dict()
    raw_metadata = "" # No file level metadata

    # Process channel metadata
    all_channels = []
    for i in eachindex(data)
        raw_metadata *= data[i][1] * "\n" # Channel specific metadata lines
        tmp = split(data[i][1], "\t")
        tmp = [strip(t) for t in tmp if !isempty(strip(t))]
        type = tmp[6]
        channel = type == "Fluorescence" ? tmp[14] * "_" * tmp[18] : tmp[13]
        push!(all_channels, (channel, type))
    end
    # Process possible duplicate channel names
    # OD channels may be repeated if multiple wavelengths were read in a single measurement
    # i.e. 600nm and 650nm in the same read is recorded as "600 650"
    # Fluorescence channels may be repeated if read at multiple gain settings
    channel_counts = Dict{String, Int}()
    for i in eachindex(all_channels)
        channel, type = all_channels[i]
        if haskey(channel_counts, channel)
            channel_counts[channel] += 1
            # Duplicate channel
            if type == "Absorbance"
                # We probably have OD wavelengths read in a single measurement action
                # Seperate the wavelengths
                all_channels[i] = (split(channel, " ")[i], type)
                if channel_counts[channel] == 2
                    # First duplicate, rename the original too
                    j = findfirst(x -> x[1] == channel, all_channels)
                    all_channels[j] = (split(channel, " ")[1], type)
                end
            else
                # Its fluorescence, probably at multiple gain settings
                all_channels[i] = (channel * "_$(channel_counts[channel])", type)
                if channel_counts[channel] == 2
                    # First duplicate, rename the original too
                    j = findfirst(x -> x[1] == channel, all_channels)
                    all_channels[j] = (channel * "_1", type)
                end
            end
        else
            channel_counts[channel] = 1
        end
    end
    for i in eachindex(data)
        channel = format_channel(all_channels[i][1])
        if !isnothing(channels) && !(channel in channels)
            continue
        end
        # Get the data
        df = CSV.read(IOBuffer(join(data[i][2:end], "\n")), DataFrame, delim = "\t")
        temp_name = names(df)[2]
        rename!(df, temp_name => "temperature")
        time_name = names(df)[1]
        rename!(df, time_name => "time")
        # Remove empty columns (could be extra alignment columns at the end of the data)
        df = df[:, Not(all.(ismissing, eachcol(df)))]
        # Replace saturated data with missing
        allowmissing!(df)
        for col in eachcol(df)
            if any(ismissing.(col)) || any(col .== "#SAT") || any(col .== "NaN")
                col .= map(x -> ismissing(x) || x == "#SAT" || x == "NaN" ? missing : x, col)
            end
            if eltype(col) <: Union{Missing, Number}
                if any(ismissing.(col)) || any(isnan.(col))
                    col .= map(x -> ismissing(x) || isnan(x) ? missing : x, col)
                end
            end
        end
        # Make sure time is in milliseconds
        time_conversion(t) = ismissing(t) || t isa Time ? t : Time(t)
        df[!, "time"] = map(t -> ismissing(t) ? missing : hour(time_conversion(t)) * 3600 * 1000 + minute(time_conversion(t)) * 60 * 1000 + second(time_conversion(t)) * 1000 +
            millisecond(time_conversion(t)), df[!, "time"])
        coerce_numeric_string_columns!(df)
        out[channel] = df
    end
    return out, raw_metadata
end

struct BioTek <: AbstractPlateReader end

function Base.read(filen::AbstractString, ::BioTek; channels = nothing)
    data, raw_metadata = read_standard(filen, 2)

    # Add possible extra metadata from the end of the file
    f = read_into_lines(filen)
    results_found = false
    for i in eachindex(f)
        if occursin(r"Results", f[i])
            results_found = true
        end
        if results_found
            raw_metadata *= "\n" * f[i]
        end
    end
    # Create the dataframes
    out = Dict()
    for i in eachindex(data)
        channel = format_channel(data[i][1])
        if !isnothing(channels) && !(channel in channels)
            continue
        end
        # Remove channel name from the first row
        data[i][2] = replace(data[i][2], " $(data[i][1])" => "")
        # Read the data into a DataFrame
        df = CSV.read(IOBuffer(join(data[i][2:end], "\n")), DataFrame)
        temp_name = names(df)[2]
        rename!(df, temp_name => "temperature")
        time_name = names(df)[1]
        rename!(df, time_name => "time")
        # Remove empty columns
        df = df[:, Not(all.(ismissing, eachcol(df)))]
        # Replace overflow data with missing
        allowmissing!(df)
        for col in eachcol(df)
            if any(col .== "OVRFLW")
                col .= map(x -> x == "OVRFLW" ? missing : x, col)
            end
        end
        # Make sure time is in milliseconds
        df[!, "time"] = [hour(t) * 3600 * 1000 + minute(t) * 60 * 1000 + second(t) * 1000 +
                         millisecond(t) for t in df[!, "time"]]
        coerce_numeric_string_columns!(df)
        out[channel] = df
    end
    return out, raw_metadata
end

struct Tecan <: AbstractPlateReader end

function Base.read(file::AbstractString, ::Tecan; channels = nothing)
    workbook = XLSX.readxlsx(file)
    sh = workbook["Sheet2"]
    isdata = .!ismissing.(sh[:, 1])
    rl = [runlength(isdata, i) for i in eachindex(isdata)]
    datalocations = findall(isequal("Cycle Nr."), vec(sh[:, 1])) .- 1
    raw_metadata = ""
    for i in 1:(datalocations[1] - 1)
        raw_metadata *= join(sh[i, :], ",") * "\n"
    end
    raw_metadata *= join(sh[end, :], ",")
    raw_metadata = replace(raw_metadata, "missing" => "")
    data = []
    for i in datalocations
        # Find and push the data onto table
        tmp = sh[i:(i + rl[i] - 1), :]
        push!(data, permutedims(tmp))
    end
    # Create the dataframes
    out = Dict()
    for i in eachindex(data)
        channel = format_channel(data[i][1, 1])
        if !isnothing(channels) && !(channel in channels)
            continue
        end
        df = DataFrame(data[i][2:end, 3:end], :auto)
        rename!(df, convert(Vector{String}, data[i][1, 3:end]))
        temp_name = names(df)[2]
        rename!(df, temp_name => "temperature")
        time_name = names(df)[1]
        rename!(df, time_name => "time")
        df = df[:, Not(all.(ismissing, eachcol(df)))]
        # Make sure time is in milliseconds
        time_float = df[!, "time"] .* 1000
        time_int = round.(Int64, time_float)
        @assert all(time_float .≈ time_int)
        df[!, "time"] = time_int
        out[channel] = df
    end
    return out, raw_metadata
end

struct BMG <: AbstractPlateReader end

function Base.read(file::AbstractString, ::BMG; channels = nothing)
    f = read_into_lines(file)
    containsData = [length(unique(j)) > 1 ? 1 : 0 for j in f]
    rl = [runlength(containsData, i) for i in eachindex(containsData)]
    datalocations = findall(x -> x == maximum(rl), rl)
    raw_metadata = join(f[1:(datalocations[1] - 1)], "\n")
    # Trim the data to only the relevant parts
    data = []
    for i in datalocations
        table = []
        # Push header onto table (first row before i that contains Time and row above)
        push!(table, f[i])
        for j in (i + 2):length(f)
            if containsData[j] == 1
                push!(table, f[j])
            else
                break
            end
        end
        push!(data, table)
    end

    out = Dict()
    for i in eachindex(data)
        channel = format_channel(split(data[i][1], ",")[2])
        if !isnothing(channels) && !(channel in channels)
            continue
        end
        # Transpose data and convert to a single string for CSV reading
        d = [split(row, ",") for row in data[i][2:end]]
        d = hcat(d...)
        d = join([join(row, ",") for row in eachrow(d)], "\n")

        # Read the data into a DataFrame
        df = CSV.read(IOBuffer(d), DataFrame)
        time_name = names(df)[1]
        rename!(df, time_name => "time")
        # Remove empty columns
        df = df[:, Not(all.(ismissing, eachcol(df)))]
        # Add temparature column with missing values
        allowmissing!(df)
        df[!, "temperature"] = fill(missing, nrow(df)) # TODO can you get this PR to record temperature?
        # Make sure time is in milliseconds
        time_float = df[!, "time"] .* 1000
        time_int = round.(Int64, time_float)
        @assert all(time_float .≈ time_int)
        df[!, "time"] = time_int
        out[channel] = df[:, ["time", "temperature", names(df)[2:(end - 1)]...]] # reorder to put temperature after time
    end
    return out, raw_metadata
end

struct GenericTabular <: AbstractPlateReader end

function Base.read(file::AbstractString, ::GenericTabular; channels = nothing)
    out = Dict()
    for j in readdir(file)
        channel = format_channel(splitext(j)[1]) # Remove file extension
        if !isnothing(channels) && !(channel in channels)
            continue
        end
        df = CSV.read(joinpath(file, j), DataFrame)
        df[!, "time"] = [hour(t) * 3600 * 1000 + minute(t) * 60 * 1000 + second(t) * 1000 +
                         millisecond(t) for t in df[!, "time"]]
        out[channel] = df
    end
    return out, ""
end
