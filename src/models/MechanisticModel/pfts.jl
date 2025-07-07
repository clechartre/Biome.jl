using Distributions
using Parameters: @kwdef

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
    sapwood_respiration::U = U(0)
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
        (:tcm, :min, :gdd, :gdd0, :twm, :snow),
        NTuple{6,Vector{Float64}}
    } = (tcm=Float64[-Inf, +Inf], min=Float64[-Inf, +Inf], gdd=Float64[-Inf, +Inf], gdd0=Float64[-Inf, +Inf], twm=Float64[-Inf, +Inf], snow=Float64[-Inf, +Inf])
end

@kwdef mutable struct PFTState{T<:Real,U<:Int}
    present   :: Bool         = false           # is this PFT active this timestep?
    dominance :: T            = zero(T)         # computed environmental dominance
    greendays :: U            = zero(U)         # how many days with green leaves?
    firedays  :: T            = zero(T)         # cumulative days since last fire
    mwet      :: Vector{T}    = zeros(T, 12)    # monthly wetness index (12 months)
    npp       :: T            = zero(T)         # net primary productivity
    lai       :: T            = zero(T)         # leaf area index
end


# Define the PFT structures
struct WoodyDesert <: AbstractPFT
    characteristics::PFTCharacteristics
end

WoodyDesert() = WoodyDesert(PFTCharacteristics{Float64, Int}(
    name="C3C4WoodyDesert",
    phenological_type=1,
    max_min_canopy_conductance=0.1,
    Emax=1.0,
    sw_drop=-99.9,
    sw_appear=-99.9,
    root_fraction_top_soil=0.53,
    leaf_longevity=12.0,
    GDD5_full_leaf_out=-99.9,
    GDD0_full_leaf_out=-99.9,
    sapwood_respiration=1,
    optratioa=0.70,
    kk=0.3,
    c4=true,
    threshold=0.33,
    t0=5.0,
    tcurve=1.0,
    respfact=1.4,
    allocfact=1.0,
    grass=false,
    constraints=(
        tcm=[-Inf, +Inf],
        min=[-45.0, +Inf],
        gdd=[500.0, +Inf],
        gdd0=[-Inf, +Inf],
        twm=[10.0, +Inf],
        snow=[-Inf, +Inf]
    )
))

struct TropicalEvergreen <: AbstractPFT
    characteristics::PFTCharacteristics
end

TropicalEvergreen() = TropicalEvergreen(PFTCharacteristics{Float64, Int}(
    name="TropicalEvergreen",
    phenological_type=1,
    max_min_canopy_conductance=0.5,
    Emax=10.0,
    sw_drop=-99.9,
    sw_appear=-99.9,
    root_fraction_top_soil=0.69,
    leaf_longevity=18.0,
    GDD5_full_leaf_out=-99.9,
    GDD0_full_leaf_out=-99.9,
    sapwood_respiration=1,
    optratioa=0.95,
    kk=0.7,
    c4=false,
    threshold=0.25,
    t0=10.0,
    tcurve=1.0,
    respfact=0.8,
    allocfact=1.0,
    grass=false,
    constraints=(
        tcm=[-Inf, +Inf],
        min=[0.0, +Inf],
        gdd=[-Inf, +Inf],
        gdd0=[-Inf, +Inf],
        twm=[10.0, +Inf],
        snow=[-Inf, +Inf]
    )
))

struct TropicalDroughtDeciduous <: AbstractPFT
    characteristics::PFTCharacteristics
end

TropicalDroughtDeciduous() = TropicalDroughtDeciduous(
    PFTCharacteristics{Float64, Int64}(
        name="TropicalDroughtDeciduous",
        phenological_type=3,
        max_min_canopy_conductance=0.5,
        Emax=10.0,
        sw_drop=0.5,
        sw_appear=0.6,
        root_fraction_top_soil=0.7,
        leaf_longevity=9.0,
        GDD5_full_leaf_out=-99.9,
        GDD0_full_leaf_out=-99.9,
        sapwood_respiration=1,
        optratioa=0.9,
        kk=0.7,
        c4=false,
        threshold=0.20,
        t0=10.0,
        tcurve=1.0,
        respfact=0.8,
        allocfact=1.0,
        grass=false,
        constraints=(
            tcm=[-Inf, +Inf],
            min=[0.0, +Inf],
            gdd=[-Inf, +Inf],
            gdd0=[-Inf, +Inf],
            twm=[10.0, +Inf],
            snow=[-Inf, +Inf]
        )
    )
)

