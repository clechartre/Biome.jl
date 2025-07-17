using Distributions
using Parameters: @kwdef

abstract type AbstractTropicalPFT <: AbstractPFT end
abstract type AbstractTemperatePFT <: AbstractPFT end
abstract type AbstractBorealPFT <: AbstractPFT end
abstract type AbstractGrassPFT <: AbstractPFT end
abstract type AbstractDeciduousPFT <: AbstractPFT end
abstract type AbstractEvergreenPFT <: AbstractPFT end

@kwdef mutable struct PFTCharacteristics{T<:Real,U<:Int} <: AbstractPFTCharacteristics
    name::String = "Default"
    phenological_type::U = U(1)
    max_min_canopy_conductance::T = T(0.0)
    Emax::T = T(10.0)
    sw_drop::T = T(-99.9)
    sw_appear::T = T(-99.9)
    root_fraction_top_soil::T = T(0.0)
    leaf_longevity::T = T(0.0)
    GDD5_full_leaf_out::T = T(-99.9)
    GDD0_full_leaf_out::T = T(-99.9)
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

    constraints::NamedTuple{
        (:tcm, :min, :gdd, :gdd0, :twm, :snow, :swb),
        NTuple{7,Vector{T}}
    } = (; 
        tcm   = [-Inf, +Inf],
        min   = [-Inf, +Inf],
        gdd   = [-Inf, +Inf],
        gdd0  = [-Inf, +Inf],
        twm   = [-Inf, +Inf],
        snow  = [-Inf, +Inf],
        swb   = [-Inf, +Inf]
    )

    mean_val::NamedTuple{
        (:clt, :prec, :temp),
        NTuple{3,T}
    } = (; 
        clt   = T(30.6),
        prec  = T(72.0),
        temp  = T(24.5)
    )

    sd_val::NamedTuple{
        (:clt, :prec, :temp),
        NTuple{3,T}
    } = (; 
        clt   = T(9.7),
        prec  = T(39.0),
        temp  = T(3.2)
    )
end

PFTCharacteristics() = PFTCharacteristics{Float64,Int}()

@kwdef mutable struct PFTState{T<:Real,U<:Int}
    present::Bool = false
    dominance::T = zero(T)
    greendays::U = zero(U)
    firedays::T = zero(T)
    mwet::Vector{T} = zeros(T, 12)
    npp::T = zero(T)
    lai::T = zero(T)
end

# Base constructors with minimal required plus constraints ----------------
function base_tropical_pft(::Type{T}, ::Type{U}; kwargs...) where {T<:Real,U<:Int}
    defaults = (
        max_min_canopy_conductance = T(0.5),
        Emax = T(10.0),
        root_fraction_top_soil = T(0.69),
        optratioa = T(0.95),
        kk = T(0.7),
        t0 = T(10.0),
        tcurve = T(1.0),
        respfact = T(0.8),
        allocfact = T(1.0),
        constraints = (
            tcm = [-Inf, +Inf],
            min = [T(0.0), +Inf],
            gdd = [-Inf, +Inf],
            gdd0 = [-Inf, +Inf],
            twm = [T(10.0), +Inf],
            snow = [-Inf, +Inf],
            swb = [T(500.0), +Inf]
        )
    )
    merged = merge(defaults, kwargs)
    return PFTCharacteristics{T,U}(; name = "TropicalBase", merged...)
end

struct TropicalBase{T<:Real,U<:Int} <: AbstractTropicalPFT
    characteristics::PFTCharacteristics{T,U}
    state::PFTState{T,U}
end

TropicalBase(::Type{T}=Float64, ::Type{U}=Int; kwargs...) where {T<:Real,U<:Int} =
    TropicalBase(base_tropical_pft(T, U; kwargs...), PFTState{T,U}())

function base_temperate_pft(::Type{T}, ::Type{U}; kwargs...) where {T<:Real,U<:Int}
    defaults = (
        Emax = T(5.0),
        root_fraction_top_soil = T(0.67),
        GDD5_full_leaf_out = T(200.0),
        optratioa = T(0.80),
        kk = T(0.65),
        t0 = T(5.0),
        tcurve = T(1.0),
        respfact = T(1.45),
        allocfact = T(1.2),
        constraints = (
            tcm   = [T(-15.0), +Inf],
            min   = [T(-Inf), T(5.0)],
            gdd   = [T(900.0), +Inf],
            gdd0  = [T(-Inf), +Inf],
            twm   = [T(-Inf), +Inf],
            snow  = [T(-Inf), +Inf],
            swb   = [T(420.0), +Inf]
        )
    )
    merged = merge(defaults, kwargs)
    return PFTCharacteristics{T,U}(; name = "TemperateBase", merged...)
end

struct TemperateBase{T<:Real,U<:Int} <: AbstractTemperatePFT
    characteristics::PFTCharacteristics{T,U}
    state::PFTState{T,U}
end

TemperateBase(::Type{T}=Float64, ::Type{U}=Int; kwargs...) where {T<:Real,U<:Int} =
    TemperateBase(base_temperate_pft(T, U; kwargs...), PFTState{T,U}())

