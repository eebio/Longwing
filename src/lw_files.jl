using Pkg
using InteractiveUtils
using Parameters
using DataFrames
using XLSX
using JSON
using DataStructures
using FileIO
using FCSFiles
using StyledStrings

@with_kw mutable struct lw_zones
    samples::DataFrame
    groups::Any
    transformations::Any
    views::Any
    metadata::Any
end

"""
    read_longwing(file::AbstractString)

Parse a Longwing file found at `file` into an lw_zones object.
"""
function read_longwing(file::AbstractString)
    @info "Reading Longwing Data Standard file at: $file"
    # Read in the file in a JSON format
    ef = JSON.parsefile(file)
    lw = convert(lw_zones, ef)
    @info "Longwing Data Standard file successfully read."
    return lw
end

"""
    write_longwing(data, file::AbstractString)

Write the Longwing data to the path `file`.
"""
function write_longwing(data::OrderedDict, file::AbstractString)
    JSON.json(file, data; pretty=true)
    @info "Longwing Data Standard file written to $file"
end

function write_longwing(data::lw_zones, file::AbstractString)
    data = convert(OrderedDict, data)
    write_longwing(data, file)
end

function Base.convert(::Type{OrderedDict}, data::lw_zones)
    samples = OrderedDict()
    for row in eachrow(data.samples)
        sample_name, channel = split(string(row.name), ".")
        if !haskey(samples, sample_name)
            samples[sample_name] = Dict(
                "type" => row.type,
                "values" => Dict{String, Any}(),
                "metadata" => Dict{String, Any}())
        end
        samples[sample_name]["values"][channel] = row.values
        merge!(samples[sample_name]["metadata"], row.metadata)
        if row.type == "population"
            # Add some channel specific metadata
            flow_meta_keys = ["ex_wav", "ex_pow", "name", "det_type", "amp_type", "det_volt", "perc_em", "name_s", "range", "filter", "amp_gain", "longwing_well"]
            samples[sample_name]["metadata"][channel] = Dict(key => value for (key, value) in row.metadata if key in flow_meta_keys)
            for key in flow_meta_keys
                if haskey(samples[sample_name]["metadata"], key)
                    delete!(samples[sample_name]["metadata"], key)
                end
            end
        end
    end

    groups = OrderedDict()
    for row in eachrow(data.groups)
        groups[string(row.group)] = Dict(
            "sample_IDs" => lowercase.(row.sample_IDs),
            "metadata" => row.metadata)
        if haskey(row.metadata, "autodefined") && row.metadata["autodefined"] == "true"
            groups[string(row.group)]["type"] = "physical"
        else
            groups[string(row.group)]["type"] = "experimental"
        end
    end

    return OrderedDict(
        "samples" => samples,
        "groups" => groups,
        "transformations" => data.transformations,
        "views" => data.views,
        "metadata" => data.metadata
    )
end

function Base.convert(::Type{lw_zones}, ef::Union{OrderedDict, JSON.Object})
    max_len = 0
    # Loop over the samples to look for maximum length of array
    for i in keys(ef["samples"])
        for j in keys(ef["samples"][i]["values"])
            k = length(ef["samples"][i]["values"][j])
            if k > max_len
                max_len = k
            end
        end
    end
    # Create the Longwing object
    lw = lw_zones(
        samples=DataFrame(
            [(lowercase(i),
                j,
                ef["samples"][i]["type"],
                replace(ef["samples"][i]["values"][j], nothing => missing),
                sample_channel_metadata(ef["samples"][i]["metadata"], j),
                [i in lowercase.(ef["groups"][k]["sample_IDs"])
                 for k in keys(ef["groups"])]...) for i in keys(ef["samples"])
             for j in keys(ef["samples"][i]["values"])],
            ["name", "channel", "type", "values", "metadata",
                [k for k in keys(ef["groups"])]...]),
        groups=DataFrame(
            [(i,
                lowercase.(ef["groups"][i]["sample_IDs"]),
                ef["groups"][i]["metadata"],
                :(filter(row -> row.name in ef["groups"][i]["sample_IDs"],
                    samples, view=true))) for i in keys(ef["groups"])],
            ["group", "sample_IDs", "metadata", "meta_select"]),
        transformations=ef["transformations"],
        views=ef["views"],
        metadata=ef["metadata"]
    )
    # Add channels to sample names
    lw.samples.name = string.(lw.samples.name, ".", lw.samples.channel)
    return lw
