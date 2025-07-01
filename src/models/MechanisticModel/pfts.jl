using Distributions

mutable struct Characteristics{T <: Real, U <: Int} <: AbstractPFTCharacteristics
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
    constraints::NamedTuple{(:tcm, :min, :gdd, :gdd0, :twm, :snow), NTuple{6, Vector{Float64}}}
    present::Bool
    dominance::T
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

# Default constructors for the PFTs
WoodyDesert(clt, prec, temp) = WoodyDesert(Characteristics(
    "C3C4WoodyDesert",
    1,      # phenological_type (evergreen)
    0.1,    # max_min_canopy_conductance
    1.0,    # EmaxD
    -99.9,    # sw_drop
    -99.9,    # sw_appear
    0.53,    # root_fraction_top_soil
    12.0,    # leaf_longevity
    -99.9, # GDD5_full_leaf_out
    -99.9,  # GDD0_full_leaf_out
    1,   # sapwood_respiration
    0.70,   # optratioa
    0.3,   # kk
    true,  # c4
    0.33,    # threshold
    5.0,    # t0
    1.0,    # tcurve
    1.4,    # respfact
    1.0,    # allocfact
    false,  # grass
    (tcm=[-99.9, -99.9], min=[-45.0, -99.9], gdd=[500.0, -99.9], gdd0=[-99.9, -99.9], twm=[10.0, -99.9], snow=[-99.9, -99.9]),  # constraints
    true, # present
    dominance_environment(clt, 9.2, 2.2) * dominance_environment(prec, 2.5, 2.8) * dominance_environment(temp, 23.9, 2.7)
))

TropicalEvergreen(clt, prec, temp) = TropicalEvergreen(Characteristics(
    "TropicalEvergreen",
    1,      # phenological_type (evergreen)
    0.5,    # max_min_canopy_conductance
    10.0,   # Emax
    -99.9,  # sw_drop
    -99.9,  # sw_appear
    0.69,   # root_fraction_top_soil
    18.0,   # leaf_longevity
    -99.9,  # GDD5_full_leaf_out
    -99.9,  # GDD0_full_leaf_out
    1,   # sapwood_respiration
    0.95,   # optratioa
    0.7,    # kk
    false,  # c4
    0.25,   # threshold
    10.0,    # t0
    1.0,    # tcurve
    0.8,    # respfact
    1.0,    # allocfact
    false,  # grass
    (tcm=[-99.9, -99.9], min=[0.0, -99.9], gdd=[-99.9, -99.9], gdd0=[-99.9, -99.9], twm=[10.0, -99.9], snow=[-99.9, -99.9]),  # constraints
    true,    # present
    dominance_environment(clt, 50.2, 4.9) * dominance_environment(prec, 169.6, 41.9) * dominance_environment(temp, 24.7, 1.2)# dominance
))

TropicalDroughtDeciduous(clt, prec, temp) = TropicalDroughtDeciduous(Characteristics(
    "TropicalDroughtDeciduous",
    3,      # phenological_type (deciduous)
    0.5,    # max_min_canopy_conductance
    10.0,    # Emax
    0.5,  # sw_drop
    0.6,  # sw_appear
    0.7,   # root_fraction_top_soil
    9.0,   # leaf_longevity
    -99.9,  # GDD5_full_leaf_out
    -99.9,  # GDD0_full_leaf_out
    1,   # sapwood_respiration
    0.9,   # optratioa
    0.7,    # kk
    false,  # c4
    0.20,   # threshold
    10.0,    # t0
    1.0,    # tcurve
    0.8,    # respfact
    1.0,    # allocfact
    false,  # grass
    (tcm=[-99.9, -99.9], min=[0.0, -99.9], gdd=[-99.9, -99.9], gdd0=[-99.9, -99.9], twm=[10.0, -99.9], snow=[-99.9, -99.9]),  # constraints
    true,    # present
    dominance_environment(clt, 44.0, 12.9) * dominance_environment(prec, 163.3, 85.1) * dominance_environment(temp, 23.7, 2.3) # dominance
))