struct TemperateBroadleavedEvergreen <: AbstractPFT
    characteristics::PFTCharacteristics
end

TemperateBroadleavedEvergreen() = TemperateBroadleavedEvergreen(
    PFTCharacteristics{Float64, Int64}(
        name="TemperateBroadleavedEvergreen",
        phenological_type=1,
        max_min_canopy_conductance=0.2,
        Emax=4.8,
        sw_drop=-99.9,
        sw_appear=-99.9,
        root_fraction_top_soil=0.67,
        leaf_longevity=18.0,
        GDD5_full_leaf_out=-99.9,
        GDD0_full_leaf_out=-99.9,
        sapwood_respiration=1,
        optratioa=0.8,
        kk=0.6,
        c4=false,
        threshold=0.40,
        t0=5.0,
        tcurve=1.0,
        respfact=1.4,
        allocfact=1.2,
        grass=false,
        constraints=(
            tcm=[-Inf, +Inf],
            min=[-8.0, 5.0],
            gdd=[1200, +Inf],
            gdd0=[-Inf, +Inf],
            twm=[10.0, +Inf],
            snow=[-Inf, +Inf]
        )
    )
)

struct TemperateDeciduous <: AbstractPFT
    characteristics::PFTCharacteristics
end

TemperateDeciduous() = TemperateDeciduous(PFTCharacteristics{Float64, Int64}(
    name="TemperateDeciduous",
    phenological_type=2,
    max_min_canopy_conductance=0.8,
    Emax=10.0,
    sw_drop=-99.9,
    sw_appear=-99.9,
    root_fraction_top_soil=0.65,
    leaf_longevity=7.0,
    GDD5_full_leaf_out=200.0,
    GDD0_full_leaf_out=-99.9,
    sapwood_respiration=1,
    optratioa=0.8,
    kk=0.6,
    c4=false,
    threshold=0.33,
    t0=4.0,
    tcurve=1.0,
    respfact=1.6,
    allocfact=1.2,
    grass=false,
    constraints=(
        tcm=[-15.0, +Inf],
        min=[-Inf, -8.0],
        gdd=[1200, +Inf],
        gdd0=[-Inf, +Inf],
        twm=[-Inf, +Inf],
        snow=[-Inf, +Inf]
    )
))

struct CoolConifer <: AbstractPFT
    characteristics::PFTCharacteristics
end

CoolConifer() = CoolConifer(PFTCharacteristics{Float64, Int}(
    name="CoolConifer",
    phenological_type=1,
    max_min_canopy_conductance=0.2,
    Emax=4.8,
    sw_drop=-99.9,
    sw_appear=-99.9,
    root_fraction_top_soil=0.52,
    leaf_longevity=30.0,
    GDD5_full_leaf_out=-99.9,
    GDD0_full_leaf_out=-99.9,
    sapwood_respiration=1,
    optratioa=0.9,
    kk=0.5,
    c4=false,
    threshold=0.40,
    t0=3.0,
    tcurve=0.9,
    respfact=0.8,
    allocfact=1.2,
    grass=false,
    constraints=(
        tcm=[-2.0, +Inf],
        min=[-Inf, 10.0],
        gdd=[900, +Inf],
        gdd0=[-Inf, +Inf],
        twm=[10.0, +Inf],
        snow=[-Inf, +Inf]
    )
))

struct BorealEvergreen <: AbstractPFT
    characteristics::PFTCharacteristics
end

BorealEvergreen() = BorealEvergreen(PFTCharacteristics{Float64, Int}(
    name="BorealEvergreen",
    phenological_type=1,
    max_min_canopy_conductance=0.5,
    Emax=4.5,
    sw_drop=-99.9,
    sw_appear=-99.9,
    root_fraction_top_soil=0.83,
    leaf_longevity=24.0,
    GDD5_full_leaf_out=-99.9,
    GDD0_full_leaf_out=-99.9,
    sapwood_respiration=1,
    optratioa=0.8,
    kk=0.5,
    c4=false,
    threshold=0.33,
    t0=0.0,
    tcurve=0.8,
    respfact=4.0,
    allocfact=1.2,
    grass=false,
    constraints=(
        tcm=[-32.5, -2.0],
        min=[-Inf, +Inf],
        gdd=[-Inf, +Inf],
        gdd0=[-Inf, +Inf],
        twm=[-Inf, 21.0],
        snow=[-Inf, +Inf]
    )
))