end

function sample_channel_metadata(sample_metadata, channel)
    metadata = if haskey(sample_metadata, channel)
        channel_metadata = sample_metadata[channel]
        raw_metadata = if haskey(channel_metadata, "raw_metadata")
            channel_metadata["raw_metadata"]
        else
            get(sample_metadata, "raw_metadata", Dict())
        end
        merge(channel_metadata, Dict("raw_metadata" => raw_metadata))
    else
        copy(sample_metadata)
    end
    if haskey(sample_metadata, "template")
        metadata = merge(metadata, Dict("template" => sample_metadata["template"]))
    end
    return metadata
end

function untranslate_longwing(input::AbstractString, output::AbstractString)
    lw = read_longwing(input)
    cp(joinpath(@__DIR__, "template.xlsx"), output; force=true)

    sample_rows = untranslate_sample_rows(lw)
    channel_map_rows = untranslate_channel_map_rows(lw)
    group_headers, group_rows = untranslate_group_rows(lw)
    transformation_rows = untranslate_transformation_rows(lw)
    view_rows = untranslate_view_rows(lw)

    XLSX.openxlsx(output, mode="rw") do workbook
        write_excel_table!(workbook["Samples"],
            ["Type", "Data Location", "Channels", "Plate brand", "Plate", "Well"],
            sample_rows)
        write_excel_table!(workbook["Channel Map"], ["Channel", "New name"],
            channel_map_rows)
        write_excel_table!(workbook["Groups"], group_headers, group_rows)
        write_excel_table!(workbook["Transformations"], ["Name", "Equation"],
            transformation_rows)
        write_excel_table!(workbook["Views"], ["Name", "View"], view_rows)
    end
    @info "Template written to $output"
    return nothing
end

function write_excel_table!(sheet, headers, rows)
    data = Matrix{Any}(undef, length(rows) + 1, length(headers))
    for (column, header) in enumerate(headers)
        data[1, column] = header
    end
    for (row_number, row) in enumerate(rows)
        for (column, value) in enumerate(row)
            data[row_number+1, column] = excel_value(value)
        end
    end
    sheet["A1"] = data
end

function excel_value(value)
    if value === nothing || ismissing(value)
        return ""
    elseif value isa AbstractString || value isa Number || value isa Bool
        return value
    end
    return string(value)
end

# This function is used to de-duplicate the sample rows. For example, a single PR file gives
# many samples, but they all have the same template metadata. We only want to write one row
# for that template metadata
function untranslate_sample_rows(lw)
    rows = Any[]
    seen = Set{String}()
    for sample in eachrow(lw.samples)
        template = sample.metadata["template"]
        row = template_sample_row(template)
        signature = join(string.(row), "\u001f")
        if !(signature in seen)
            push!(seen, signature)
            push!(rows, row)
        end
    end
    return rows
end

function template_sample_row(template)
    return [template["sample_type"],
        template["data_location"],
        join(string.(template["channels"]), ", "),
        template["plate_brand"],
        template["plate"],
        template["well"]]
end

function untranslate_channel_map_rows(lw)
    stored_map = lw.metadata["channel_map"]
    return [[string(source), string(target)] for (source, target) in stored_map]
end

function untranslate_group_rows(lw)
    groups = Any[]
    metadata_keys = String[]
    for group in eachrow(lw.groups)
        group_name = string(group.group)
        group_metadata = group.metadata
        autogenerated = lowercase(string(get(group_metadata, "autodefined", "false"))) == "true"
        if autogenerated
            continue
        end
        for key in keys(group_metadata)
            key = string(key)
            if key != "autodefined" && !(key in metadata_keys)
                push!(metadata_keys, key)
            end
        end
        push!(groups, (group_name, group.sample_IDs, group_metadata))
    end
    headers = ["Name", "Samples", metadata_keys...]
    rows = Any[]
    for (group_name, sample_ids, group_metadata) in groups
        row = Any[group_name, join(string.(sample_ids), ", ")]
        append!(row, [group_metadata[key] for key in metadata_keys])
        push!(rows, row)
    end
    return headers, rows
