using Distributions
using Parameters: @kwdef

abstract type AbstractEvergreenPFT  <: AbstractPFT end
abstract type AbstractDeciduousPFT  <: AbstractPFT end
abstract type AbstractGrassPFT     <: AbstractPFT end
abstract type AbstractTundraPFT    <: AbstractPFT end

@kwdef mutable struct PFTCharacteristics{T<:Real,U<:Int}
    name::String = "Default"
    phenological_type::U = 1
    max_min_canopy_conductance::T = 0.0
    Emax::T = 0.0
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
    tcurve::T = 0.0
    respfact::T = 1.0
    allocfact::T = 0.0
    grass::Bool = false
    constraints::NamedTuple{(:tcm, :min, :gdd, :gdd0, :twm, :snow, :swb),NTuple{7,Vector{T}}} = (
        tcm   = [-Inf, +Inf], 
        min   = [-Inf, +Inf], 
        gdd   = [-Inf, +Inf],
        gdd0  = [-Inf, +Inf], 
        twm   = [-Inf, +Inf], 
        snow  = [-Inf, +Inf],
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

PFTCharacteristics() = PFTCharacteristics{Float64,Int}()

@kwdef mutable struct PFTState{T<:Real,U<:Int}
    present::Bool = false
    dominance::T   = 0.0
    greendays::U   = 0
    firedays::T    = 0.0
    mwet::Vector{T} = zeros(T, 12)
    npp::T         = 0.0
    lai::T         = 0.0
end

PFTState(c::PFTCharacteristics{T,U}) where {T,U} = PFTState{T,U}()
PFTState(pft::AbstractPFT) = PFTState(pft.characteristics)
PFTState() = PFTState{Float64,Int}()

const BASE_DEFAULTS = Dict{DataType, NamedTuple}(
    AbstractEvergreenPFT => (
            name                    = "EvergreenBase",
            phenological_type       = 1,           # evergreen
            max_min_canopy_conductance = 0.4,
            Emax                    = 10.0,
            root_fraction_top_soil  = 0.7,
            leaf_longevity          = 20.0,
            sapwood_respiration     = 1,
            optratioa               = 0.85,
            kk                      = 0.60,
            threshold               = 0.33,
            t0                      = 5.0,
            tcurve                  = 0.9,
            respfact                = 2.0,
            allocfact               = 1.2,
            constraints = (
                tcm   = [-Inf, +Inf],
                min   = [-Inf, +Inf],
                gdd   = [-Inf, +Inf],
                gdd0  = [-Inf, +Inf],
                twm   = [-Inf, +Inf],
                snow  = [-Inf, +Inf],
                swb   = [300.0, +Inf]
            ),
            mean_val = (
                clt  = 43.0,
                prec = 110.0,
                temp = 15.0,
            ),
            sd_val = (
                clt  = 9.0,
                prec = 55.0,
                temp = 3.0,
            ),
            dominance_factor = 1
        ),
    AbstractDeciduousPFT => (
           name                    = "DeciduousBase",
           phenological_type       = 2,           # deciduous
           max_min_canopy_conductance = 0.70,
           Emax                    = 10.0,
           root_fraction_top_soil  = 0.7,
           leaf_longevity          = 13.0,
           GDD5_full_leaf_out      = 200.0,
           sapwood_respiration     = 1,
           optratioa               = 0.87,
           kk                      = 0.6,
           threshold               = 0.3,   
           t0                      = 5.0,
           tcurve                  = 0.9,
           respfact                = 2.1,
           allocfact               = 1.2,
           constraints = (
               tcm   = [-15.0, +Inf],
               min   = [-Inf, 5.0],
               gdd   = [900.0, +Inf],
               gdd0  = [-Inf,+Inf],
               twm   = [-Inf,+Inf],
               snow  = [-Inf,+Inf],
               swb   = [300.0,+Inf]
           ),
           mean_val = (
               clt  = 45.0,
               prec = 100.0,
               temp = 9.0,
           ),
           sd_val = (
               clt  = 10.0,
               prec = 70.0,
               temp = 5.0,
           ),
            dominance_factor = 1
   ),
    AbstractGrassPFT => (
        name                       = "GrassBase",
        phenological_type          = 3,
        max_min_canopy_conductance = 0.8,
        Emax                       = 6.5,
        sw_drop                    = 0.2,
        sw_appear                  = 0.3,
        leaf_longevity             = 8.0,
        sapwood_respiration        = 2,
        optratioa                  = 0.65,
        kk                         = 0.4,
        threshold                  = 0.4,
        tcurve                     = 1.0,
        allocfact                  = 1.0,
        grass                      = true,
        constraints = (
            tcm  = [-Inf, Inf],
            min  = [-Inf, Inf],
            gdd  = [-Inf, Inf],
            gdd0 = [-Inf, Inf],
            twm  = [-Inf, Inf],
            snow = [-Inf, Inf],
            swb  = [100.0, Inf]
        )
    ),

    AbstractTundraPFT => (
        name                       = "TundraBase",
        phenological_type          = 2,
        max_min_canopy_conductance = 0.8,
        Emax                       = 1.0,
        root_fraction_top_soil     = 0.93,
        leaf_longevity             = 8.0,
        optratioa                  = 0.9,
        kk                         = 0.5,
        t0                         = -7.0,
        tcurve                     = 0.6,
        respfact                   = 4.0,
        allocfact                  = 1.0,
        constraints = (
            tcm  = [-Inf, Inf],
            min  = [-Inf, Inf],
            gdd  = [-Inf, Inf],
            gdd0 = [50, Inf],
            twm  = [-Inf, 15],
            snow = [15.0, Inf],
            swb  = [300.0, Inf]
        ),
        mean_val = (
            clt  =30.0,
            prec =40.0,
            temp =-5.0,
        ),
        sd_val = (
            clt  =10.0,
            prec =20.0,
            temp =5.0,
        )
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

@kwdef mutable struct EvergreenPFT{T<:Real,U<:Int} <: AbstractEvergreenPFT
    characteristics :: PFTCharacteristics{T,U}
end

EvergreenPFT(c::PFTCharacteristics{T,U}) where {T,U} = EvergreenPFT{T,U}(c)
function EvergreenPFT(; kwargs...)
    c = base_pft(AbstractEvergreenPFT; kwargs...)
    EvergreenPFT(c)
end

@kwdef mutable struct DeciduousPFT{T<:Real,U<:Int} <: AbstractDeciduousPFT
    characteristics :: PFTCharacteristics{T,U}
end

DeciduousPFT(c::PFTCharacteristics{T,U}) where {T,U} = DeciduousPFT{T,U}(c)
function DeciduousPFT(; kwargs...)
    c = base_pft(AbstractDeciduousPFT; kwargs...)
    DeciduousPFT(c)
end

@kwdef mutable struct GrassPFT{T<:Real,U<:Int} <: AbstractGrassPFT
    characteristics :: PFTCharacteristics{T,U}
end

GrassPFT(c::PFTCharacteristics{T,U}) where {T,U} = GrassPFT{T,U}(c)
function GrassPFT(; kwargs...)
    c = base_pft(AbstractGrassPFT; kwargs...)
    GrassPFT(c)
end

@kwdef mutable struct TundraPFT{T<:Real,U<:Int} <: AbstractTundraPFT
    characteristics :: PFTCharacteristics{T,U}
end

TundraPFT(c::PFTCharacteristics{T,U}) where {T,U} = TundraPFT{T,U}(c)
function TundraPFT(; kwargs...)
    c = base_pft(AbstractTundraPFT; kwargs...)
    TundraPFT(c)
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
        EvergreenPFT{T,U}(), DeciduousPFT{T,U}(),
        GrassPFT{T,U}(),    TundraPFT{T,U}(),    Default{T,U}(),
        None{T,U}()
    ])
end

# default, infer types via the vector‐based constructor
PFTClassification() = PFTClassification([
    EvergreenPFT{T,U}(), DeciduousPFT{T,U}(),
    GrassPFT(), TundraPFT(), Default(), None()
])

function get_characteristic(pft::AbstractPFT, prop::Symbol)
    if hasproperty(pft.characteristics, prop)
        return getproperty(pft.characteristics, prop)
    else
        throw(ArgumentError("`$(prop)` is not a PFTCharacteristics field"))
    end
end

function dominance_environment(pft::AbstractPFT, variable::Symbol, clt::Real)
    mv = get_characteristic(pft, :mean_val)[variable]
    sd = get_characteristic(pft, :sd_val)[variable]
    dist = Normal(mv, sd)
    pdf(dist, clt) / pdf(dist, mv)
end
