using Distributions

mutable struct Characteristics{T<:Real,U<:Int} <: AbstractPFTCharacteristics
    name::String
    phenological_type::U
    max_min_canopy_conductance::T
    Emax::T
    sw_drop::T
    sw_appear::T
    root_fraction_top_soil::T
    leaf_longevity::T
    GDD5_full_leaf_out::T
    GDD0_full_leaf_out::T
    sapwood_respiration::U
    optratioa::T
    kk::T
    c4::Bool
    threshold::T
    t0::T
    tcurve::T
    respfact::T
    allocfact::T
    grass::Bool
    constraints::NamedTuple{
        (:tcm, :min, :gdd, :gdd0, :twm, :snow),
        NTuple{6,Vector{Float64}}
    }
    # Values that will get filled through the code
    present::Bool
    dominance::T
    greendays::U
    firedays::T
    mwet::Vector{T}
    npp::T
    lai::T
end

# Define the PFT structures
struct WoodyDesert <: AbstractPFT
    characteristics::Characteristics
end

struct TropicalEvergreen <: AbstractPFT
    characteristics::Characteristics
end

struct TropicalDroughtDeciduous <: AbstractPFT
    characteristics::Characteristics
end

struct TemperateBroadleavedEvergreen <: AbstractPFT
    characteristics::Characteristics
end

struct TemperateDeciduous <: AbstractPFT
    characteristics::Characteristics
end

struct CoolConifer <: AbstractPFT
    characteristics::Characteristics
end

struct BorealEvergreen <: AbstractPFT
    characteristics::Characteristics
end

struct BorealDeciduous <: AbstractPFT
    characteristics::Characteristics
end

struct LichenForb <: AbstractPFT
    characteristics::Characteristics
end

struct TundraShrubs <: AbstractPFT
    characteristics::Characteristics
end

struct C3C4TemperateGrass <: AbstractPFT
    characteristics::Characteristics
end

struct C4TropicalGrass <: AbstractPFT
    characteristics::Characteristics
end

struct ColdHerbaceous <: AbstractPFT
    characteristics::Characteristics
end

struct Default <: AbstractPFT
    characteristics::Characteristics
end

struct None <: AbstractPFT
    characteristics::Characteristics
end

# Default Characteristics
Characteristics() = Characteristics(
    "Default",
    0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0,
    0.0,
    0.0,
    false,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    false,
    (
        tcm=[-Inf, +Inf],
        min=[-Inf, +Inf],
        gdd=[-Inf, +Inf],
        gdd0=[-Inf, +Inf],
        twm=[-Inf, +Inf],
        snow=[-Inf, +Inf]
    ),
    false,
    0.0,
    0,
    0.0,
    zeros(Float64, 12),
    0.0,
    0.0
)

# Default constructors for the PFTs
WoodyDesert(clt, prec, temp) = WoodyDesert(Characteristics(
    "C3C4WoodyDesert",
    1,
    0.1,
    1.0,
    -99.9,
    -99.9,
    0.53,
    12.0,
    -99.9,
    -99.9,
    1,
    0.70,
    0.3,
    true,
    0.33,
    5.0,
    1.0,
    1.4,
    1.0,
    false,
    (
        tcm=[-Inf, +Inf],
        min=[-45.0, +Inf],
        gdd=[500.0, +Inf],
        gdd0=[-Inf, +Inf],
        twm=[10.0, +Inf],
        snow=[-Inf, +Inf]
    ),
    true,
    dominance_environment(clt, 9.2, 2.2) *
        dominance_environment(prec, 2.5, 2.8) *
        dominance_environment(temp, 23.9, 2.7),
    0,
    0.0,
    zeros(Float64, 12),
    0.0,
    0.0
))

TropicalEvergreen(clt, prec, temp) = TropicalEvergreen(Characteristics(
    "TropicalEvergreen",
    1,
    0.5,
    10.0,
    -99.9,
    -99.9,
    0.69,
    18.0,
    -99.9,
    -99.9,
    1,
    0.95,
    0.7,
    false,
    0.25,
    10.0,
    1.0,
    0.8,
    1.0,
    false,
    (
        tcm=[-Inf, +Inf],
        min=[0.0, +Inf],
        gdd=[-Inf, +Inf],
        gdd0=[-Inf, +Inf],
        twm=[10.0, +Inf],
        snow=[-Inf, +Inf]
    ),
    true,
    dominance_environment(clt, 50.2, 4.9) *
        dominance_environment(prec, 169.6, 41.9) *
        dominance_environment(temp, 24.7, 1.2),
    0,
    0.0,
    zeros(Float64, 12),
    0.0,
    0.0
))