end

function untranslate_transformation_rows(lw)
    return [[name, transformation["equation"]] for
            (name, transformation) in lw.transformations]
end

function untranslate_view_rows(lw)
    return [[name, join(string.(view["data"]), ", ")] for
            (name, view) in lw.views]
end

"""
    read_data(file::AbstractString)

Read the data from path `file` into the correct structure.
"""
function read_data(file::AbstractString)
    # Check for flow directories
    samples = DataFrame(XLSX.readtable(file, "Samples"; stop_in_empty_row=false))
    samples = expand_flow_directories(samples)

    # Extract data
    groups = DataFrame(XLSX.readtable(file, "Groups"; stop_in_empty_row=false))
    trans = DataFrame(XLSX.readtable(file, "Transformations"; stop_in_empty_row=false))
    views = DataFrame(XLSX.readtable(file, "Views"; stop_in_empty_row=false))
    channel_map = DataFrame(XLSX.readtable(file, "Channel Map"; stop_in_empty_row=false))

    # Validate template file
    validate_template(samples, groups, trans, views, channel_map)

    samples = groupby(samples, :Plate)

    # Create the dict to show what channels need to be changed
    channel_map = Dict(string(i."Channel") => string(i."New name") for i in eachrow(channel_map)
                                                                       if !ismissing(i."Channel") && !ismissing(i."New name") && !isempty(string(i."Channel")))
    for val in values(channel_map)
        if val != format_channel(val)
            throw(TemplateError("Channel names must only contain letters, numbers, and underscores. Invalid channel name: $val. If this is the default name for the channel, it should be renamed using the channel map."))
        end
    end
    sample_dict = OrderedDict()
    process_groups_of_groups!(groups)
    group_dict = OrderedDict(i.Name => Dict(
        "sample_IDs" => lowercase.(expand_groups(i.Samples)),
        "type" => "experimental",
        "metadata" => Dict{String,Any}(j => i[j]
                                       for j in names(i) if !(j in ["Name", "Samples"])))
                             for i in eachrow(groups)) # Get all the experimental groups.
    for i in eachrow(groups)
        group_dict[i.Name]["metadata"]["autodefined"] = "false"
    end
    @info "Reading $(length(keys(samples))) plates"
    for i in range(1, length(keys(samples)))
        # Check what instrument was used
        ins_type = Set(samples[i].Type)
        for j in 1:length(samples[i]."Data Location")
            if contains(samples[i]."Data Location"[j], "\$GITHUB_WORKSPACE")
                samples[i]."Data Location"[j] = replace.(samples[i]."Data Location"[j],
                    "\$GITHUB_WORKSPACE" => ENV["GITHUB_WORKSPACE"])
            end
        end
        length(ins_type) == 1 ||
            throw(TemplateError("All experiments on one plate must be from the same instrument types. \
            Instrument types used here are: $(Set(samples[i].Type))"))
        # Process channels
        channels = String[]
        # Convert to string if not already
        str_j = string(samples[i].Channels[1])
        # Add the remaining channels to the list
        for k in split(str_j, ",")
            push!(channels, strip(k))
        end
        channels = [c for c in channels if !isempty(c)]
        # Remove duplicates (for example, specifying the same channels for every well in a flow cytometry plate)
        channels = unique(channels)
        # Add channels that are not in the channel map to the channel map
        channel_map = Dict(i => if i in keys(channel_map)
            channel_map[i]
        else
            i
        end for i in union(channels, keys(channel_map)) if i!="missing")
        if channels == ["missing"]
            channels = String[]
        end
        # Just for pretty printing. Makes the channel map look nice
        prb = ["$j -> $(channel_map[j])\n" for j in keys(channel_map)]
        if isempty(prb)
            prb = "Empty - no channels or channel map specified"
        end
        @info "Channel map: \n$(prb...)"
        broad_g = []
        if "plate reader" in lowercase.(ins_type)
            sample_dict, broad_g = read_pr(
                samples[i], sample_dict, channels, broad_g, channel_map)
        elseif "flow" in lowercase.(ins_type)
            sample_dict, broad_g = read_flow(
                samples[i], sample_dict, channels, broad_g, channel_map)
        else
            throw(TemplateError("Unknown instrument type: $(first(ins_type))"))
        end

        if "plate reader" in lowercase.(ins_type)
            template = template_metadata(first(eachrow(samples[i])), "plate reader",
                channels)
            for sample_name in broad_g
                sample_dict[sample_name]["metadata"]["template"] = template
            end
        else
            for (sample_row, sample_name) in zip(eachrow(samples[i]), broad_g)
                sample_dict[sample_name]["metadata"]["template"] = template_metadata(
                    sample_row, "flow", channels)
            end
        end
        # Add the physical plate to the group dict
        group_dict["plate_0$i"] = Dict("sample_IDs" => broad_g, "type" => "physical",
            "metadata" => Dict("autodefined" => "true"))
    end
    # Add the transformations
    trans_dict = OrderedDict(i.Name => "equation" => string(i.Equation) for i in eachrow(trans))
    # Add the views
    views_dict = OrderedDict(i.Name => "data" => strip.(split(i.View, ",")) for i in eachrow(views))
    metadata = get_metadata()
    metadata["channel_map"] = channel_map
    return OrderedDict("samples" => sample_dict, "groups" => group_dict,
        "transformations" => trans_dict, "views" => views_dict, "metadata" => metadata)
