using Distributions
using Parameters: @kwdef

abstract type AbstractTropicalPFT <: AbstractPFT end
abstract type AbstractTemperatePFT <: AbstractPFT end
abstract type AbstractBorealPFT    <: AbstractPFT end
abstract type AbstractGrassPFT     <: AbstractPFT end
abstract type AbstractTundraPFT    <: AbstractPFT end

@kwdef mutable struct PFTCharacteristics{T<:Real,U<:Int}
    name::String = "Default"
    phenological_type::U = U(1)
    max_min_canopy_conductance::T = T(0.0)
    Emax::T = T(0.0)
    sw_drop::T = T(0.0)
    sw_appear::T = T(0.0)
    root_fraction_top_soil::T = T(0.0)
    leaf_longevity::T = T(0.0)
    GDD5_full_leaf_out::T = T(1.0)
    GDD0_full_leaf_out::T = T(1.0)
    sapwood_respiration::U = U(1)
    optratioa::T = T(1.0)
    kk::T = T(1.0)
    c4::Bool = false
    threshold::T = T(0.0)
    t0::T = T(0.0)
    tcurve::T = T(0.0)
    respfact::T = T(0.0)
    allocfact::T = T(0.0)
    grass::Bool = false
    constraints::NamedTuple{(:tcm, :min, :gdd, :gdd0, :twm, :snow, :swb),
                            NTuple{7,Vector{T}}} = 
                            (;
        tcm   = [-Inf, +Inf], 
        min   = [-Inf, +Inf], 
        gdd   = [-Inf, +Inf],
        gdd0  = [-Inf, +Inf], 
        twm   = [-Inf, +Inf], 
        snow  = [-Inf, +Inf],
        swb   = [-Inf, +Inf]
    )

    mean_val::NamedTuple{(:clt, :prec, :temp),NTuple{3,T}} = (;
        clt   = T(30.6), prec  = T(72.0), temp  = T(24.5)
    )

    sd_val::NamedTuple{(:clt, :prec, :temp),NTuple{3,T}} = (;
        clt   = T(9.7), prec  = T(39.0), temp  = T(3.2)
    )
end

PFTCharacteristics() = PFTCharacteristics{Float64,Int}()

@kwdef mutable struct PFTState{T<:Real,U<:Int}
    present::Bool = false
    dominance::T   = zero(T)
    greendays::U   = zero(U)
    firedays::T    = zero(T)
    mwet::Vector{T} = zeros(T,12)
    npp::T         = zero(T)
    lai::T         = zero(T)
end

const BASE_DEFAULTS = Dict{DataType, NamedTuple}(
    AbstractTropicalPFT => (
        name                       = "TropicalBase",
        phenological_type          = 1,
        max_min_canopy_conductance = 0.5,
        Emax                       = 10.0,
        root_fraction_top_soil     = 0.69,
        optratioa                  = 0.95,
        kk                         = 0.7,
        t0                         = 10.0,
        tcurve                     = 1.0,
        respfact                   = 0.8,
        allocfact                  = 1.0,
        constraints = (
            tcm  = [-Inf,  Inf],
            min  = [0.0,   Inf],
            gdd  = [-Inf,  Inf],
            gdd0 = [-Inf,  Inf],
            twm  = [10.0,  Inf],
            snow = [-Inf,  Inf],
            swb  = [500.0, Inf]
        )
    ),

    AbstractTemperatePFT => (
        name                  = "TemperateBase",
        phenological_type     = 2,
        Emax                  = 5.0,
        root_fraction_top_soil = 0.67,
        GDD5_full_leaf_out    = 200.0,
        optratioa             = 0.8,
        kk                    = 0.65,
        t0                    = 5.0,
        tcurve                = 1.0,
        respfact              = 1.45,
        allocfact             = 1.2,
        constraints = (
            tcm  = [-15.0, Inf],
            min  = [-Inf, 5.0],
            gdd  = [900.0, Inf],
            gdd0 = [-Inf,  Inf],
            twm  = [-Inf,  Inf],
            snow = [-Inf,  Inf],
            swb  = [400.0, Inf]
        )
    ),

    AbstractBorealPFT => (
        name                    = "BorealBase",
        phenological_type       = 1,
        Emax                    = 4.5,
        root_fraction_top_soil  = 0.83,
        leaf_longevity          = 24.0,
        optratioa               = 0.9,
        kk                      = 0.4,
        threshold               = 0.33,
        t0                      = 0.0,
        tcurve                  = 0.8,
        respfact                = 4.0,
        allocfact               = 1.2,
        constraints = (
            tcm  = [-Inf, 5.0],
            min  = [-Inf, Inf],
            gdd  = [-Inf, Inf],
            gdd0 = [-Inf, Inf],
            twm  = [-Inf, 21.0],
            snow = [-Inf, Inf],
            swb  = [300.0, Inf]
        )
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
            swb  = [250.0, Inf]
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
        )
    )
)

