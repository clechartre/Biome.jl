using Distributions
using Parameters: @kwdef

abstract type AbstractTropicalPFT <: AbstractPFT end
abstract type AbstractTemperatePFT <: AbstractPFT end
abstract type AbstractBorealPFT <: AbstractPFT end
abstract type AbstractGrassPFT <: AbstractPFT end

@kwdef mutable struct PFTCharacteristics{T<:Real,U<:Int} <: AbstractPFTCharacteristics
    name::String = "Default"
    phenological_type::U = U(1)
    max_min_canopy_conductance::T = T(0.0)
    Emax::T = T(0.0)
    sw_drop::T = T(0.0)
    sw_appear::T = T(0.0)
    root_fraction_top_soil::T = T(0.0)
    leaf_longevity::T = T(0.0)
    GDD5_full_leaf_out::T = T(0.0)
    GDD0_full_leaf_out::T = T(0.0)
    sapwood_respiration::U = U(1)
    optratioa::T = T(0.0)
    kk::T = T(0.0)
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


# Base constructors ----------------------------------------------------
function base_tropical_pft(::Type{T}, ::Type{U}; kwargs...) where {T<:Real,U<:Int}
    defaults = (
        max_min_canopy_conductance = T(0.5),
        Emax = T(10.0),
        sw_drop = T(-99.9),
        sw_appear = T(-99.9),
        root_fraction_top_soil = T(0.69),
        GDD5_full_leaf_out = T(-99.9),
        GDD0_full_leaf_out = T(-99.9),
        sapwood_respiration = U(1),
        optratioa = T(0.95),
        kk = T(0.7),
        c4 = false,
        t0 = T(10.0),
        tcurve = T(1.0),
        respfact = T(0.8),
        allocfact = T(1.0),
        grass = false
    )
    merged = merge(defaults, kwargs)
    return PFTCharacteristics{T,U}(; name = "TropicalBase", merged...)
end

# Concrete PFT types with characteristics
struct TropicalBase{T<:Real,U<:Int} <: AbstractTropicalPFT
    characteristics::PFTCharacteristics{T,U}
    state::PFTState{T,U}
end

# Constructors
TropicalBase(::Type{T}=Float64, ::Type{U}=Int; kwargs...) where {T<:Real,U<:Int} =
    TropicalBase(base_tropical_pft(T, U; kwargs...), PFTState{T,U}())


function base_temperate_pft(::Type{T}, ::Type{U}; kwargs...) where {T<:Real,U<:Int}
    defaults = (
        sw_drop = T(-99.9),
        sw_appear = T(-99.9),
        root_fraction_top_soil = T(0.67),
        GDD5_full_leaf_out = T(-99.9),
        GDD0_full_leaf_out = T(-99.9),
        sapwood_respiration = U(1),
        optratioa = T(0.8),
        kk = T(0.6),
        c4 = false,
        tcurve = T(1.0),
        respfact = T(1.45),
        allocfact = T(1.2),
        grass = false
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
        sw_drop = T(-99.9),
        sw_appear = T(-99.9),
        root_fraction_top_soil = T(0.83),
        leaf_longevity = T(24.0),
        GDD5_full_leaf_out = T(-99.9),
        GDD0_full_leaf_out = T(-99.9),
        sapwood_respiration = U(1),
        optratioa = T(0.85),
        kk = T(0.45),
        c4 = false,
        threshold = T(0.33),
        t0 = T(0.0),
        tcurve = T(0.8),
        respfact = T(4.0),
        allocfact = T(1.2),
        grass = false
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
        sw_drop = T(0.2),
        sw_appear = T(0.3),
        GDD5_full_leaf_out = T(-99.9),
        GDD0_full_leaf_out = T(-99.9),
        sapwood_respiration = U(2),
        optratioa = T(0.65),
        kk = T(0.4),
        tcurve = T(1.0),
        allocfact = T(1.0),
        grass = true
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

function get_characteristic(pft::AbstractPFT, prop::Symbol)
    if hasproperty(pft.characteristics, prop)
        return getproperty(pft.characteristics, prop)
    else
        throw(ArgumentError("`$(prop)` is not a field of PFTCharacteristics"))
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

struct PFTClassification{T<:Real,U<:Int} <: AbstractPFTList
    pft_list::Vector{AbstractPFT}
end

function PFTClassification{T,U}() where {T<:Real,U<:Int}
    return PFTClassification{T,U}([
        TropicalBase{T,U}(),
        TemperateBase{T,U}(),
        BorealBase{T,U}(),
        GrassBase{T,U}(),
    ])
end
PFTClassification() = PFTClassification{Float64,Int}()

"""
    dominance_environment(pft, variable, clt)

Calculate the normalized environmental dominance value for a given climate trait.

Returns a value in [0,1], where 1 is at the species' optimal mean and values fall off according to its tolerance.
"""
function dominance_environment(pft::AbstractPFT, variable::Symbol, clt)
    mean_val = get_characteristic(pft, :mean_val)[variable]
    std_val  = get_characteristic(pft, :sd_val)[variable]
    dist     = Normal(mean_val, std_val)
    pdf_clt  = pdf(dist, clt)
    pdf_mean = pdf(dist, mean_val)
    return pdf_clt / pdf_mean
end