end

function process_groups_of_groups!(groups)
    # Check for groups of groups and expand them
    mapping = Dict{String,String}(i.Name => i.Samples for i in eachrow(groups))
    while true
        complete = true
        for i in eachrow(groups)
            if any(occursin.(keys(mapping), i.Samples))
                complete = false
                i.Samples = replace(i.Samples, mapping...)
            end
        end
        if complete
            break
        end
    end
end

function template_metadata(row, sample_type, channels)
    value(column) =
        if column in propertynames(row)
            column_value = row[column]
            ismissing(column_value) ? "" : column_value
        else
            ""
        end
    data_location = value(Symbol("Data Location"))
    plate_brand = value(Symbol("Plate brand"))
    return Dict{String,Any}(
        "sample_type" => sample_type,
        "data_location" => string(data_location),
        "plate_brand" => string(plate_brand),
        "channels" => string.(channels),
        "plate" => value(:Plate),
        "well" => value(:Well)
    )
end

"""
    get_metadata()

Generate the metadata for a new Longwing file, such as the version of Longwing used to create it.
"""
function get_metadata()
    io = IOBuffer()
    Pkg.status(; io=io)
    project_toml = String(take!(io))
    Pkg.status(; mode=PKGMODE_MANIFEST, io=io)
    manifest_toml = String(take!(io))
    versioninfo(io)
    version_info = String(take!(io))
    return Dict(
        "description" => "",
        "longwing_version" => pkgversion(Longwing),
        "longwing_data_standard_version" => "0.4.0",
        "date_created" => string(Dates.now()),
        "date_modified" => string(Dates.now()),
        "Project.toml" => project_toml,
        "Manifest.toml" => manifest_toml,
        "versioninfo" => version_info
    )
end

"""
    expand_group(group::AbstractString)

Expand a condensed group name into the sample IDs it contains.
For example, if the group is "plate_0[1,2]_[a:c]2", it will return all sample IDs
from plate 1 to 2 and wells a2, b2, and c2.

Arguments:
- `group::AbstractString`: The group name to expand.

Returns:
- `Vector{String}`: A vector of sample IDs contained in the group.
"""
function expand_group(group::AbstractString)
    parts = []
    for match in eachmatch(r"\[([^\]]+)\]", group)
        s = match.captures[1]
        expanded = []
        for item in split(s, ",")
            item = strip(item)
            if occursin(":", item)
                if count(==(':'), item) == 2
                    start, step, stop = split(item, ":")
                else
                    start, stop = split(item, ":")
                    step = "1"
                end
                if occursin(r"\d", start)
                    indexes = parse(Int, start):parse(Int, step):parse(Int, stop)
                    append!(expanded,
                        string.(indexes))
                else
                    indexes = start[1]:parse(Int, step):stop[1]
                    append!(expanded, collect(indexes))
                end
            else
                push!(expanded, item)
            end
        end
        push!(parts, expanded)
    end
    # Replace bracketed sections with "{}" for formatting
    fmt = replace(group, r"\[[^\]]+\]" => "{}")
    ids = []
    for x in Iterators.product(parts...)
        id = fmt
        for (i, y) in enumerate(eachmatch(r"\{\}", fmt))
            id = replace(id, y.match => x[i], count=1)
        end
        push!(ids, id)
    end
    return ids