TemperateBroadleavedEvergreen(clt, prec, temp) = TemperateBroadleavedEvergreen(Characteristics(
    "TemperateBroadleavedEvergreen",
    1,      # phenological_type (evergreen)
    0.2,    # max_min_canopy_conductance
    4.8,   # Emax
    -99.9,  # sw_drop
    -99.9,  # sw_appear
    0.67,   # root_fraction_top_soil
    18.0,   # leaf_longevity
    -99.9,  # GDD5_full_leaf_out
    -99.9,  # GDD0_full_leaf_out
    1,   # sapwood_respiration
    0.8,   # optratioa
    0.6,    # kk
    false,  # c4
    0.40,   # threshold
    5.0,    # t0
    1.0,    # tcurve
    1.4,    # respfact
    1.2,    # allocfact
    false,  # grass
    (tcm=[-99.9, -99.9], min=[-8.0, -99.9], gdd=[1200, -99.9], gdd0=[-99.9, -99.9], twm=[10.0, -99.9], snow=[-99.9, -99.9]),  # constraints
    true,    # present
    dominance_environment(clt, 33.4, 13.3) * dominance_environment(prec, 106.3, 83.6) * dominance_environment(temp, 18.7, 3.2) # dominance
))

TemperateDeciduous(clt, prec, temp) = TemperateDeciduous(Characteristics(
    "TemperateDeciduous",
    2,      # phenological_type
    0.8,    # max_min_canopy_conductance
    10.0,   # Emax
    -99.9,  # sw_drop
    -99.9,  # sw_appear
    0.65,   # root_fraction_top_soil
    7.0,   # leaf_longevity
    200.0,  # GDD5_full_leaf_out
    -99.9,  # GDD0_full_leaf_out
    1,   # sapwood_respiration
    0.8,   # optratioa
    0.6,    # kk
    false,  # c4
    0.33,   # threshold
    4.0,    # t0
    1.0,    # tcurve
    1.6,    # respfact
    1.2,    # allocfact
    false,  # grass
    (tcm=[-15.0, -99.9], min=[-99.9, -99.9], gdd=[1200, -99.9], gdd0=[-99.9, -99.9], twm=[-99.9, -99.9], snow=[-99.9, -99.9]),  # constraints
    true,    # present
    dominance_environment(clt, 40.9, 8.6) * dominance_environment(prec, 70.2, 41.9) * dominance_environment(temp, 8.4, 4.7)
))

CoolConifer(clt, prec, temp) = CoolConifer(Characteristics(
    "CoolConifer",
    1,      # phenological_type (evergreen)
    0.2,    # max_min_canopy_conductance
    4.8,    # Emax
    -99.9,  # sw_drop
    -99.9,  # sw_appear
    0.52,   # root_fraction_top_soil
    30.0,   # leaf_longevity
    -99.9,  # GDD5_full_leaf_out
    -99.9,  # GDD0_full_leaf_out
    1,   # sapwood_respiration
    0.9,   # optratioa
    0.5,    # kk
    false,  # c4
    0.40,   # threshold
    3.0,    # t0
    0.9,    # tcurve
    0.8,    # respfact
    1.2,    # allocfact
    false,  # grass
    (tcm=[-2.0, -99.9], min=[-99.9, 10.0], gdd=[900, -99.9], gdd0=[-99.9, -99.9], twm=[10.0, -99.9], snow=[-99.9, -99.9]),  # constraints
    true,    # present
    dominance_environment(clt, 28.1, 8.6) * dominance_environment(prec, 54.5, 49.9) * dominance_environment(temp, 13.9, 3.4)
    ))  

