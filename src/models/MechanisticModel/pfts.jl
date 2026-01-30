using Distributions
using Parameters: @kwdef

abstract type AbstractEvergreenPFT  <: AbstractPFT end
abstract type AbstractNeedleleafEvergreenPFT  <: AbstractEvergreenPFT end
abstract type AbstractBroadleafEvergreenPFT  <: AbstractEvergreenPFT end

abstract type AbstractDeciduousPFT  <: AbstractPFT end
abstract type AbstractNeedleleafDeciduousPFT  <: AbstractDeciduousPFT end
abstract type AbstractBroadleafDeciduousPFT  <: AbstractDeciduousPFT end

abstract type AbstractGrassPFT  <: AbstractPFT end
abstract type AbstractC3GrassPFT     <: AbstractGrassPFT end
abstract type AbstractC4GrassPFT   <: AbstractGrassPFT end

@kwdef mutable struct PFTCharacteristics{T<:Real,U<:Int}
    name::String = "Default"
    phenological_type::U = 1
    max_min_canopy_conductance::T = 0.0
    Emax::T = 1.0
    sw_drop::T = 0.0
    sw_appear::T = 0.0
    root_fraction_top_soil::T = 0.0
    leaf_longevity::T = 0.0
    GDD5_full_leaf_out::T = 1.0
    GDD0_full_leaf_out::T = 1.0
    sapwood_respiration::U = 1
    optratioa::T = 1.0
    kk::T = 1.0
    c4::Bool = false
    threshold::T = 0.0
    t0::T = 0.0
    tcurve::T = 1.0
    respfact::T = 1.0
    allocfact::T = 0.0
    grass::Bool = false
    constraints::NamedTuple = (
        tcm   = [-Inf, +Inf], 
        tmin   = [-Inf, +Inf], 
        gdd5   = [-Inf, +Inf],
        gdd0  = [-Inf, +Inf], 
        twm   = [-Inf, +Inf], 
        maxdepth  = [-Inf, +Inf],
        swb   = [-Inf, +Inf]
    )
    dominance_factor::U = 5
    minimum_lai::T = 0.0
end

mutable struct PFTState{T<:Real,U<:Int}
    present::Bool
    fitness::T
    greendays::U
    firedays::T
    mwet::Vector{T}
    npp::T
    lai::T
end

# Default constructor with type parameters
PFTState{T,U}() where {T<:Real,U<:Int} = PFTState{T,U}(false, T(0.0), U(0), T(0.0), zeros(T, 12), T(0.0), T(0.0))

# Convenience constructor for Float64,Int defaults
PFTState(c::PFTCharacteristics{T,U}) where {T,U} = PFTState{T,U}()
PFTState(pft::AbstractPFT) = PFTState(pft.characteristics)
PFTState() = PFTState()

