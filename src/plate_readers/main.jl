abstract type AbstractPlateReaderMethod <: AbstractLongwingMethod end

abstract type AbstractPlateReader <: AbstractLongwingDataType end

include("read.jl")
include("calibrate.jl")
include("growth_rate.jl")
include("fluorescence_per_cell.jl")
include("smoothing.jl")
include("quantification.jl")
