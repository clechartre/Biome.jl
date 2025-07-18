using Distributions
using Parameters: @kwdef

# ————— Abstract hierarchy —————

abstract type AbstractTropicalPFT <: AbstractPFT end
abstract type AbstractTemperatePFT <: AbstractPFT end
abstract type AbstractBorealPFT    <: AbstractPFT end
abstract type AbstractTundraPFT  <: AbstractPFT end

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

# PFTCharacteristics() = PFTCharacteristics{Float64,Int}()

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
          tcm = [-Inf, +Inf], 
          min = [T(0.0), +Inf],
          gdd = [-Inf, +Inf],
          gdd0 = [-Inf, +Inf], 
          twm = [T(10.0), +Inf], 
          snow = [-Inf, +Inf],
          swb = [T(500.0), +Inf]
        ),
        mean_val = (
            clt  = T(50.0),
            prec = T(170.0),
            temp = T(26.0),
        ),
        sd_val = (
            clt  = T(5.0),
            prec = T(40.0),
            temp = T(5.0),
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
          tcm = [T(-15.0), +Inf],
          min = [-Inf, T(5.0)], 
          gdd = [T(900.0), +Inf],
          gdd0 = [-Inf, +Inf],
          twm = [-Inf, +Inf], 
          snow = [-Inf, +Inf],
          swb = [T(400.0), +Inf]
        ),        
        mean_val = (
            clt  = T(35.0),
            prec = T(70.0),
            temp = T(15.0),
        ),
        sd_val = (
            clt  = T(10.0),
            prec = T(40.0),
            temp = T(8.0),
        ),
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
        ),
        mean_val = (
            clt  = T(48.0),
            prec = T(60.0),
            temp = T(-2.0),
        ),
        sd_val = (
            clt  = T(15.0),
            prec = T(30.0),
            temp = T(5.0),
        )
    )
    return PFTCharacteristics{T,U}(; name="BorealBase", merge(defaults,kwargs)...)
end

function base_tundra_pft(::Type{T}, ::Type{U}; kwargs...) where {T<:Real,U<:Int}
    # draw defaults from TundraShrubs, ColdHerbaceous, LichenForb
    defaults = (
        phenological_type      = U(2),      # mix of herbaceous and shrubs
        max_min_canopy_conductance = T(0.8),
        Emax                   = T(1.0),    # low photosynthetic capacity
        sw_drop                = T(-99.9),
        sw_appear              = T(-99.9),
        root_fraction_top_soil = T(0.93),   # deep rooting
        leaf_longevity         = T(8.0),    # intermediate
        GDD5_full_leaf_out     = T(50.0),   # low growing degree days
        GDD0_full_leaf_out     = T(25.0),   # from ColdHerbaceous
        sapwood_respiration    = U(1),
        optratioa              = T(0.9),
        kk                     = T(0.5),
        c4                     = false,
        threshold              = T(0.33),
        t0                     = T(-7.0),  # cold tolerance
        tcurve                 = T(0.6),
        respfact               = T(4.0),   # high respiration
        allocfact              = T(1.0),
        grass                  = false,
        constraints = (
            tcm   = [-Inf, +Inf],
            min   = [-Inf, +Inf],
            gdd   = [-Inf, +Inf],
            gdd0  = [T(50.0), +Inf],
            twm   = [-Inf, T(15.0)],
            snow  = [T(15.0), +Inf],
            swb   = [T(300.0), +Inf]
        ),
        mean_val = (
            clt  = T(30.0),
            prec = T(40.0),
            temp = T(-5.0),
        ),
        sd_val = (
            clt  = T(10.0),
            prec = T(20.0),
            temp = T(5.0),
        )
    )
    return PFTCharacteristics{T,U}(; name="TundraBase", merge(defaults, kwargs)...)
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

"""
    add_grass!(c::PFTCharacteristics)

Convert a base PFT into a (generic) grass form:
- sets grass phenology and physiology
- adds typical soil‐water stress thresholds
- marks `grass = true`
- injects a soil‐water‐balance constraint
"""
function add_grass!(characteristics::PFTCharacteristics{T,U}) where {T<:Real,U<:Int}
    characteristics.phenological_type           = U(3)
    characteristics.max_min_canopy_conductance = T(0.8)
    characteristics.Emax                       = T(6.5)
    characteristics.sw_drop                    = T(0.20)
    characteristics.sw_appear                  = T(0.30)
    characteristics.leaf_longevity             = T(8.0)
    characteristics.sapwood_respiration        = U(2)
    characteristics.optratioa                  = T(0.65)
    characteristics.kk                         = T(0.4)
    characteristics.threshold                  = T(0.40)
    characteristics.allocfact                  = T(1.0)
    characteristics.grass                      = true
    characteristics.constraints = (
        tcm   = characteristics.constraints.tcm,
        min   = characteristics.constraints.min,
        gdd   = characteristics.constraints.gdd,
        gdd0  = characteristics.constraints.gdd0,
        twm   = characteristics.constraints.twm,
        snow  = characteristics.constraints.snow,
        swb   = [T(200.0), +Inf],
    )
    characteristics.mean_val = (
        clt  = T(10.0),
        prec = T(10.0),
        temp = characteristics.mean_val.temp,
    )

    return characteristics
end


"""
    add_woody!(c::PFTCharacteristics)

Convert a base PFT into a (generic) woody form:
- enables sapwood respiration
- boosts allocation to support wood
- turns off `grass`
"""
function add_woody!(characteristics::PFTCharacteristics{T,U}) where {T<:Real,U<:Int}
    characteristics.sapwood_respiration = U(1) # enable sapwood respiration
    characteristics.respfact = T(4.0)     # woody tissues incur extra respiratory cost
    characteristics.allocfact = T(1.2)     # allocate extra carbon to structural wood
    characteristics.grass = false # definitely not a grass
    return characteristics
end

"""
    add_forb!(c::PFTCharacteristics)

Convert a base PFT into a (generic) forb/herbaceous form:
- sets phenology to herbaceous (type 2)
- moderate leaf longevity
- moderate optimal‐ratio and light‐use efficiency
- higher allocation to reproduction/quick turnover
- ensures `grass` is false
"""
function add_forb!(characteristics::PFTCharacteristics{T,U}) where {T<:Real,U<:Int}
    characteristics.phenological_type = U(2)        # herbaceous phenology
    characteristics.leaf_longevity    = T(8.0)      # short‐to‐medium leaf lifespan
    characteristics.optratioa        = T(0.8)       # typical light optimum
    characteristics.kk               = T(0.6)       # moderate curvature of light‐response
    characteristics.allocfact        = T(1.5)    # more allocation to rapid turnover tissues
    characteristics.grass            = false
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

  @kwdef mutable struct TundraPFT{T<:Real,U<:Int} <: AbstractTundraPFT
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
  
# Tundra
function (::Type{TundraPFT{T,U}})(name::String, mixins::Function...) where {T<:Real,U<:Int}
    char = base_tundra_pft(T, U)
    for mix in mixins
        mix(char)
    end
    char.name = name
    return TundraPFT{T,U}(char)
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