const BASE_DEFAULTS = Dict{DataType, NamedTuple}(
    AbstractNeedleleafEvergreenPFT => (
            name                    = "NeedleleafEvergreenBase",
            phenological_type       = 1,           # evergreen
            max_min_canopy_conductance = 0.35,
            Emax                    = 4.7,
            root_fraction_top_soil  = 0.7,
            leaf_longevity          = 28.0,
            sapwood_respiration     = 1,
            optratioa               = 0.85,
            kk                      = 0.5,
            threshold               = 0.38,
            t0                      = 1.5,
            tcurve                  = 0.85,
            respfact                = 2.0,
            allocfact               = 1.2,
            constraints = (
                tcm   = [-45, +Inf],
                tmin   = [-Inf, +Inf],
                gdd5   = [750, 6000],
                gdd0  = [-Inf, +Inf],
                twm   = [-Inf, +Inf],
                maxdepth  = [-Inf, +Inf],
                swb   = [400.0, +Inf]
            ),
            dominance_factor = 3
        ),
    AbstractBroadleafEvergreenPFT => (
            name                    = "BroadleafEvergreenBase",
            phenological_type       = 1,           # evergreen
            max_min_canopy_conductance = 0.35,
            Emax                    = 7.0,
            root_fraction_top_soil  = 0.68,
            leaf_longevity          = 18.0,
            sapwood_respiration     = 1,
            optratioa               = 0.85,
            kk                      = 0.65,
            threshold               = 0.33,
            t0                      = 7.5,
            tcurve                  = 1.0,
            respfact                = 1.1,
            allocfact               = 1.1,
            constraints = (
                tcm   = [-32.5, +Inf],
                tmin   = [-25.0, +Inf],
                gdd5   = [1200, +Inf],
                gdd0  = [-Inf, +Inf],
                twm   = [10.0, +Inf],
                maxdepth  = [-Inf, +Inf],
                swb   = [400.0, +Inf]
            ),
            dominance_factor = 2
        ),
    AbstractNeedleleafDeciduousPFT => (
            name                    = "NeedleleafDeciduousBase",
            phenological_type       = 2,                   # deciduous
            max_min_canopy_conductance = 0.8,        # average of 0.2–0.8
            Emax                    = 6.5,                               # typical value for needleleaf
            sw_drop                 = -99.9,                            # as used in deciduous
            sw_appear               = -99.9,
            root_fraction_top_soil  = 0.83,            # moderate rooting
            leaf_longevity          = 24.0,                   # in months (1 year)
            GDD5_full_leaf_out      = 200.0,              # earlier onset than evergreen
            GDD0_full_leaf_out      = -99.9,                # default
            sapwood_respiration     = 1,                 
            optratioa               = 0.9,                         # moderate photosynthetic efficiency
            kk                      = 0.4,                                 # light extinction coefficient
            c4                      = false,
            threshold               = 0.33,
            t0                      = 0.0,                                 # same as other trees
            tcurve                  = 0.8,
            respfact                = 4.0,
            allocfact               = 1.2,
            grass                   = false,
            constraints = (
                tcm  = [-Inf, 5.0],
                tmin  = [-Inf, -15.0],
                gdd5  = [300, 1600],
                gdd0 = [-Inf, +Inf],
                twm  = [-Inf, 21.0],
                maxdepth = [-Inf, +Inf],
                swb  = [400.0, +Inf]
            ),
            dominance_factor = 3
    ),
    AbstractBroadleafDeciduousPFT => (
        name                    = "BroadleafDeciduousBase",
        phenological_type       = 2,           # deciduous
        max_min_canopy_conductance = 0.80,
        Emax                    = 10.0,
        root_fraction_top_soil  = 0.75,
        leaf_longevity          = 13.0,
        GDD5_full_leaf_out      = 200.0,
        sapwood_respiration     = 1,
        optratioa               = 0.87,
        kk                      = 0.6,
        threshold               = 0.3,   
        t0                      = 4.0,
        tcurve                  = 1.0,
        respfact                = 2.6,
        allocfact               = 1.2,
        constraints = (
            tcm   = [-Inf, +Inf],
            tmin   = [-Inf, +Inf],
            gdd5   = [1000, 8000],
            gdd0  = [-Inf,+Inf],
            twm   = [-Inf,+Inf],
            maxdepth  = [-Inf,+Inf],
            swb   = [400.0,+Inf]
        ),
        dominance_factor = 3
    ),
    AbstractC3GrassPFT => (
        name                       = "C3GrassBase",
        phenological_type          = 3,
        max_min_canopy_conductance = 0.8,
        Emax                       = 6.5,
        sw_drop                    = 0.2,
        sw_appear                  = 0.3,
        leaf_longevity             = 8.0,
        root_fraction_top_soil      = 0.83,   
        sapwood_respiration        = 2,
        optratioa                  = 0.65,
        kk                         = 0.4,
        c4                         = false,
        threshold                  = 0.4,
        tcurve                     = 1.0,
        respfact                   = 1.6,
        allocfact                  = 1.0,
        grass                      = true,
        constraints = (
            tcm  = [-Inf, Inf],
            tmin  = [-Inf, Inf],
            gdd5  = [-Inf, Inf],
            gdd0 = [-Inf, Inf],
            twm  = [-Inf, Inf],
            maxdepth = [-Inf, Inf],
            swb  = [100.0, Inf]
        ),
        dominance_factor = 5
    ),
    AbstractC4GrassPFT => (
        name                       = "C4GrassBase",
        phenological_type          = 3,
        max_min_canopy_conductance = 0.8,
        Emax                       = 8.0,
        sw_drop                    = 0.2,
        sw_appear                  = 0.3,
        root_fraction_top_soil      = 0.57,   
        leaf_longevity             = 10.0,
        sapwood_respiration        = 2,
        optratioa                  = 0.65,
        kk                         = 0.4,
        c4                         = true,
        threshold                  = 0.4,
        t0                         = 10.0,
        tcurve                     = 1.0,  
        respfact                   = 0.8,
        allocfact                  = 1.0,
        grass                      = true,
        constraints = (
            tcm  = [-Inf, Inf],
            tmin  = [-3.0, Inf],
            gdd5  = [-Inf, Inf],
            gdd0 = [-Inf, Inf],
            twm  = [10.0, Inf],
            maxdepth = [-Inf, Inf],
            swb  = [100.0, Inf]
        ),
        dominance_factor = 5
    )
)

