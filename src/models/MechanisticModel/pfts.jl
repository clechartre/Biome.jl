using Distributions
using Parameters: @kwdef

# ————— Abstract hierarchy —————

abstract type AbstractTropicalPFT <: AbstractPFT end
abstract type AbstractTemperatePFT <: AbstractPFT end
abstract type AbstractBorealPFT    <: AbstractPFT end
abstract type AbstractGrassPFT     <: AbstractPFT end
struct PFTClassification{T<:Real,U<:Int} <: AbstractPFTList
    pft_list::Vector{AbstractPFT}
end

# ————— Characteristics & State —————

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
    dominance::T = zero(T)
    greendays::U = zero(U)
    firedays::T = zero(T)
    mwet::Vector{T} = zeros(T,12)
    npp::T = zero(T)
    lai::T = zero(T)
end

# ————— Base‐factory functions —————

function base_tropical_pft(::Type{T}, ::Type{U}; kwargs...) where {T<:Real,U<:Int}
    defaults = (
        max_min_canopy_conductance = T(0.5),
        Emax                       = T(10.0),
        root_fraction_top_soil     = T(0.69),
        optratioa                  = T(0.95),
        kk                         = T(0.7),
        t0                         = T(10.0),
        tcurve                     = T(1.0),
        respfact                   = T(0.8),
        allocfact                  = T(1.0),
        constraints = (
          tcm=[-Inf,+Inf], 
          min=[T(0.0),+Inf],
          gdd=[-Inf,+Inf],
          gdd0=[-Inf,+Inf], 
          twm=[T(10.0),+Inf], 
          snow=[-Inf,+Inf],
          swb=[T(500.0),+Inf]
        )
    )
    return PFTCharacteristics{T,U}(; name="TropicalBase", merge(defaults,kwargs)...)
end

function base_temperate_pft(::Type{T}, ::Type{U}; kwargs...) where {T<:Real,U<:Int}
    defaults = (
        phenological_type       = U(2),
        Emax                    = T(5.0),
        root_fraction_top_soil  = T(0.67),
        GDD5_full_leaf_out      = T(200.0),
        optratioa               = T(0.8),
        kk                      = T(0.65),
        t0                      = T(5.0),
        tcurve                  = T(1.0),
        respfact                = T(1.45),
        allocfact               = T(1.2),
        constraints = (
          tcm=[T(-15.0),+Inf],
          min=[-Inf,T(5.0)], 
          gdd=[T(900.0),+Inf],
          gdd0=[-Inf,+Inf],
          twm=[-Inf,+Inf], 
          snow=[-Inf,+Inf],
          swb=[T(300.0),+Inf]
        )
    )
    return PFTCharacteristics{T,U}(; name="TemperateBase", merge(defaults,kwargs)...)
end

function base_boreal_pft(::Type{T}, ::Type{U}; kwargs...) where {T<:Real,U<:Int}
    defaults = (
        Emax                    = T(4.5),
        root_fraction_top_soil  = T(0.83),
        leaf_longevity          = T(24.0),
        optratioa               = T(0.90),
        kk                      = T(0.40),
        threshold               = T(0.33),
        t0                      = T(0.0),
        tcurve                  = T(0.8),
        respfact                = T(4.0),
        allocfact               = T(1.2),
        constraints = (
          tcm=[-Inf,T(5.0)], 
          min=[-Inf,+Inf],
          gdd=[-Inf,+Inf], 
          gdd0=[-Inf,+Inf], 
          twm=[-Inf,T(21.0)],
          snow=[-Inf,+Inf], 
          swb = [T(300.0),+Inf]
        )
    )
    return PFTCharacteristics{T,U}(; name="BorealBase", merge(defaults,kwargs)...)
end

function base_grass_pft(::Type{T}, ::Type{U}; kwargs...) where {T<:Real,U<:Int}
    defaults = (
        phenological_type           = U(3),
        max_min_canopy_conductance  = T(0.8),
        Emax                        = T(6.5),
        sw_drop                     = T(0.20),
        sw_appear                   = T(0.30),
        leaf_longevity              = T(8.0),
        sapwood_respiration         = U(2),
        optratioa                   = T(0.65),
        kk                          = T(0.4),
        tcurve                      = T(1.0),
        threshold                   = T(0.40),
        allocfact                   = T(1.0),
        grass                       = true,
        constraints = (
          tcm=[-Inf,+Inf], 
          min=[-Inf,+Inf],
          gdd=[-Inf,+Inf], 
          gdd0=[-Inf,+Inf], 
          twm=[-Inf,+Inf], 
          snow=[-Inf,+Inf],
          swb=[T(100.0),+Inf]
        )
    )
    return PFTCharacteristics{T,U}(; name="GrassBase", merge(defaults,kwargs)...)