BorealEvergreen(clt, prec, temp) = BorealEvergreen(Characteristics(
    "BorealEvergreen",
    1,      # phenological_type (evergreen)
    0.5,    # max_min_canopy_conductance
    4.5,    # Emax
    -99.9,  # sw_drop
    -99.9,  # sw_appear
    0.83,   # root_fraction_top_soil
    24.0,   # leaf_longevity
    -99.9,  # GDD5_full_leaf_out
    -99.9,  # GDD0_full_leaf_out
    1,   # sapwood_respiration
    0.8,   # optratioa
    0.5,    # kk
    false,  # c4
    0.33,   # threshold
    0.0,    # t0
    0.8,    # tcurve
    4.0,    # respfact
    1.2,    # allocfact
    false,  # grass
    (tcm=[-32.5, -2.0], min=[-99.9, -99.9], gdd=[-99.9, -99.9], gdd0=[-99.9, -99.9], twm=[-99.9, 21.0], snow=[-99.9, -99.9]),  # constraints
    true, # present
    dominance_environment(clt, 48.1, 7.6) * dominance_environment(prec, 58.7, 35.7) * dominance_environment(temp, -2.7, 4.0)
))

BorealDeciduous(clt, prec, temp) = BorealDeciduous(Characteristics(
    "BorealDeciduous",
    2,      # phenological_type (deciduous)
    0.8,    # max_min_canopy_conductance
    10.0,    # Emax
    -99.9,  # sw_drop
    -99.9,  # sw_appear
    0.83,   # root_fraction_top_soil
    24.0,   # leaf_longevity
    200.0,  # GDD5_full_leaf_out
    -99.9,  # GDD0_full_leaf_out
    1,   # sapwood_respiration
    0.9,   # optratioa
    0.4,    # kk
    false,  # c4
    0.33,   # threshold
    0.0,    # t0
    0.8,    # tcurve
    4.0,    # respfact
    1.2,    # allocfact
    false,  # grass
    (tcm=[-99.9, 5.0], min=[-99.9, -10.0], gdd=[-99.9, -99.9], gdd0=[-99.9, -99.9], twm=[-99.9, 21.0], snow=[-99.9, -99.9]),  # constraints
    true,    # present
    dominance_environment(clt, 47.4, 8.3) * dominance_environment(prec, 65.0, 83.6) * dominance_environment(temp, -6.4, 7.7)
))

LichenForb(clt, prec, temp) = LichenForb(Characteristics(
    "LichenForb",
    1,      # phenological_type (evergreen)
    0.8,    # max_min_canopy_conductance
    1.0,    # Emax
    -99.9,  # sw_drop
    -99.9,  # sw_appear
    0.93,    # root_fraction_top_soil
    8.0,   # leaf_longevity
    -99.9,  # GDD5_full_leaf_out
    -99.9,  # GDD0_full_leaf_out
    1,   # sapwood_respiration
    0.80,   # optratioa
    0.6,    # kk
    false,  # c4
    0.33,    # threshold
    -12.0,    # t0
    0.5,    # tcurve
    4.0,    # respfact
    1.5,    # allocfact
    false,  # grass
    (tcm=[-99.9, -99.9], min=[-99.9, -99.9], gdd=[-99.9, -99.9], gdd0=[-99.9, -99.9], twm=[-99.9, 15.0], snow=[-99.9, -99.9]),  # constraints
    true,    # present
    dominance_environment(clt, 43.9, 9.0) * dominance_environment(prec, 53.3, 52.1) * dominance_environment(temp, -18.4, 4.1)
    ))

TundraShrubs(clt, prec, temp) = TundraShrubs(Characteristics(
    "TundraShrubs",
    1,      # phenological_type (evergreen)
    0.8,    # max_min_canopy_conductance
    1.0,    # Emax
    -99.9,  # sw_drop
    -99.9,  # sw_appear
    0.93,   # root_fraction_top_soil
    8.0,   # leaf_longevity
    -99.9,  # GDD5_full_leaf_out
    -99.9,  # GDD0_full_leaf_out
    1,   # sapwood_respiration
    0.90,   # optratioa
    0.5,    # kk
    false,  # c4
    0.33,    # threshold
    -7.0,    # t0
    0.6,    # tcurve
    4.0,    # respfact
    1.0,    # allocfact
    true,  # grass
    (tcm=[-99.9, -99.9], min=[-99.9, -99.9], gdd=[-99.9, -99.9], gdd0=[50.0, -99.9], twm=[-99.9, 15.0], snow=[15.0, -99.9]),  # constraints
    true,
    dominance_environment(clt, 51.4, 9.0) * dominance_environment(prec, 50.0, 43.3) * dominance_environment(temp, -10.8, 5.1)
))