struct BorealDeciduous <: AbstractPFT
    characteristics::PFTCharacteristics
end

BorealDeciduous() = BorealDeciduous(PFTCharacteristics{Float64, Int}(
    name="BorealDeciduous",
    phenological_type=2,
    max_min_canopy_conductance=0.8,
    Emax=10.0,
    sw_drop=-99.9,
    sw_appear=-99.9,
    root_fraction_top_soil=0.83,
    leaf_longevity=24.0,
    GDD5_full_leaf_out=200.0,
    GDD0_full_leaf_out=-99.9,
    sapwood_respiration=1,
    optratioa=0.9,
    kk=0.4,
    c4=false,
    threshold=0.33,
    t0=0.0,
    tcurve=0.8,
    respfact=4.0,
    allocfact=1.2,
    grass=false,
    constraints=(
        tcm=[-Inf, 5.0],
        min=[-Inf, -10.0],
        gdd=[-Inf, +Inf],
        gdd0=[-Inf, +Inf],
        twm=[-Inf, 21.0],
        snow=[-Inf, +Inf]
    )
))

struct LichenForb <: AbstractPFT
    characteristics::PFTCharacteristics
end

LichenForb() = LichenForb(PFTCharacteristics{Float64, Int}(
    name="LichenForb",
    phenological_type=1,
    max_min_canopy_conductance=0.8,
    Emax=1.0,
    sw_drop=-99.9,
    sw_appear=-99.9,
    root_fraction_top_soil=0.93,
    leaf_longevity=8.0,
    GDD5_full_leaf_out=-99.9,
    GDD0_full_leaf_out=-99.9,
    sapwood_respiration=1,
    optratioa=0.80,
    kk=0.6,
    c4=false,
    threshold=0.33,
    t0=-12.0,
    tcurve=0.5,
    respfact=4.0,
    allocfact=1.5,
    grass=false,
    constraints=(
        tcm=[-Inf, +Inf],
        min=[-Inf, +Inf],
        gdd=[-Inf, +Inf],
        gdd0=[-Inf, +Inf],
        twm=[-Inf, 15.0],
        snow=[-Inf, +Inf]
    )
))

struct TundraShrubs <: AbstractPFT
    characteristics::PFTCharacteristics
end

TundraShrubs() = TundraShrubs(PFTCharacteristics{Float64, Int}(
    name="TundraShrubs",
    phenological_type=1,
    max_min_canopy_conductance=0.8,
    Emax=1.0,
    sw_drop=-99.9,
    sw_appear=-99.9,
    root_fraction_top_soil=0.93,
    leaf_longevity=8.0,
    GDD5_full_leaf_out=-99.9,
    GDD0_full_leaf_out=-99.9,
    sapwood_respiration=1,
    optratioa=0.90,
    kk=0.5,
    c4=false,
    threshold=0.33,
    t0=-7.0,
    tcurve=0.6,
    respfact=4.0,
    allocfact=1.0,
    grass=true,
    constraints=(
        tcm=[-Inf, +Inf],
        min=[-Inf, +Inf],
        gdd=[-Inf, +Inf],
        gdd0=[50.0, +Inf],
        twm=[-Inf, 15.0],
        snow=[15.0, +Inf]
    )
))

struct C3C4TemperateGrass <: AbstractPFT
    characteristics::PFTCharacteristics
end

C3C4TemperateGrass() = C3C4TemperateGrass(PFTCharacteristics{Float64, Int}(
    name="C3C4TemperateGrass",
    phenological_type=3,
    max_min_canopy_conductance=0.8,
    Emax=6.5,
    sw_drop=0.2,
    sw_appear=0.3,
    root_fraction_top_soil=0.83,
    leaf_longevity=8.0,
    GDD5_full_leaf_out=-99.9,
    GDD0_full_leaf_out=100.0,
    sapwood_respiration=2,
    optratioa=0.65,
    kk=0.4,
    c4=false,
    threshold=0.40,
    t0=4.5,
    tcurve=1.0,
    respfact=1.6,
    allocfact=1.0,
    grass=true,
    constraints=(
        tcm=[-Inf, +Inf],
        min=[-Inf, 0.0],
        gdd=[550.0, +Inf],
        gdd0=[-Inf, +Inf],
        twm=[-Inf, +Inf],
        snow=[-Inf, +Inf]
    )
))