end

"""
    expand_groups(groups::AbstractString)

Iteratively call `expand_group` on a comma-separated list of group names.
"""
function expand_groups(groups::AbstractString)
    expanded = []
    # Split on commas not inside brackets
    wells = split(groups, r",(?![^\[]*\])")
    for well in wells
        well = strip(well)
        if occursin(r"\[|\]", well)
            append!(expanded, expand_group(well))
        else
            push!(expanded, well)
        end
    end
    expanded = unique(lowercase.(expanded))
    # Validate well syntax
    for id in expanded
        if isnothing(match(r"^plate_\d\d_[a-z]\d+$", id))
            throw(TemplateError("Invalid well syntax in group expansion: group $groups produces $id which is not valid syntax."))
        end
    end
    return expanded
end

function expand_flow_directories(samples)
    rows_to_delete = Int[]
    for (idx, row) in enumerate(eachrow(copy(samples)))
        if lowercase(row.Type) == "flow"
            loc = row."Data Location"
            if occursin("\$GITHUB_WORKSPACE", loc)
                loc = replace(loc, "\$GITHUB_WORKSPACE" => ENV["GITHUB_WORKSPACE"])
            end
            if isdir(loc)
                filenames, wells, confirmations = expand_flow_directory(loc)
                for (file, well) in zip(filenames, wells)
                    new_row = merge(copy(row), (Symbol("Data Location") => joinpath(loc, file), :Well => well))
                    push!(samples, new_row)
                end
                push!(rows_to_delete, idx)
                # Print the well mapping to the user
                @info "Expanded flow directory $(row."Data Location") into the following files and wells:"
                # TODO sort the mapping
                function colour_confirmation(c, confirmation)
                    confirmation == "?" ? styled"{yellow:$(c)}" :
                    confirmation == "✗" ? styled"{red:$(c)}" :
                    confirmation == "✓" ? styled"{green:$(c)}" :
                    styled"{blue:$(c)}"
                end
                str = ""
                for (confirmation, well, filename) in zip(confirmations, wells, filenames)
                    str *= colour_confirmation("$confirmation $well -> $filename\n", confirmation)
                end
                @info "Well map: \n" * str
            end
        end
    end
    # Delete rows marked for deletion
    deleteat!(samples, rows_to_delete)
    return samples
end

function expand_flow_directory(dir)
    filenames = []
    wells = []
    confirmations = []
    for entry in readdir(dir)
        if endswith(lowercase(entry), ".fcs")
            push!(filenames, entry)
            # Match on letter (case insensitive) + some number of digits (not starting with 0), surrounded by non-alphanumeric characters or start/end of string
            m = match(r"(?i)(?<![a-z0-9])([a-z][1-9]\d*)(?![a-z0-9])", entry)
            if isnothing(m)
                # Try matching by allowing a leading 0 in the well number (e.g. A01 instead of A1)
                m = match(r"(?i)(?<![a-z0-9])([a-z]\d+)(?![a-z0-9])", entry)
                if isnothing(m)
                    throw(TemplateError("Could not extract well from filename: $entry"))
                end
            end
            well = lowercase(m.captures[1])
            well = replace(well, r"([a-z])0+(\d+)" => s"\1\2") # Remove leading zeros from well number
            push!(wells, well)
            # Read the file to confirm that the well in the filename matches the well in the file metadata (if it exists)
            try
                fcs = load(joinpath(dir, entry))
                wellid = lowercase(fcs.wellid)
                wellid = replace(wellid, r"([a-z])0+(\d+)" => s"\1\2") # Remove leading zeros from well number
                if wellid != well
                    push!(confirmations, "✗")
                else
                    push!(confirmations, "✓")
                end
            catch
                push!(confirmations, "?")
            end
        end
    end
    # Check for uniqueness of wells
    return filenames, wells, confirmations