function base_pft(::Type{P}; kwargs...) where {P<:AbstractPFT}
    defaults = BASE_DEFAULTS[P]
    merged = merge(defaults, kwargs)
    reals = filter(x->x isa Real, values(merged))
    ints = filter(x->x isa Integer, values(merged))
    T = isempty(reals) ? Float64 : promote_type(map(typeof, reals)...)
    U = isempty(ints)  ? Int     : promote_type(map(typeof, ints)...)
    return PFTCharacteristics{T,U}(; merged...)
end

@kwdef mutable struct NeedleleafEvergreenPFT{T<:Real,U<:Int} <: AbstractNeedleleafEvergreenPFT
    characteristics :: PFTCharacteristics{T,U}
end

function NeedleleafEvergreenPFT(c::PFTCharacteristics{T,U}) where {T,U}
    NeedleleafEvergreenPFT{T,U}(c)
end
function NeedleleafEvergreenPFT(; kwargs...)
    c = base_pft(AbstractNeedleleafEvergreenPFT; kwargs...)
    NeedleleafEvergreenPFT(c)
end

@kwdef mutable struct BroadleafEvergreenPFT{T<:Real,U<:Int} <: AbstractBroadleafEvergreenPFT
    characteristics :: PFTCharacteristics{T,U}
end

function BroadleafEvergreenPFT(c::PFTCharacteristics{T,U}) where {T,U}
    BroadleafEvergreenPFT{T,U}(c)
end
function BroadleafEvergreenPFT(; kwargs...)
    c = base_pft(AbstractBroadleafEvergreenPFT; kwargs...)
    BroadleafEvergreenPFT(c)
end

@kwdef mutable struct BroadleafDeciduousPFT{T<:Real,U<:Int} <: AbstractBroadleafDeciduousPFT
    characteristics :: PFTCharacteristics{T,U}
end

function BroadleafDeciduousPFT(c::PFTCharacteristics{T,U}) where {T,U}
    BroadleafDeciduousPFT{T,U}(c)
end
function BroadleafDeciduousPFT(; kwargs...)
    c = base_pft(AbstractBroadleafDeciduousPFT; kwargs...)
    BroadleafDeciduousPFT(c)
end

@kwdef mutable struct NeedleleafDeciduousPFT{T<:Real,U<:Int} <: AbstractNeedleleafDeciduousPFT
    characteristics :: PFTCharacteristics{T,U}
end

function NeedleleafDeciduousPFT(c::PFTCharacteristics{T,U}) where {T,U}
    NeedleleafDeciduousPFT{T,U}(c)
end
function NeedleleafDeciduousPFT(; kwargs...)
    c = base_pft(AbstractNeedleleafDeciduousPFT; kwargs...)
    NeedleleafDeciduousPFT(c)
end


@kwdef mutable struct C3GrassPFT{T<:Real,U<:Int} <: AbstractC3GrassPFT
    characteristics :: PFTCharacteristics{T,U}
end

function C3GrassPFT(c::PFTCharacteristics{T,U}) where {T,U}
    C3GrassPFT{T,U}(c)
end
function C3GrassPFT(; kwargs...)
    c = base_pft(AbstractC3GrassPFT; kwargs...)
    C3GrassPFT(c)
end

@kwdef mutable struct C4GrassPFT{T<:Real,U<:Int} <: AbstractC4GrassPFT
    characteristics :: PFTCharacteristics{T,U}
end

function C4GrassPFT(c::PFTCharacteristics{T,U}) where {T,U}
    C4GrassPFT{T,U}(c)
end
function C4GrassPFT(; kwargs...)
    c = base_pft(AbstractC4GrassPFT; kwargs...)
    C4GrassPFT(c)
end


struct Default{T<:Real,U<:Int} <: AbstractPFT
    characteristics::PFTCharacteristics{T,U}
end

function Default(c::PFTCharacteristics{T,U}) where {T,U}
    Default{T,U}(c)
end
function Default(; kwargs...)
    c = PFTCharacteristics(; kwargs...)
    Default(c)
end

struct None{T<:Real,U<:Int} <: AbstractPFT
    characteristics::PFTCharacteristics{T,U}
end

function None(c::PFTCharacteristics{T,U}) where {T,U}
    None{T,U}(c)
end
function None(; kwargs...)
    c = PFTCharacteristics(; kwargs...)
    None(c)
end

struct PFTClassification{T<:Real,U<:Int} <: AbstractPFTList
    pft_list::Vector{AbstractPFT}
end


function PFTClassification(pfts::Vector{P} ) where P<:AbstractPFT
    isempty(pfts) && return PFTClassification()
    T = typeof(pfts[1].characteristics).parameters[1]
    U = typeof(pfts[1].characteristics).parameters[2]
    return PFTClassification{T,U}(pfts)
