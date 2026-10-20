using FCSFiles
using FileIO

"""
    read_flow(samples, sample_dict,channels,broad_g,channel_map)

Read the flow cytometry data from a file.

Arguments:
- `samples::DataFrame`: DataFrame of samples to read from.
- `sample_dict::Dict`: Output sample Dict.
- `channels::Vector`: Channels to read.
- `broad_g::Vector`: The physical group that this is part of.
- `channel_map::Dict`: The names to replace the old channel names with.
"""
function read_flow(samples, sample_dict, channels, broad_g, channel_map)
    @info "Processing flow cytometer data from plate $(unique(samples.Plate)[1])"
    for j in eachrow(samples)
        if j.Plate > 9
            name = "plate_$(j.Plate)_$(lowercase(j.Well))"
        else
            name = "plate_0$(j.Plate)_$(lowercase(j.Well))"
        end
        temp = Dict()
        temp["type"] = "population"
        temp_data = load(j."Data Location")
        current_channels = if isempty(channels)
            discovered_channels = format_channel.(keys(temp_data))
            discovered_channels = [c == "Time" ? "time" : c
                                   for c in discovered_channels]
            channel_map = merge(Dict(c => c for c in discovered_channels), channel_map)
            discovered_channels
        else
            channels
        end
        temp["values"] = Dict{String,Any}(get(channel_map, x, x) =>
            temp_data[flow_channel(x, temp_data)] for x in current_channels)
        temp["metadata"] = convert(Dict{String,Any},
            Dict(channel_map[x] => extract_flow(
                temp_data, flow_channel(x, temp_data))
                 for x in current_channels))
        temp["metadata"]["raw_metadata"] = Dict(k =>
            try
                getproperty(temp_data, k)
            catch
                "Error: Property could not be read"
            end
                                                for k in propertynames(temp_data))
        for c in current_channels
            temp["metadata"][channel_map[c]]["longwing_well"] = lowercase(j.Well)
        end

        # Handle time channel units
        if haskey(channel_map, "time") && haskey(temp["values"], channel_map["time"])
            function check_times(experiment_time, buffer, start_time, end_time)
                # Checks that predicted end time is within buffer seconds of actual end time, and that the predicted end time is closer to the actual end time than the start time
                return (end_time - Second(buffer) <= start_time + Millisecond(round(experiment_time)) <= end_time + Second(buffer)
                    &&
                    end_time - start_time - Millisecond(round(experiment_time)) <= Millisecond(round(experiment_time)))
            end
            times = collect(temp["values"][channel_map["time"]])
            assumption = "ERROR"
            function parse_time(time)
                time = strip(time)
                if count(==(':'), time) > 2
                    return Time(time, dateformat"HH:MM:SS:ss")
                else
                    return Time(time)
                end
            end
            start_time = parse_time(temp["metadata"]["raw_metadata"][:btim])
            end_time = parse_time(temp["metadata"]["raw_metadata"][:etim])
            experiment_times = [maximum(times), maximum(times) - minimum(times)]
            if hasproperty(temp_data, :timestep)
                if eltype(times) <: Integer
                    # Times are stored as integer multiples of timestep (as they should be)
                    timestep = parse(Float64, temp_data.timestep) # in seconds
                    temp["values"][channel_map["time"]] = times .* timestep .* 1000 # store time in milliseconds
                    assumption = "Data was stored as integer multiples of the timestep, which is in seconds."
                else
                    # Has a timestep but is stored as floats
                    # Has time been stored in seconds or milliseconds?
                    if check_times(experiment_times[1] * 1000, 2, start_time, end_time) || check_times(experiment_times[2] * 1000, 2, start_time, end_time)
                        # Already in seconds, convert to ms
                        temp["values"][channel_map["time"]] = times .* 1000
                        assumption = "Data appears to have been stored in seconds as floats, and matches start and end times when converted to milliseconds."
                    elseif check_times(experiment_times[1], 1, start_time, end_time) || check_times(experiment_times[2], 1, start_time, end_time)
                        assumption = "Data appears to have been stored in milliseconds as floats, and matches start and end times when treated as milliseconds."
                        # Also needed to check that start_time+experiment_time is closer to end_time than start_time
                        # Already in ms, do nothing
                    else
                        # Assume the time is meant to be an integer multiple of the timestep but was stored as floats
                        timestep = parse(Float64, temp_data.timestep) # in seconds
                        temp["values"][channel_map["time"]] = times .* timestep .* 1000 # convert to ms
                        assumption = "Data appears to have been stored as floats, but reading as seconds or milliseconds does not match the start and end times. We have assumed the time is multiples of the timestep, which is in seconds, but stored as floats rather than integers."
                    end
                end
            else
                if check_times(experiment_times[1] * 1000, 2, start_time, end_time) || check_times(experiment_times[2] * 1000, 2, start_time, end_time)
                    # Already in seconds, convert to ms
                    temp["values"][channel_map["time"]] = times .* 1000
                    assumption = "Data appears to have been stored in seconds as floats, and matches start and end times when converted to milliseconds."
                elseif check_times(experiment_times[1], 1, start_time, end_time) || check_times(experiment_times[2], 1, start_time, end_time)
                    assumption = "Data appears to have been stored in milliseconds as floats, and matches start and end times when treated as milliseconds."
                    # Also needed to check that start_time+experiment_time is closer to end_time than start_time
                    # Already in ms, do nothing
                else
                    # Time data is messed up
                    assumption = "Data does not store the timestep and does not appear to be stored in seconds or milliseconds. We have assumed the time is stored in milliseconds but the units on this time data should NOT be trusted."
                end
            end
            t = collect(temp["values"][channel_map["time"]])
            experiment_times = [maximum(t), maximum(t) - minimum(t)]
            if !(check_times(experiment_times[1], 2, start_time, end_time) || check_times(experiment_times[2], 2, start_time, end_time))
                str = "Data from the time channel does not match start and end times in the metadata.\n"
                str *= "Filename: $(j."Data Location")\n"
                str *= "Start time: $start_time\n"
                str *= "End time: $end_time\n"
                str *= "Converted experiment time (from transformed time channel): $(experiment_times[1]) milliseconds (or possibly $(experiment_times[2]) milliseconds)\n"
                str *= "Minimum value of raw time channel: $(minimum(times))\n"
                str *= "Maximum value of raw time channel: $(maximum(times))\n"
                if hasproperty(temp_data, :timestep)
                    str *= "Timestep from metadata: $(temp_data.timestep) seconds\n"
                else
                    str *= "No timestep stored in metadata\n"
                end
                str *= "Expected end time based on start time and experiment time: $(start_time + Millisecond(round(experiment_times[1]))) (or possibly $(start_time + Millisecond(round(experiment_times[2]))))\n"
                str *= "Assumption made about time channel for conversion: $assumption\n"
                @warn str
            end
        end
        sample_dict[name] = temp
        broad_g = [broad_g; [name]]
    end
    return sample_dict, broad_g