TropicalDroughtDeciduous(clt, prec, temp) = TropicalDroughtDeciduous(
    Characteristics(
        "TropicalDroughtDeciduous",
        3,
        0.5,
        10.0,
        0.5,
        0.6,
        0.7,
        9.0,
        -99.9,
        -99.9,
        1,
        0.9,
        0.7,
        false,
        0.20,
        10.0,
        1.0,
        0.8,
        1.0,
        false,
        (
            tcm=[-Inf, +Inf],
            min=[0.0, +Inf],
            gdd=[-Inf, +Inf],
            gdd0=[-Inf, +Inf],
            twm=[10.0, +Inf],
            snow=[-Inf, +Inf]
        ),
        true,
        dominance_environment(clt, 44.0, 12.9) *
            dominance_environment(prec, 163.3, 85.1) *
            dominance_environment(temp, 23.7, 2.3),
        0,
        0.0,
        zeros(Float64, 12),
        0.0,
        0.0
    )
)

TemperateBroadleavedEvergreen(clt, prec, temp) = TemperateBroadleavedEvergreen(
    Characteristics(
        "TemperateBroadleavedEvergreen",
        1,
        0.2,
        4.8,
        -99.9,
        -99.9,
        0.67,
        18.0,
        -99.9,
        -99.9,
        1,
        0.8,
        0.6,
        false,
        0.40,
        5.0,
        1.0,
        1.4,
        1.2,
        false,
        (
            tcm=[-Inf, +Inf],
            min=[-8.0, 5.0],
            gdd=[1200, +Inf],
            gdd0=[-Inf, +Inf],
            twm=[10.0, +Inf],
            snow=[-Inf, +Inf]
        ),
        true,
        dominance_environment(clt, 33.4, 13.3) *
            dominance_environment(prec, 106.3, 83.6) *
            dominance_environment(temp, 18.7, 3.2),
        0,
        0.0,
        zeros(Float64, 12),
        0.0,
        0.0
    )
)

TemperateDeciduous(clt, prec, temp) = TemperateDeciduous(Characteristics(
    "TemperateDeciduous",
    2,
    0.8,
    10.0,
    -99.9,
    -99.9,
    0.65,
    7.0,
    200.0,
    -99.9,
    1,
    0.8,
    0.6,
    false,
    0.33,
    4.0,
    1.0,
    1.6,
    1.2,
    false,
    (
        tcm=[-15.0, +Inf],
        min=[-Inf, -8.0],
        gdd=[1200, +Inf],
        gdd0=[-Inf, +Inf],
        twm=[-Inf, +Inf],
        snow=[-Inf, +Inf]
    ),
    true,
    dominance_environment(clt, 40.9, 8.6) *
        dominance_environment(prec, 70.2, 41.9) *
        dominance_environment(temp, 8.4, 4.7),
    0,
    0.0,
    zeros(Float64, 12),
    0.0,
    0.0
))

CoolConifer(clt, prec, temp) = CoolConifer(Characteristics(
    "CoolConifer",
    1,
    0.2,
    4.8,
    -99.9,
    -99.9,
    0.52,
    30.0,
    -99.9,
    -99.9,
    1,
    0.9,
    0.5,
    false,
    0.40,
    3.0,
    0.9,
    0.8,
    1.2,
    false,
    (
        tcm=[-2.0, +Inf],
        min=[-Inf, 10.0],
        gdd=[900, +Inf],
        gdd0=[-Inf, +Inf],
        twm=[10.0, +Inf],
        snow=[-Inf, +Inf]
    ),
    true,
    dominance_environment(clt, 28.1, 8.6) *
        dominance_environment(prec, 54.5, 49.9) *
        dominance_environment(temp, 13.9, 3.4),
    0,
    0.0,
    zeros(Float64, 12),
    0.0,
    0.0
))

BorealEvergreen(clt, prec, temp) = BorealEvergreen(Characteristics(
    "BorealEvergreen",
    1,
    0.5,
    4.5,
    -99.9,
    -99.9,
    0.83,
    24.0,
    -99.9,
    -99.9,
    1,
    0.8,
    0.5,
    false,
    0.33,
    0.0,
    0.8,
    4.0,
    1.2,
    false,
    (
        tcm=[-32.5, -2.0],
        min=[-Inf, +Inf],
        gdd=[-Inf, +Inf],
        gdd0=[-Inf, +Inf],
        twm=[-Inf, 21.0],
        snow=[-Inf, +Inf]
    ),
    true,
    dominance_environment(clt, 48.1, 7.6) *
        dominance_environment(prec, 58.7, 35.7) *
        dominance_environment(temp, -2.7, 4.0),
    0,
    0.0,
    zeros(Float64, 12),
    0.0,
    0.0
))