end

function PFTClassification(p1::AbstractPFT, rest::AbstractPFT...)
    PFTClassification([p1; rest])
end

function PFTClassification{T,U}() where {T<:Real,U<:Int}
    PFTClassification{T,U}([
        NeedleleafEvergreenPFT{T,U}(),
        BroadleafEvergreenPFT{T,U}(),
        NeedleleafDeciduousPFT{T,U}(),
        BroadleafDeciduousPFT{T,U}(),
        C3GrassPFT{T,U}(),
        C4GrassPFT{T,U}(),
        Default{T,U}(),
        None{T,U}()
    ])
end

# default, infer types via the vector‐based constructor
PFTClassification() = PFTClassification([
    NeedleafEvergreenPFT(),
    BroadleafEvergreenPFT(),
    NeedleleafDeciduousPFT(),
    BroadleafDeciduousPFT(),
    C3GrassPFT(),
    C4GrassPFT(),
    Default(),
    None()
])

function get_characteristic(pft::AbstractPFT, prop::Symbol)
    if hasproperty(pft.characteristics, prop)
        return getproperty(pft.characteristics, prop)
    else
        throw(ArgumentError("`$(prop)` is not a PFTCharacteristics field"))
    end
end

@inline function dist_to_interval(x::T, lo::T, hi::T) where {T<:Real}
    if x < lo
        return lo - x
    elseif x > hi
        return x - hi
    else
        return 0.0
    end
end

function choose_softness(var::Symbol, lo::T, hi::T,
    fallback = (tcm=T(4.0), tmin=T(4.0), gdd5=T(800.0), gdd0=T(800.0), twm=T(2.5), maxdepth=T(7.5)),
    mins     = (tcm=T(1.0), tmin=T(1.0), gdd5=T(300.0), gdd0=T(300.0), twm=T(1.0), maxdepth=T(2.0)),
    maxs     = (tcm=T(10.0), tmin=T(10.0), gdd5=T(2000.0), gdd0=T(2000.0), twm=T(8.0), maxdepth=T(20.0)),
    frac::T = T(0.25)
) where {T<:Real}
    if isfinite(lo) && isfinite(hi) && hi > lo
        s = frac * (hi - lo)
        return clamp(s, mins[var], maxs[var])
    else
        return fallback[var]
    end
end

function dominance_environment_mv(pft::AbstractPFT;
    tcm::T, tmin::T, gdd5::T, gdd0::T, twm::T, maxdepth::T,
    minval::Union{T,Nothing} = nothing) where {T<:Real}
    cons = get_characteristic(pft, :constraints)
    
    minval = isnothing(minval) ? T(0.01) : minval
    d2 = T(0.0)
    for (var, x) in (
        (:tcm, tcm), (:tmin, tmin), (:gdd5, gdd5), (:gdd0, gdd0),
        (:twm, twm), (:maxdepth, maxdepth)
    )
        lo = T(cons[var][1])
        hi = T(cons[var][2])

        d  = dist_to_interval(x, lo, hi)
        s  = choose_softness(var, lo, hi)

        d2 += (d / s)^2
    end

    value = exp(-T(0.5) * d2)
    return max(value, T(minval))
end

"""
    change_type(x, Tnew::Type; Unew::Type=Int)

Recursively convert all numeric fields and nested structs within `x` to use
the new numeric type `Tnew`, preserving structure and field names.
If the structure is parametric (e.g. `PFTClassification{T,U}`), it returns
a new instance of the same type but with `{Tnew, Unew}`.

This is useful in initialization to make sure that the PFTList has the same 
datatype as the input Rasters
"""
function change_type(x, Tnew::Type; Unew::Type=Int)
    if x isa Number
        return convert(Tnew, x)
    elseif x isa AbstractVector
        return [change_type(el, Tnew; Unew=Unew) for el in x]
    elseif x isa NamedTuple
        return NamedTuple{keys(x)}(change_type.(values(x), Tnew; Unew=Unew))
    elseif fieldcount(typeof(x)) > 0
        # If it's a composite struct, rebuild it
        vals = [change_type(getfield(x, f), Tnew; Unew=Unew) for f in fieldnames(typeof(x))]
        if length(typeof(x).parameters) == 2 &&
           typeof(x).parameters[1] <: Real &&
           typeof(x).parameters[2] <: Int
            newT = typeof(x).name.wrapper{Tnew, Unew}
            return newT(vals...)
        else
            return typeof(x)(vals...)
        end
    else
        return x
    end
end