function base_boreal_pft(::Type{T}, ::Type{U}; kwargs...) where {T<:Real,U<:Int}
    defaults = (
        Emax = T(4.5),
        root_fraction_top_soil = T(0.83),
        leaf_longevity = T(24.0),
        optratioa = T(0.90),
        kk = T(0.40),
        threshold = T(0.33),
        t0 = T(0.0),
        tcurve = T(0.8),
        respfact = T(4.0),
        allocfact = T(1.2),
        constraints = (
            tcm   = [T(-Inf), T(5.0)],
            min   = [T(-Inf), +Inf],
            gdd   = [T(-Inf), +Inf],
            gdd0  = [T(-Inf), +Inf],
            twm   = [T(-Inf), T(21.0)],
            snow  = [T(-Inf), +Inf],
            swb   = [T(300.0), +Inf]
        )
    )
    merged = merge(defaults, kwargs)
    return PFTCharacteristics{T,U}(; name = "BorealBase", merged...)
end

struct BorealBase{T<:Real,U<:Int} <: AbstractBorealPFT
    characteristics::PFTCharacteristics{T,U}
    state::PFTState{T,U}
end

BorealBase(::Type{T}=Float64, ::Type{U}=Int; kwargs...) where {T<:Real,U<:Int} =
    BorealBase(base_boreal_pft(T, U; kwargs...), PFTState{T,U}())

function base_grass_pft(::Type{T}, ::Type{U}; kwargs...) where {T<:Real,U<:Int}
    defaults = (
        phenological_type = U(3),
        max_min_canopy_conductance = T(0.8),
        Emax = T(6.5),
        sw_drop = T(0.20),
        sw_appear = T(0.30),
        leaf_longevity = T(8.0),
        sapwood_respiration = U(2),
        optratioa = T(0.65),
        kk = T(0.4),
        tcurve = T(1.0),
        threshold = T(0.40),
        allocfact = T(1.0),
        grass = true,
        constraints = (
            tcm   = [T(-Inf), +Inf],
            min   = [T(-Inf), +Inf],
            gdd   = [T(-Inf), +Inf],
            gdd0  = [T(-Inf), +Inf],
            twm   = [T(-Inf), +Inf],
            snow  = [T(-Inf), +Inf],
            swb   = [T(100.0), +Inf]
        )
    )
    merged = merge(defaults, kwargs)
    return PFTCharacteristics{T,U}(; name = "GrassBase", merged...)
end

struct GrassBase{T<:Real,U<:Int} <: AbstractGrassPFT
    characteristics::PFTCharacteristics{T,U}
    state::PFTState{T,U}
end

GrassBase(::Type{T}=Float64, ::Type{U}=Int; kwargs...) where {T<:Real,U<:Int} =
    GrassBase(base_grass_pft(T, U; kwargs...), PFTState{T,U}())

function base_deciduous_pft(::Type{T}, ::Type{U}; kwargs...) where {T<:Real,U<:Int}
    defaults = (
        phenological_type = U(2),
        leaf_longevity = T(7.0),
        GDD5_full_leaf_out = T(200.0),
        kk = T(0.65)
    )
    merged = merge(defaults, kwargs)
    return PFTCharacteristics{T,U}(; name = "DeciduousBase", merged...)
end

struct DeciduousBase{T<:Real,U<:Int} <: AbstractDeciduousPFT
    characteristics::PFTCharacteristics{T,U}
    state::PFTState{T,U}
end

DeciduousBase(::Type{T}=Float64, ::Type{U}=Int; kwargs...) where {T<:Real,U<:Int} =
    DeciduousBase(base_deciduous_pft(T, U; kwargs...), PFTState{T,U}())

function base_evergreen_pft(::Type{T}, ::Type{U}; kwargs...) where {T<:Real,U<:Int}
    defaults = (
        phenological_type = U(1),
        leaf_longevity = T(18.0),
        kk = T(0.67)
    )
    merged = merge(defaults, kwargs)
    return PFTCharacteristics{T,U}(; name = "EvergreenBase", merged...)
end

struct EvergreenBase{T<:Real,U<:Int} <: AbstractEvergreenPFT
    characteristics::PFTCharacteristics{T,U}
    state::PFTState{T,U}
end

EvergreenBase(::Type{T}=Float64, ::Type{U}=Int; kwargs...) where {T<:Real,U<:Int} =
    EvergreenBase(base_evergreen_pft(T, U; kwargs...), PFTState{T,U}())

# Utility and classification ----------------------------------------------

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

"""
    PFTClassification()

Return a list of all base PFT instances.
"""
struct PFTClassification{T<:Real,U<:Int} <: AbstractPFTList
    pft_list::Vector{AbstractPFT}
end

function PFTClassification{T,U}() where {T<:Real,U<:Int}
    return PFTClassification{T,U}([
        TropicalBase{T,U}(),
        TemperateBase{T,U}(),
        BorealBase{T,U}(),
        GrassBase{T,U}(),
        DeciduousBase{T,U}(),
        EvergreenBase{T,U}(),
    ])
end
PFTClassification() = PFTClassification{Float64,Int}()

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
