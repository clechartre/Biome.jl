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
    mean_val::NamedTuple{(:clt, :prec, :temp),NTuple{3,T}} = (
        clt   = 30.6, prec  = 72.0, temp  = 24.5
    )
    sd_val::NamedTuple{(:clt, :prec, :temp),NTuple{3,T}} = (
        clt   = 9.7, prec  = 39.0, temp  = 3.2
    )
    dominance_factor::U = 5
end

@kwdef mutable struct PFTState{T<:Real,U<:Int}
    present::Bool = false
    fitness::T   = 0.0
    greendays::U   = 0
    firedays::T    = 0.0
    mwet::Vector{T} = zeros(T, 12)
    npp::T         = 0.0
    lai::T         = 0.0
end

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
                tcm   = [-32.5, +Inf],
                tmin   = [-Inf, +Inf],
                gdd5   = [-Inf, +Inf],
                gdd0  = [-Inf, +Inf],
                twm   = [-Inf, +Inf],
                maxdepth  = [-Inf, +Inf],
                swb   = [400.0, +Inf]
            ),
            mean_val = (
                clt  = 37.6,
                prec = 54.5,
                temp = 5.3,
            ),
            sd_val = (
                clt  = 9.1,
                prec = 25.0,
                temp = 6.0,
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
                tcm   = [-Inf, +Inf],
                tmin   = [-8.0, +Inf],
                gdd5   = [1200, +Inf],
                gdd0  = [-Inf, +Inf],
                twm   = [10.0, +Inf],
                maxdepth  = [-Inf, +Inf],
                swb   = [400.0, +Inf]
            ),
            mean_val = (
                clt  = 37.6,
                prec = 117.1,
                temp = 20.7,
            ),
            sd_val = (
                clt  = 8.75,
                prec = 47.2,
                temp = 2.6,
            ),
            dominance_factor = 2
        ),
    AbstractNeedleleafDeciduousPFT => (
            name                    = "NeedleleafDeciduous",
            phenological_type       = 2,                   # deciduous
            max_min_canopy_conductance = 0.4,        # average of 0.2–0.8
            Emax                    = 6.5,                               # typical value for needleleaf
            sw_drop                 = 0.5,                            # as used in deciduous
            sw_appear               = 0.6,
            root_fraction_top_soil  = 0.7,            # moderate rooting
            leaf_longevity          = 12.0,                   # in months (1 year)
            GDD5_full_leaf_out      = 200.0,              # earlier onset than evergreen
            GDD0_full_leaf_out      = 1.0,                # default
            sapwood_respiration     = 1,                 
            optratioa               = 0.85,                         # moderate photosynthetic efficiency
            kk                      = 0.5,                                 # light extinction coefficient
            c4                      = false,
            threshold               = 0.33,
            t0                      = 3.0,                                 # same as other trees
            tcurve                  = 0.9,
            respfact                = 1.2,
            allocfact               = 1.2,
            grass                   = false,
            constraints = (
                tcm  = [-25.0, +Inf],
                tmin  = [-Inf, -10.0],
                gdd5  = [900.0, +Inf],
                gdd0 = [-Inf, +Inf],
                twm  = [-Inf, +Inf],
                maxdepth = [-Inf, +Inf],
                swb  = [400.0, +Inf]
            ),
            mean_val = (
                clt = 37.9, 
                prec = 55.7, 
                temp = 4.8
            ),
            sd_val = (
                clt = 7.5, 
                prec = 40.0, 
                temp = 3.5
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
            gdd5   = [-Inf, +Inf],
            gdd0  = [-Inf,+Inf],
            twm   = [-Inf,+Inf],
            maxdepth  = [-Inf,+Inf],
            swb   = [400.0,+Inf]
        ),
        mean_val = (
            clt  = 38.6,
            prec = 70.9,
            temp = 7.9,
        ),
        sd_val = (
            clt  = 7.4,
            prec = 58.2,
            temp = 7.3,
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
        mean_val = (clt=16.6, prec=12.2, temp=21.3), 
        sd_val = (clt=6.9, prec=13.4, temp=6.2),
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
        mean_val = (clt=9.4, prec=1.7, temp=23.2), 
        sd_val = (clt=1.4, prec=2.1, temp=2.2),
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

NeedleleafEvergreenPFT(c::PFTCharacteristics{T,U}) where {T,U} = NeedleleafEvergreenPFT{T,U}(c)
function NeedleleafEvergreenPFT(; kwargs...)
    c = base_pft(AbstractNeedleleafEvergreenPFT; kwargs...)
    NeedleleafEvergreenPFT(c)
end

@kwdef mutable struct BroadleafEvergreenPFT{T<:Real,U<:Int} <: AbstractBroadleafEvergreenPFT
    characteristics :: PFTCharacteristics{T,U}
end

BroadleafEvergreenPFT(c::PFTCharacteristics{T,U}) where {T,U} = BroadleafEvergreenPFT{T,U}(c)
function BroadleafEvergreenPFT(; kwargs...)
    c = base_pft(AbstractBroadleafEvergreenPFT; kwargs...)
    BroadleafEvergreenPFT(c)
end

@kwdef mutable struct BroadleafDeciduousPFT{T<:Real,U<:Int} <: AbstractBroadleafDeciduousPFT
    characteristics :: PFTCharacteristics{T,U}
end

BroadleafDeciduousPFT(c::PFTCharacteristics{T,U}) where {T,U} = BroadleafDeciduousPFT{T,U}(c)
function BroadleafDeciduousPFT(; kwargs...)
    c = base_pft(AbstractBroadleafDeciduousPFT; kwargs...)
    BroadleafDeciduousPFT(c)
end

@kwdef mutable struct NeedleleafDeciduousPFT{T<:Real,U<:Int} <: AbstractBroadleafDeciduousPFT
    characteristics :: PFTCharacteristics{T,U}
end

NeedleleafDeciduousPFT(c::PFTCharacteristics{T,U}) where {T,U} = NeedleleafDeciduousPFT{T,U}(c)
function NeedleleafDeciduousPFT(; kwargs...)
    c = base_pft(AbstractNeedleleafDeciduousPFT; kwargs...)
    NeedleleafDeciduousPFT(c)
end


@kwdef mutable struct C3GrassPFT{T<:Real,U<:Int} <: AbstractC3GrassPFT
    characteristics :: PFTCharacteristics{T,U}
end

C3GrassPFT(c::PFTCharacteristics{T,U}) where {T,U} = C3GrassPFT{T,U}(c)
function C3GrassPFT(; kwargs...)
    c = base_pft(AbstractC3GrassPFT; kwargs...)
    C3GrassPFT(c)
end

@kwdef mutable struct C4GrassPFT{T<:Real,U<:Int} <: AbstractC4GrassPFT
    characteristics :: PFTCharacteristics{T,U}
end

C4GrassPFT(c::PFTCharacteristics{T,U}) where {T,U} = C4GrassPFT{T,U}(c)
function C4GrassPFT(; kwargs...)
    c = base_pft(AbstractC4GrassPFT; kwargs...)
    C4GrassPFT(c)
end


struct Default{T<:Real,U<:Int} <: AbstractPFT
    characteristics::PFTCharacteristics{T,U}
end

Default(c::PFTCharacteristics{T,U}) where {T,U} = Default{T,U}(c)
function Default(; kwargs...)
    c = PFTCharacteristics(; kwargs...)
    Default(c)
end

struct None{T<:Real,U<:Int} <: AbstractPFT
    characteristics::PFTCharacteristics{T,U}
end

None(c::PFTCharacteristics{T,U}) where {T,U} = None{T,U}(c)
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
        NeedleafEvergreenPFT{T,U}(),
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

function dominance_environment_mv(pft::AbstractPFT, clt::Real, prec::Real, temp::Real)
    mean_tuple = get_characteristic(pft, :mean_val)
    sd_tuple   = get_characteristic(pft, :sd_val)

    μ = [mean_tuple.clt, mean_tuple.prec, mean_tuple.temp]
    σ = [sd_tuple.clt, sd_tuple.prec, sd_tuple.temp]
    point = [clt, prec, temp]

    d² = sum(((point .- μ) ./ σ).^2)
    value = exp(-0.5 * d²)

    return max(value, 0.01)  # Ensure a small positive minimum
end
