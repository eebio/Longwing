using CSV
using DataFrames

"""
    produce_views(lw, trans_meta_map;to_out=[])

Produces the subset of views specified in `to_out` or all views if unspecified.

Arguments:
- `lw::lw_zones`: The lw_zones object
- `trans_meta_map::Dict`: A dictionary mapping transformations to their names.
- `to_out::Vector{String}`: A list of all the views to be produced.
"""
function produce_views(lw, trans_meta_map; to_out=[])
    # No views specified? Do all then
    if to_out == []
        to_out = keys(lw.views)
    end
    # Initialise the output of views dict
    v_out = Dict()
    for i in to_out
        @info "Producing view $i."
        # Initialise the result dict that can be concatenated later
        result = []
        # Loop over the views list
        for j in lw.views[i]["data"]
            exp = sexp_to_nested_list(Meta.parse(j), lw, trans_meta_map)
            push!(result, eval(exp))
        end
        # Put it all in the same frame and not a vector
        if any(isa.(result, AbstractVecOrMat)) || any(isa.(result, Number))
            v_out[i] = Tables.table(hcat(result...))
        elseif any(isa.(result, AbstractDataFrame))
            # TODO If transforms are a comma separated list (internally a tuple), then a view of that transform will be [(results...)], which when splatted is still a tuple of results
            v_out[i] = hcat(result..., makeunique=true)
        else
            v_out[i] = result
        end
    end
    @info "Views produced."
    return v_out
end

"""
    view_to_csv(lw,trans_meta_map;out_dir,to_out)

Produces views and writes them to CSV files.

Arguments:
- `lw::lw_zones`: The original Longwing struct
- `trans_meta_map::Dict`: The transformations that have been parsed at the top level.
- `outdir::String`: The specified output dir - defaults to nothing.
- `to_out::Vector{String}`: The views to be processed.
"""
function view_to_csv(lw, trans_meta_map; outdir="", to_out=[])
    # Process the views
    vs = produce_views(lw, trans_meta_map; to_out=to_out)
    # Write the views to file
    for i in keys(vs)
        if Tables.istable(vs[i])
            @info "Writing view: $i to $(joinpath(outdir,i*".csv"))"
            CSV.write("$(joinpath(outdir,i*".csv"))", vs[i])
        else
            @info "View $i is not a table and cannot be written to CSV."
            if length(vs[i]) == 1
                @info "$i = $(vs[i][1])"
            else
                @info "$i = $(Tuple(vs[i]))"
            end
        end
    end
    @info "Views written successfully."
end

const BLOCKED_CALLS = [
    :eval,
    :run,
    :Filesystem,
    :include,
    :read,
    :write,
    :success,
    :unsafe_load,
    :unsafe_read,
    :unsafe_write,
    :unsafe_wrap,
    :unsafe_store!,
    :unsafe_swap!,
    :unsafe_string,
    :rm,
    :mv,
    :cp,
    :mkdir,
    :mkpath,
    :walkpath,
    :chmod,
    :touch,
    :download,
]

const BLOCKED_MACROS = [
    Symbol("@eval"),
    Symbol("@includet"),
    Symbol("@ccall"),
    Symbol("@llvmcall"),
    Symbol("@cglobal")
]

function _check_expression(sexp)
    if sexp.head == :call
        func_name = sexp.args[1]
        check_expression_args(func_name)
    end
    if sexp.head == :macrocall
        macro_name = sexp.args[1]
        if macro_name in BLOCKED_MACROS
            error("Blocked macro call: $macro_name")
        end
    end
end

function check_expression_args(sexp)
    if sexp isa Expr
        for arg in sexp.args
            check_expression_args(arg)
        end
    elseif sexp isa Symbol
        if sexp in BLOCKED_CALLS
            error("Blocked function call: $sexp")
        end
    elseif sexp isa QuoteNode
        if sexp.value in BLOCKED_CALLS
            error("Blocked function call: $(sexp.value)")
        end
    end
end

"""
    sexp_to_nested_list(sexp,lw,trans_meta_map)

Recursively converts the parsed equations to julia code and produces the correct dataframes
    over which to operate. This also calls any unprocessed transformations.

Arguments:
- sexp: Expression or part of expression to be decomposed.
- lw: The lw_zones data type that contains the data.
- trans_meta_map: The transformation map of the parsed transformations.
"""
function sexp_to_nested_list(sexp, lw, trans_meta_map)
    if isa(sexp, Symbol)
        if sexp in keys(trans_meta_map)
            # Is the symbol a transformation
            return sexp_to_nested_list(trans_meta_map[sexp], lw, trans_meta_map)
        elseif string(sexp) in lw.groups.group
            # Is the symbol a group?
            return Longwing.get_group(lw, sexp)
        elseif string(sexp) in first.(splitext.(lw.samples.name))
            # Is the symbol a sample?
            return Longwing.get_sample(lw, string(sexp))
        end
        # Just return it - its something else
        return sexp
    end
    if isa(sexp, Expr)
        _check_expression(sexp)
        # Check if the symbol is an expression as this could mean further processing
        for i in eachindex(sexp.args)
            # Recursively process each argument of the expression
            if sexp.head == :kw && i == 1
                # If this is a keyword argument, don't process the first argument as it is the keyword name
                continue
            end
            sexp.args[i] = sexp_to_nested_list(sexp.args[i], lw, trans_meta_map)
        end
        if sexp.head == :.
            # If there is a dot expression, this could be a channel access
            channel = sexp.args[end]
            if channel isa QuoteNode
                channel = channel.value
            end
            if channel isa Symbol && length(sexp.args) == 2
                channel = string(channel)
                # Want to make sure this isn't some other dot expression
                if any(last.(splitext.(lw.samples.name)) .== ".$channel")
                    # This is channel access
                    return Longwing.filter_channel(sexp.args[1], channel)
                end
            end
        end
        # Just return the expression as is now its processed
        return sexp
    end
    # Not a symbol or expression - return as is
    return sexp
end

function run_transformation(lw, transform)
    trans_meta_map = Dict(Symbol(i) => Meta.parse(lw.transformations[i]["equation"])
                          for i in keys(lw.transformations))
    expression = sexp_to_nested_list(Meta.parse(transform), lw, trans_meta_map)
    return eval(expression)
end