function base_pft(::Type{P}, ::Type{T}, ::Type{U}; kwargs...) where {P<:AbstractPFT, T<:Real, U<:Int}
    defaults = BASE_DEFAULTS[P]
    merged   = merge(defaults, kwargs)
    return PFTCharacteristics{T,U}(; merged...)
end


@kwdef mutable struct TropicalPFT{T<:Real,U<:Int} <: AbstractTropicalPFT
    characteristics :: PFTCharacteristics{T,U}
end

TropicalPFT{T,U}() where {T<:Real,U<:Int} =
    TropicalPFT{T,U}(base_pft(AbstractTropicalPFT, T, U))
TropicalPFT() = TropicalPFT{Float64,Int}()


@kwdef mutable struct TemperatePFT{T<:Real,U<:Int} <: AbstractTemperatePFT
    characteristics :: PFTCharacteristics{T,U}
end

TemperatePFT{T,U}() where {T<:Real,U<:Int} =
    TemperatePFT{T,U}(base_pft(AbstractTemperatePFT, T, U))
TemperatePFT() = TemperatePFT{Float64,Int}()


@kwdef mutable struct BorealPFT{T<:Real,U<:Int} <: AbstractBorealPFT
    characteristics :: PFTCharacteristics{T,U}
end

BorealPFT{T,U}() where {T<:Real,U<:Int} =
    BorealPFT{T,U}(base_pft(AbstractBorealPFT, T, U))
BorealPFT() = BorealPFT{Float64,Int}()


@kwdef mutable struct GrassPFT{T<:Real,U<:Int} <: AbstractGrassPFT
    characteristics :: PFTCharacteristics{T,U}
end

GrassPFT{T,U}() where {T<:Real,U<:Int} =
    GrassPFT{T,U}(base_pft(AbstractGrassPFT, T, U))
GrassPFT() = GrassPFT{Float64,Int}()

@kwdef mutable  struct TundraPFT{T<:Real,U<:Int} <: AbstractPFT
    characteristics :: PFTCharacteristics{T,U}
end

TundraPFT{T,U}() where {T<:Real,U<:Int} =
    TundraPFT{T,U}(base_pft(AbstractTundraPFT, T, U))
TundraPFT() = TundraPFT{Float64,Int}()

struct Default{T<:Real,U<:Int} <: AbstractPFT
    characteristics::PFTCharacteristics{T,U}
end

Default{T,U}() where {T<:Real,U<:Int} = Default{T,U}(PFTCharacteristics{T,U}())
Default() = Default{Float64,Int}()

struct None{T<:Real,U<:Int} <: AbstractPFT
    characteristics::PFTCharacteristics{T,U}
end

None{T,U}() where {T<:Real,U<:Int} = None{T,U}(PFTCharacteristics{T,U}())
None() = None{Float64,Int}()
  

# If you want to build your own instance of the PFT: 
# SpecificGrass = GrassPFT(Float32, Int; Emax=7.1, allocfact=1.3)
# GrassPFT{Float32,Int64}(PFTCharacteristics{Float32,Int64}(
#   name = "GrassBase",
#   phenological_type = 3,
#   max_min_canopy_conductance = 0.8,
#   Emax = 7.1,
#   …))

struct PFTClassification{T<:Real,U<:Int} <: AbstractPFTList
    pft_list::Vector{AbstractPFT}
end

function PFTClassification{T,U}() where {T<:Real,U<:Int}
    return PFTClassification{T,U}([
        TropicalPFT{T,U}(),
        TemperatePFT{T,U}(),
        BorealPFT{T,U}(),
        GrassPFT{T,U}(),
        TundraPFT{T,U}(),
        Default{T,U}(),
        None{T,U}()
    ])
end
PFTClassification() = PFTClassification{Float64,Int}()

"""
    get_characteristic(pft, prop)

Fetch a named characteristic field from a PFT’s characteristics.
"""
function get_characteristic(pft::AbstractPFT, prop::Symbol)
    if hasproperty(pft.characteristics, prop)
        return getproperty(pft.characteristics, prop)
    else
        throw(ArgumentError("`$(prop)` is not a PFTCharacteristics field"))
    end
end

# Environmental dominance as before:
"""
    dominance_environment(pft, variable, clt)

Calculate environmental dominance (0–1) given climate variable.
"""
function dominance_environment(pft::AbstractPFT, variable::Symbol, clt::Real)
    mv = get_characteristic(pft, :mean_val)[variable]
    sd = get_characteristic(pft, :sd_val)[variable]
    dist = Normal(mv, sd)
    return pdf(dist, clt) / pdf(dist, mv)
end