struct C4TropicalGrass <: AbstractPFT
    characteristics::PFTCharacteristics
end

C4TropicalGrass() = C4TropicalGrass(PFTCharacteristics{Float64, Int}(
    name="C4TropicalGrass",
    phenological_type=3,
    max_min_canopy_conductance=0.8,
    Emax=8.0,
    sw_drop=0.2,
    sw_appear=0.3,
    root_fraction_top_soil=0.57,
    leaf_longevity=10.0,
    GDD5_full_leaf_out=-99.9,
    GDD0_full_leaf_out=-99.9,
    sapwood_respiration=2,
    optratioa=0.65,
    kk=0.4,
    c4=true,
    threshold=0.40,
    t0=10.0,
    tcurve=1.0,
    respfact=0.8,
    allocfact=1.0,
    grass=true,
    constraints=(
        tcm=[-Inf, +Inf],
        min=[-3.0, +Inf],
        gdd=[-Inf, +Inf],
        gdd0=[-Inf, +Inf],
        twm=[10.0, +Inf],
        snow=[-Inf, +Inf]
    )
))

struct ColdHerbaceous <: AbstractPFT
    characteristics::PFTCharacteristics
end

ColdHerbaceous() = ColdHerbaceous(PFTCharacteristics{Float64, Int}(
    name="ColdHerbaceous",
    phenological_type=2,
    max_min_canopy_conductance=0.8,
    Emax=1.0,
    sw_drop=-99.9,
    sw_appear=-99.9,
    root_fraction_top_soil=0.93,
    leaf_longevity=8.0,
    GDD5_full_leaf_out=-99.9,
    GDD0_full_leaf_out=25.0,
    sapwood_respiration=2,
    optratioa=0.75,
    kk=0.3,
    c4=false,
    threshold=0.33,
    t0=-7.0,
    tcurve=0.6,
    respfact=4.0,
    allocfact=1.0,
    grass=true,
    constraints=(
        tcm=[-Inf, +Inf],
        min=[-Inf, +Inf],
        gdd=[-Inf, +Inf],
        gdd0=[50.0, +Inf],
        twm=[-Inf, 15.0],
        snow=[-Inf, +Inf]
    )
))


"""
    Default <: AbstractPFT

A default plant functional type (PFT) that ressembles a savanna grass and is defined as a generic PFT
with no specific characteristics. This PFT can be used as a default when no other PFT is suited to the environment.
"""
struct Default <: AbstractPFT
    characteristics::PFTCharacteristics
end

Default() = Default(PFTCharacteristics{Float64, Int}())

"""
    None<: AbstractPFT

A None type plant functional type (PFT) that is chosen when no PFT is applicable to the environment.
This PFT will lead to a Barren type biome
"""
struct None <: AbstractPFT
    characteristics::PFTCharacteristics
end

None() = None(PFTCharacteristics{Float64, Int}())

struct PFTClassification <: AbstractPFTList
    pft_list::Vector{AbstractPFT}
end

# TOFIX: not sure this is needed, but could be used to define functions 
# that are uniquely defined for specific biome classifications
PFTClassification() = PFTClassification([
    TropicalEvergreen(),
    TropicalDroughtDeciduous(),
    TemperateBroadleavedEvergreen(),
    TemperateDeciduous(),
    CoolConifer(),
    BorealEvergreen(),
    BorealDeciduous(),
    C3C4TemperateGrass(),
    C4TropicalGrass(),
    WoodyDesert(),
    TundraShrubs(),
    ColdHerbaceous(),
    LichenForb()
])

"""
    get_characteristic(pft::AbstractPFT, prop::Symbol)

Pulls out any field `prop` from `pft.characteristics`
"""
function get_characteristic(pft::AbstractPFT, prop::Symbol)
    if hasproperty(pft.characteristics, prop)
        return getproperty(pft.characteristics, prop)
    else
        throw(ArgumentError("`$(prop)` is not a field of PFTCharacteristics"))
    end
end
