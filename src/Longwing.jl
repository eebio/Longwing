module Longwing
@doc read(joinpath(dirname(@__DIR__), "README.md"), String) Longwing

using Comonicon

abstract type AbstractLongwingMethod end

abstract type AbstractLongwingDataType end

struct LongwingData <: AbstractLongwingDataType end

include("FitEllipse.jl")
include("lw_files.jl")
include("main.jl")
include("plate_readers/main.jl")
include("flow/main.jl")
include("summarise.jl")
include("views.jl")
include("interactive/main.jl")

export read_longwing, lw_zones, read_data, write_longwing
export template, translate, views, summarise, untranslate

export growth_rate, doubling_time, lag_time, max_od, time_to_max_growth, od_at_max_growth
export MovingWindow, FiniteDiff, Endpoints, LinearOnLog, ExpandingWindow
export ParametricGrowthRate, Logistic, Gompertz, ModifiedGompertz, Richards
export SmoothedSpline

export fluorescence
export RatioAtTime, RatioAtMaxGrowth

export smooth
export MovingAverage, MovingTimeAverage

export calibrate
export at_time, at, between_times, between
export TimeseriesBlank, SmoothedTimeseriesBlank, MeanBlank, MinBlank, MinData, StartData

export quantification
export TMSD, HMSD, InternalTMSD, RelativeFluorescence

export gate, event_count, gated_proportion
export HighLowGate, RectangleGate, QuadrantGate, PolygonGate, EllipseGate
export and, or, not
export AndGate, OrGate, NotGate
export KDE

export MEF

export transform, untransform, Transform
export Log, Log10, Log2, Log1p, Arcsinh, Linear, Logicle, Hyperlog, Bound, Identity

export AbstractLongwingMethod, AbstractPlateReaderMethod
export AbstractGrowthRateMethod
export AbstractLongwingDataType, AbstractPlateReader
export LongwingData, FlowCytometryData, BioTek, SpectraMax, Tecan, GenericTabular, BMG
export summary

using Statistics: median
export median

"""
    lw translate

Translates the completed .xlsx template file to a .lw file.

# Args

- `input`: The completed .xlsx template file to be read.
- `output`: The filepath/destination for the .lw file.
"""
@cast function translate(input::String, output::String)
    x = read_data(input)
    write_longwing(x, output)
end

"""
    lw untranslate

Reconstruct an Excel template from an .lw file.

# Args

- `input`: The .lw file to reconstruct.
- `output`: The filepath/destination for the Excel template.
"""
@cast function untranslate(input::String, output::String)
    untranslate_longwing(input, output)
end

"""
    lw views

Produce and save the views from a .lw file.

# Args

- `lw_file`: The .lw file to be read.

# Options
- `-v, --view=<String>`: The view to be produced (or comma-separated list of views). All views if not specified.
- `-o, --output-dir=<String>`: The directory to save the output(s) to. Defaults to the
    current directory.
"""
@cast function views(lw_file::String; view=nothing, output_dir::String=".")
    lw = read_longwing(lw_file)
    trans_meta_map = Dict(Symbol(i) => Meta.parse(lw.transformations[i]["equation"])
                          for i in keys(lw.transformations))
    @info "Producing views."
    if isnothing(view)
        views = []
    elseif contains(view, ",")
        views = split(view, ",")
    else
        views = [view]
    end
    view_to_csv(lw, trans_meta_map; outdir=output_dir, to_out=views)
end

"""
    lw template

Produce a template excel file for data entry into the Longwing Data Standard.

# Options

- `-o, --output-path=<String>`: The path to create the template in. Defaults to template.xlsx in
    the current directory.
"""
@cast function template(; output_path::String="template.xlsx")
    e = pathof(Longwing)
    e = e[1:(length(e)-11)]
    cp(joinpath(e, "template.xlsx"), output_path)
    @info "New template file created at \"$output_path\""
end

"""
    lw summarise

Summarise a data file (.lw, plate reader, .fcs, etc.).

# Args

- `file`: The data file to be summarised.

# Options

- `-t, --type=<String>`: The type of data file. Options are "auto" (default), "longwing",
    "spectramax", "biotek", "tecan", "bmg", "generic", "fcs". If "auto" is selected, the type will be
    inferred from the file extension (or raise an error if not possible).

# Flags

- `-p, --plot`: Produce plots of the data. Not available for `--type=longwing`.
- `-c, --csv`: Save the data as CSV files. Not available for `--type=longwing`.
"""
@cast function summarise(file; type="auto", plot::Bool=false, csv::Bool=false)
    # If type=="auto", attempt to infer from file extension
    if type == "auto"
        ext = splitext(file)[end]
        if ext == ".lw"
            type = "longwing"
        elseif ext == ".fcs"
            type = "fcs"
        elseif isdir(file)
            type = "generic"
        else
            error("File type $ext cannot be inferred from extension. Supported extensions \
            are .lw or .fcs (or directories for generic tabular plate reader data).")
        end
    end
    if lowercase(type) == "longwing"
        summary(file, LongwingData(); plot=plot)
    elseif lowercase(type) == "fcs"
        summary(file, FlowCytometryData(); plot=plot, csv=csv)
    elseif lowercase(type) == "spectramax"
        summary(file, SpectraMax(); plot=plot, csv=csv)
    elseif lowercase(type) == "biotek"
        summary(file, BioTek(); plot=plot, csv=csv)
    elseif lowercase(type) == "tecan"
        summary(file, Tecan(); plot=plot, csv=csv)
    elseif lowercase(type) == "bmg"
        summary(file, BMG(); plot=plot, csv=csv)
    elseif lowercase(type) == "generic"
        summary(file, GenericTabular(); plot=plot, csv=csv)
    else
        error("Unsupported file type: $type.")
    end
end

"""
    lw interactive

Open a Longwing file in an interactive session.

# Args

- `file`: The Longwing data file to source data from. It should contain all the samples you want
    to use (and potentially a channel map), but does not need transformations, groups,
    views, etc.
"""
@cast function interactive(file)
    lw = read_longwing(file)
    main_menu(lw, false)
    return nothing
end
Comonicon.@main

end # module Longwing