end

struct TemplateError <: Exception
    msg::String
end

Base.showerror(io::IO, e::TemplateError) = print(io, e.msg)

function validate_template(samples, groups, trans, views, channel_map)
    for row in eachrow(samples)
        # Check for missing fields
        ismissing(row.Type) && throw(TemplateError("Sample type is missing for one of the samples."))
        ismissing(row."Data Location") && throw(TemplateError("Data location is missing for one of the samples."))
        ismissing(row.Plate) && throw(TemplateError("Plate is missing for one of the samples."))
        if lowercase(row.Type) == "flow"
            ismissing(row.Well) && throw(TemplateError("Well is missing for one of the flow samples."))
        end
        if lowercase(row.Type) == "plate reader"
            ismissing(row."Plate brand") && throw(TemplateError("Plate brand is missing for one of the plate reader samples."))
        end

        # Invalid data location
        isfile(row."Data Location") || throw(TemplateError("Data location does not exist: $(row."Data Location")"))

        # Plate should be an integer
        row.Plate isa Integer || throw(TemplateError("Plate should be an integer."))
    end
    # Plate + well combinations should be unique for all samples
    plate_well_combinations = [(row.Plate, row.Well) for row in eachrow(samples)]
    length(plate_well_combinations) == length(unique(plate_well_combinations)) ||
        throw(TemplateError("Plate + well combinations should be unique for all samples. You seem to be trying to write multiple peices of data to the same well."))

    # Groups
    for row in eachrow(groups)
        ismissing(row.Name) && throw(TemplateError("Group name is missing for one of the groups."))
        ismissing(row.Samples) && throw(TemplateError("Samples are missing for one of the groups."))
        # Check the names are valid syntax
        if !isnothing(match(r"^[a-zA-Z][a-zA-Z0-9_]*$", row.Name))
            throw(TemplateError("Group name $(row.Name) is invalid. Group names must start with a letter and can only contain letters, numbers, and underscores."))
        end
    end

    # Transformations
    for row in eachrow(trans)
        ismissing(row.Name) && throw(TemplateError("Transformation name is missing for one of the transformations."))
        ismissing(row.Equation) && throw(TemplateError("Transformation equation is missing for one of the transformations."))
        # Check the names are valid syntax
        if !isnothing(match(r"^[a-zA-Z][a-zA-Z0-9_]*$", row.Name))
            throw(TemplateError("Transformation name $(row.Name) is invalid. Transformation names must start with a letter and can only contain letters, numbers, and underscores."))
        end
    end

    # Views
    for row in eachrow(views)
        ismissing(row.Name) && throw(TemplateError("View name is missing for one of the views."))
        ismissing(row.View) && throw(TemplateError("View data is missing for one of the views."))
        # Check the names are valid syntax
        if !isnothing(match(r"^[a-zA-Z][a-zA-Z0-9_]*$", row.Name))
            throw(TemplateError("View name $(row.Name) is invalid. View names must start with a letter and can only contain letters, numbers, and underscores."))
        end
    end

    for row in eachrow(channel_map)
        ismissing(row."Channel") && throw(TemplateError("Channel name is missing for one of the channel map entries."))
        ismissing(row."New name") && throw(TemplateError("New channel name is missing for one of the channel map entries."))
        # Check the new names are valid syntax
        if !isnothing(match(r"^[a-zA-Z][a-zA-Z0-9_]*$", row."New name"))
            throw(TemplateError("New channel name $(row."New name") is invalid. New channel names must start with a letter and can only contain letters, numbers, and underscores."))
        end
        # Check the old name is in samples (or at least one of the samples has all channels (i.e. is empty))
        if !any(ismissing(samples.Channels))
            possible_channels = split(join(samples.Channels, ","), ",")
            row.Channel in possible_channels || throw(TemplateError("Channel $(row."Channel") is not present in any of the samples."))
        end
    end
end