BorealDeciduous(clt, prec, temp) = BorealDeciduous(Characteristics(
    "BorealDeciduous",
    2,
    0.8,
    10.0,
    -99.9,
    -99.9,
    0.83,
    24.0,
    200.0,
    -99.9,
    1,
    0.9,
    0.4,
    false,
    0.33,
    0.0,
    0.8,
    4.0,
    1.2,
    false,
    (
        tcm=[-Inf, 5.0],
        min=[-Inf, -10.0],
        gdd=[-Inf, +Inf],
        gdd0=[-Inf, +Inf],
        twm=[-Inf, 21.0],
        snow=[-Inf, +Inf]
    ),
    true,
    dominance_environment(clt, 47.4, 8.3) *
        dominance_environment(prec, 65.0, 83.6) *
        dominance_environment(temp, -12, 7.7),
    0,
    0.0,
    zeros(Float64, 12),
    0.0,
    0.0
))

LichenForb(clt, prec, temp) = LichenForb(Characteristics(
    "LichenForb",
    1,
    0.8,
    1.0,
    -99.9,
    -99.9,
    0.93,
    8.0,
    -99.9,
    -99.9,
    1,
    0.80,
    0.6,
    false,
    0.33,
    -12.0,
    0.5,
    4.0,
    1.5,
    false,
    (
        tcm=[-Inf, +Inf],
        min=[-Inf, +Inf],
        gdd=[-Inf, +Inf],
        gdd0=[-Inf, +Inf],
        twm=[-Inf, 15.0],
        snow=[-Inf, +Inf]
    ),
    true,
    dominance_environment(clt, 43.9, 9.0) *
        dominance_environment(prec, 53.3, 52.1) *
        dominance_environment(temp, -18.4, 4.1),
    0,
    0.0,
    zeros(Float64, 12),
    0.0,
    0.0
))

TundraShrubs(clt, prec, temp) = TundraShrubs(Characteristics(
    "TundraShrubs",
    1,
    0.8,
    1.0,
    -99.9,
    -99.9,
    0.93,
    8.0,
    -99.9,
    -99.9,
    1,
    0.90,
    0.5,
    false,
    0.33,
    -7.0,
    0.6,
    4.0,
    1.0,
    true,
    (
        tcm=[-Inf, +Inf],
        min=[-Inf, +Inf],
        gdd=[-Inf, +Inf],
        gdd0=[50.0, +Inf],
        twm=[-Inf, 15.0],
        snow=[15.0, +Inf]
    ),
    true,
    dominance_environment(clt, 51.4, 9.0) *
        dominance_environment(prec, 50.0, 43.3) *
        dominance_environment(temp, -10.8, 5.1),
    0,
    0.0,
    zeros(Float64, 12),
    0.0,
    0.0
))

C3C4TemperateGrass(clt, prec, temp) = C3C4TemperateGrass(Characteristics(
    "C3C4TemperateGrass",
    3,
    0.8,
    6.5,
    0.2,
    0.3,
    0.83,
    8.0,
    -99.9,
    100.0,
    2,
    0.65,
    0.4,
    false,
    0.40,
    4.5,
    1.0,
    1.6,
    1.0,
    true,
    (
        tcm=[-Inf, +Inf],
        min=[-Inf, 0.0],
        gdd=[550.0, +Inf],
        gdd0=[-Inf, +Inf],
        twm=[-Inf, +Inf],
        snow=[-Inf, +Inf]
    ),
    true,
    dominance_environment(clt, 9.3, 1.5) *
        dominance_environment(prec, 1.5, 1.5) *
        dominance_environment(temp, 22.9, 2.7),
    0,
    0.0,
    zeros(Float64, 12),
    0.0,
    0.0
))