C3C4TemperateGrass(clt, prec, temp) = C3C4TemperateGrass(Characteristics(
    "C3C4TemperateGrass",
    3,      # phenological_type
    0.8,    # max_min_canopy_conductance
    6.5,    # Emax
    0.2,  # sw_drop
    0.3,  # sw_appear
    0.83,   # root_fraction_top_soil
    8.0,   # leaf_longevity
    -99.9,  # GDD5_full_leaf_out
    100.0,  # GDD0_full_leaf_out
    2,   # sapwood_respiration
    0.65,   # optratioa
    0.4,    # kk
    false,  # c4
    0.40,    # threshold
    4.5,    # t0
    1.0,    # tcurve
    1.6,    # respfact
    1.0,    # allocfact
    true,  # grass
    (tcm=[-99.9, -99.9], min=[-99.9, -99.9], gdd=[550.0, -99.9], gdd0=[-99.9, -99.9], twm=[-99.9, -99.9], snow=[-99.9, -99.9]),  # constraints
    true,
    dominance_environment(clt, 16.6, 6.9) * dominance_environment(prec, 12.2, 13.4) * dominance_environment(temp, 21.3, 6.2)

))

C4TropicalGrass(clt, prec, temp) = C4TropicalGrass(Characteristics(
    "C4TropicalGrass",
    3,      # phenological_type
    0.8,    # max_min_canopy_conductance
    8.0,    # Emax
    0.2,  # sw_drop
    0.3,  # sw_appear
    0.57,   # root_fraction_top_soil
    10.0,   # leaf_longevity
    -99.9,  # GDD5_full_leaf_out
    -99.9,  # GDD0_full_leaf_out
    2,   # sapwood_respiration
    0.65,   # optratioa
    0.4,    # kk
    true,  # c4
    0.40,    # threshold
    10.0,    # t0
    0.8,    # tcurve
    0.8,    # respfact
    1.0,    # allocfact
    true,  # grass
    (tcm=[-99.9, -99.9], min=[-3.0, -99.9], gdd=[-99.9, -99.9], gdd0=[-99.9, -99.9], twm=[10.0, -99.9], snow=[-99.9, -99.9]),  # constraints
    true,   # present
    dominance_environment(clt, 9.4, 1.4) * dominance_environment(prec, 1.7, 2.1) * dominance_environment(temp, 23.2, 2.2)
))

ColdHerbaceous(clt, prec, temp) = ColdHerbaceous(Characteristics(
    "ColdHerbaceous",
    2,      # phenological_type
    0.8,    # max_min_canopy_conductance
    1.0,    # Emax
    -99.9,  # sw_drop
    -99.9,  # sw_appear
    0.93,   # root_fraction_top_soil
    8.0,   # leaf_longevity
    -99.9,  # GDD5_full_leaf_out
    25.0,  # GDD0_full_leaf_out
    2,   # sapwood_respiration
    0.75,   # optratioa
    0.3,    # kk
    false,  # c4
    0.33,    # threshold
    -7.0,    # t0
    0.6,    # tcurve
    4.0,    # respfact
    1.0,    # allocfact
    true,  # grass
    (tcm=[-99.9, -99.9], min=[-99.9, -99.9], gdd=[-99.9, -99.9], gdd0=[50.0, -99.9], twm=[-99.9, 15.0], snow=[-99.9, -99.9]),  # constraints
    true,   # present
    dominance_environment(clt, 10.4, 2.5) * dominance_environment(prec, 2.0, 1.6) * dominance_environment(temp, 23.5, 2.3)
))


struct BiomeClassification <: AbstractPFTList
    pft_list::Vector{AbstractPFT}