end

# ————— Mixins —————

function add_deciduous!(characteristics::PFTCharacteristics{T,U}) where {T<:Real,U<:Int}
    characteristics.phenological_type = U(2)
    characteristics.leaf_longevity    = T(7.0)
    characteristics.GDD5_full_leaf_out= T(200.0)
    characteristics.kk                = T(0.65)
    return characteristics
end

function add_evergreen!(characteristics::PFTCharacteristics{T,U}) where {T<:Real,U<:Int}
    characteristics.phenological_type = U(1)
    characteristics.leaf_longevity    = T(12.0)
    characteristics.kk                = T(0.67)
    return characteristics
end

function add_broadleaf!(characteristics::PFTCharacteristics{T,U}) where {T<:Real,U<:Int}
    characteristics.leaf_longevity        = T(12.0)
    characteristics.kk                    = T(0.6)
    characteristics.Emax                  = characteristics.Emax==zero(T) ? T(8.0) : characteristics.Emax*T(1.2)
    characteristics.root_fraction_top_soil= T(0.7)
    return characteristics
end

function add_needleleaf!(characteristics::PFTCharacteristics{T,U}) where {T<:Real,U<:Int}
    characteristics.leaf_longevity        = T(24.0)
    characteristics.kk                    = T(0.4)
    characteristics.Emax                  = characteristics.Emax==zero(T) ? T(4.0) : characteristics.Emax*T(0.8)
    characteristics.root_fraction_top_soil= T(0.6)
    return characteristics
end

# ————— Concrete subtypes + mixin‐powered constructors —————

# ————— Concrete subtypes —————

@kwdef mutable struct TropicalPFT{T<:Real,U<:Int} <: AbstractTropicalPFT
    characteristics::PFTCharacteristics{T,U}
  end
  
  @kwdef mutable struct TemperatePFT{T<:Real,U<:Int} <: AbstractTemperatePFT
    characteristics::PFTCharacteristics{T,U}
  end
  
  @kwdef mutable struct BorealPFT{T<:Real,U<:Int} <: AbstractBorealPFT
    characteristics::PFTCharacteristics{T,U}
  end
  
  @kwdef mutable struct GrassPFT{T<:Real,U<:Int}    <: AbstractGrassPFT
    characteristics::PFTCharacteristics{T,U}
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
  
  # ————— Type‐call constructors with mixins —————
  
  # Tropical
  function (::Type{TropicalPFT{T,U}})(name::String, mixins::Function...) where {T<:Real,U<:Int}
    characteristics = base_tropical_pft(T, U)
    for mix in mixins
      mix(characteristics)
    end
    characteristics.name = name
    return TropicalPFT{T,U}(characteristics)
  end
  
  # Temperate
  function (::Type{TemperatePFT{T,U}})(name::String, mixins::Function...) where {T<:Real,U<:Int}
    characteristics = base_temperate_pft(T, U)
    for mix in mixins
      mix(characteristics)
    end
    characteristics.name = name
    return TemperatePFT{T,U}(characteristics)
  end
  
  # Boreal
  function (::Type{BorealPFT{T,U}})(name::String, mixins::Function...) where {T<:Real,U<:Int}
    characteristics = base_boreal_pft(T, U)
    for mix in mixins
      mix(characteristics)
    end
    characteristics.name = name
    return BorealPFT{T,U}(characteristics)
  end
  
  # Grass
  function (::Type{GrassPFT{T,U}})(name::String, mixins::Function...) where {T<:Real,U<:Int}
    characteristics = base_grass_pft(T, U)
    for mix in mixins
      mix(characteristics)
    end
    characteristics.name = name
    return GrassPFT{T,U}(characteristics)
  end

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

# ————— Usage examples —————

# trop = TropicalPFT{Float64,Int}("RainTree", add_deciduous!, add_broadleaf!)
# temp = TemperatePFT{Float64,Int}("Oak",   add_deciduous!, add_broadleaf!)
# bore = BorealPFT{Float64,Int}("Pine",  add_evergreen!, add_needleleaf!)
# gras = GrassPFT{Float64,Int}("PrairieGrass",)