C4TropicalGrass(clt, prec, temp) = C4TropicalGrass(Characteristics(
    "C4TropicalGrass",
    3,
    0.8,
    8.0,
    0.2,
    0.3,
    0.57,
    10.0,
    -99.9,
    -99.9,
    2,
    0.65,
    0.4,
    true,
    0.40,
    10.0,
    1.0,
    0.8,
    1.0,
    true,
    (
        tcm=[-Inf, +Inf],
        min=[-3.0, +Inf],
        gdd=[-Inf, +Inf],
        gdd0=[-Inf, +Inf],
        twm=[10.0, +Inf],
        snow=[-Inf, +Inf]
    ),
    true,
    dominance_environment(clt, 9.4, 1.4) *
        dominance_environment(prec, 1.7, 2.1) *
        dominance_environment(temp, 23.2, 2.2),
    0,
    0.0,
    zeros(Float64, 12),
    0.0,
    0.0
))

ColdHerbaceous(clt, prec, temp) = ColdHerbaceous(Characteristics(
    "ColdHerbaceous",
    2,
    0.8,
    1.0,
    -99.9,
    -99.9,
    0.93,
    8.0,
    -99.9,
    25.0,
    2,
    0.75,
    0.3,
    false,
    0.33,
    -7.0,
    0.6,
    4.0,
    1.0,
    true,
    (
        tcm=[-Inf, +Inf],
        min=[-Inf, +Inf],
        gdd=[-Inf, +Inf],
        gdd0=[50.0, +Inf],
        twm=[-Inf, 15.0],
        snow=[-Inf, +Inf]
    ),
    true,
    dominance_environment(clt, 10.4, 2.5) *
        dominance_environment(prec, 2.0, 1.6) *
        dominance_environment(temp, 23.5, 2.3),
    0,
    0.0,
    zeros(Float64, 12),
    0.0,
    0.0
))

Default() = Default(Characteristics())
None() = None(Characteristics())

struct BiomeClassification <: AbstractPFTList
    pft_list::Vector{AbstractPFT}
end

# TOFIX: not sure this is needed, but could be used to define functions 
# that are uniquely defined for specific biome classifications
BiomeClassification(clt, prec, temp) = BiomeClassification([
    TropicalEvergreen(clt, prec, temp),
    TropicalDroughtDeciduous(clt, prec, temp),
    TemperateBroadleavedEvergreen(clt, prec, temp),
    TemperateDeciduous(clt, prec, temp),
    CoolConifer(clt, prec, temp),
    BorealEvergreen(clt, prec, temp),
    BorealDeciduous(clt, prec, temp),
    C3C4TemperateGrass(clt, prec, temp),
    C4TropicalGrass(clt, prec, temp),
    WoodyDesert(clt, prec, temp),
    TundraShrubs(clt, prec, temp),
    ColdHerbaceous(clt, prec, temp),
    LichenForb(clt, prec, temp)
])

"""
    get_characteristic(pft::AbstractPFT, prop::Symbol)

Pulls out any field `prop` from `pft.characteristics`
"""
function get_characteristic(pft::AbstractPFT, prop::Symbol)
    if hasproperty(pft.characteristics, prop)
        return getproperty(pft.characteristics, prop)
    else
        throw(ArgumentError("`$(prop)` is not a field of Characteristics"))
    end
end

"""
    set_characteristic!(pft::AbstractPFT, prop::Symbol, value)

Assigns to any mutable field `prop` in `pft.characteristics`
"""
function set_characteristic(pft::AbstractPFT, prop::Symbol, value)
    if hasproperty(pft.characteristics, prop)
        setfield!(pft.characteristics, prop, value)
    else
        throw(ArgumentError("`$(prop)` is not a field of Characteristics"))
    end
end

"""
    dominance_environment(clt, mean, std)

Calculate the normalized environmental dominance value for a given climate trait.

This function computes how well a species performs in a given environment by evaluating
a normal distribution centered on the species' optimal environmental conditions. The 
function returns a value between 0 and 1, where 1 represents optimal conditions (at the mean)
and values decrease as environmental conditions deviate from the optimum according to the
standard deviation.

# Arguments
- `clt`: The current climate/environmental value to evaluate
- `mean`: The optimal environmental value for the species (center of the distribution)
- `std`: The standard deviation representing the species' environmental tolerance

# Returns
- `Float64`: A normalized value between 0 and 1 representing environmental suitability,
  where 1.0 is optimal and lower values indicate decreasing suitability
"""
function dominance_environment(clt, mean, std)
    # Draw the normal distribution around the mean and std 
    distribution = Normal(mean, std)

    # Pick the distribution at the clt value
    value = pdf(distribution, clt)

    # Normalize the value to be between 0 and 1, 1 is the mean and it 
    # decreases according to the standard deviation
    normalized_value = value / pdf(distribution, mean)

    return normalized_value
end