end

function flow_channel(lwchannel, data)
    all_channels = keys(data)
    for c in all_channels
        if format_channel(c) == lwchannel
            return c
        end
    end
    for c in all_channels
        if lowercase(format_channel(c)) == lowercase(lwchannel)
            return c
        end
    end
end

"""
    extract_flow(fcs,chan)

Extract the metadata from a FCSFiles.FlowSample.

Arguments:
- `fcs`: The parsed FCS file.
- `chan::String`: The channel being read from.
"""
function extract_flow(fcs, chan)
    p = findfirst([i == chan for i in keys(fcs)])
    function mapper(char)
        if hasproperty(fcs, Symbol("p$(p)$(char)"))
            return getproperty(fcs, Symbol("p$(p)$(char)"))
        else
            return missing
        end
    end
    return Dict(
        "name" => mapper('n'),
        "amp_type" => mapper('e'),
        "range" => mapper('r'),
        "filter" => mapper('f'),
        "amp_gain" => mapper('g'),
        "ex_wav" => mapper('l'),
        "ex_pow" => mapper('o'),
        "perc_em" => mapper('p'),
        "name_s" => mapper('s'),
        "det_type" => mapper('t'),
        "det_volt" => mapper('v')
    )
end

"""
    to_rfi(lw, sample_name)

Calculates relative fluorescence of given sample.

Arguments:
- `lw::lw_zones`: The data set to search.
- `sample_name::String`: channel to use.
"""
function to_rfi(lw, sample_name)
    sub = lw.samples[
        map(x -> !isnothing(match(Regex(string(sample_name * raw"\.")), x)),
            lw.samples.name),
        :]
    chans = sub.channel
    o = Dict()
    for i in chans
        # Load metadata for channel
        amp_type = parse.(
            Float64, split(
            sub[sub.name .== "$sample_name.$i", "metadata"][1]["amp_type"], ","))
        range = parse(Int, sub.metadata[sub.name .== "$sample_name.$i", :][1]["range"])
        if amp_type[1] == 0
            if isnothing(sub.metadata[sub.name .== "$sample_name.$i", :][1]["amp_gain"])
                amp_gain = 1.0
            else
                amp_gain = sub.metadata[sub.name .== "$sample_name.$i", :][1]["amp_gain"]
                amp_gain = parse(Int, replace(amp_gain, ".0" => ""))
            end
            data = sub.values[sub.name .== "$sample_name.$i", :][1] ./ amp_gain
            min = 1 / amp_gain
            max = range / amp_gain
        else
            # Non-linear gain
            data = amp_type[2] *
                10 .^ (amp_type[1] *
                (sub.values[sub.name .== "$sample_name.$i", :][1] / range))
            min = amp_type[2] * 10^(amp_type[1] * (1 / range))
            max = amp_type[2] * 10^(amp_type[1] * (range / range))
        end
        o["$i.min"] = min
        o["$i.max"] = max
        o[i] = data
    end
    o["id"] = 1:length(o[chans[1]])
    o["longwing_well"] = sub.metadata[1]["longwing_well"]
    return DataFrame(o)[!, sort(names(DataFrame(o)))]
end