end

# TOFIX: not sure this is needed, but could be used to define functions that are uniquely defined for specific biome classifications
BiomeClassification(clt, prec, temp) = BiomeClassification([WoodyDesert(clt, prec, temp),
                                            TropicalEvergreen(clt, prec, temp),
                                            TropicalDroughtDeciduous(clt, prec, temp),
                                            TemperateBroadleavedEvergreen(clt, prec, temp),
                                            TemperateDeciduous(clt, prec, temp),
                                            CoolConifer(clt, prec, temp),
                                            BorealEvergreen(clt, prec, temp),
                                            BorealDeciduous(clt, prec, temp),
                                            LichenForb(clt, prec, temp),
                                            TundraShrubs(clt, prec, temp),
                                            C3C4TemperateGrass(clt, prec, temp),
                                            C4TropicalGrass(clt, prec, temp),
                                            ColdHerbaceous(clt, prec, temp)]) # place all other Biome4 PFTs here

# Define the functions to get all PFT characteristics easily
get_name(pft::AbstractPFT) = pft.characteristics.name
get_phenological_type(pft::AbstractPFT) = pft.characteristics.phenological_type
get_max_min_canopy_conductance(pft::AbstractPFT) = pft.characteristics.max_min_canopy_conductance
get_Emax(pft::AbstractPFT) = pft.characteristics.Emax
get_sw_drop(pft::AbstractPFT) = pft.characteristics.sw_drop
get_sw_appear(pft::AbstractPFT) = pft.characteristics.sw_appear
get_root_fraction_top_soil(pft::AbstractPFT) = pft.characteristics.root_fraction_top_soil
get_leaf_longevity(pft::AbstractPFT) = pft.characteristics.leaf_longevity
get_GDD5_full_leaf_out(pft::AbstractPFT) = pft.characteristics.GDD5_full_leaf_out
get_GDD0_full_leaf_out(pft::AbstractPFT) = pft.characteristics.GDD0_full_leaf_out
get_sapwood_respiration(pft::AbstractPFT) = pft.characteristics.sapwood_respiration
get_optratioa(pft::AbstractPFT) = pft.characteristics.optratioa
get_kk(pft::AbstractPFT) = pft.characteristics.kk
get_c4(pft::AbstractPFT) = pft.characteristics.c4
get_threshold(pft::AbstractPFT) = pft.characteristics.threshold
get_t0(pft::AbstractPFT) = pft.characteristics.t0
get_tcurve(pft::AbstractPFT) = pft.characteristics.tcurve
get_respfact(pft::AbstractPFT) = pft.characteristics.respfact
get_allocfact(pft::AbstractPFT) = pft.characteristics.allocfact
get_grass(pft::AbstractPFT) = pft.characteristics.grass
get_constraints(pft::AbstractPFT) = pft.characteristics.constraints
edit_presence(pft::AbstractPFT, present::Bool) = pft.characteristics.present = present
get_presence(pft::AbstractPFT) = pft.characteristics.present
get_dominance(pft::AbstractPFT) = pft.characteristics.dominance

function dominance_environment(clt, mean, std)
    # Draw the normal distribution around the mean and std 
    distribution = Normal(mean, std)

    # Pick the distribution at the clt value
    value = pdf(distribution, clt)

    # Normalize the value to be between 0 and 1, 1 is the mean and it decreases according to the standard deviation
    normalized_value = value / pdf(distribution, mean)

    return normalized_value

end

# export Characteristics, PFT, BiomeClassification,  get_name, get_phenological_type, get_max_min_canopy_conductance, get_Emax,
# get_sw_drop, get_sw_appear, get_root_fraction_top_soil, get_leaf_longevity,
# get_GDD5_full_leaf_out, get_GDD0_full_leaf_out, get_sapwood_respiration,
# get_optratioa, get_kk, get_c4, get_threshold, get_t0, get_tcurve,
# get_respfact, get_allocfact, get_grass, get_constraints, edit_presence, get_presence

