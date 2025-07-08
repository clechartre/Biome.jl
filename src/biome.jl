"""
    BIOME

A Julia module for climate-based biome modeling.

This module provides implementations of various biome classification models and 
plant functional type (PFT) characterization systems. It includes both mechanistic
and empirical approaches for modeling vegetation patterns and climate-vegetation
relationships.
"""

module BIOME 

# Core abstract types
include("pfts.jl")
include("biomes.jl")
include("abstractmodel.jl")

# Constants (must be loaded early for other modules to use)
include("models/MechanisticModel/constants.jl")
using .Constants

# PFT definitions and classifications
include("models/MechanisticModel/pfts.jl")
include("models/MechanisticModel/biomes.jl")

# Core mechanistic model components
include("models/MechanisticModel/utils.jl")
include("models/MechanisticModel/climdata.jl")
include("models/MechanisticModel/constraints.jl")
include("models/MechanisticModel/findnpp.jl")
include("models/MechanisticModel/phenology.jl")
include("models/MechanisticModel/ppeett.jl")
include("models/MechanisticModel/snow.jl")
include("models/MechanisticModel/soiltemp.jl")
include("models/MechanisticModel/competition2.jl")
include("models/MechanisticModel/table.jl")

# Growth subroutines
include("models/MechanisticModel/growth_subroutines/daily.jl")
include("models/MechanisticModel/growth_subroutines/c4photo.jl")
include("models/MechanisticModel/growth_subroutines/calcphi.jl")
include("models/MechanisticModel/growth_subroutines/fire.jl")
include("models/MechanisticModel/growth_subroutines/hetresp.jl")
include("models/MechanisticModel/growth_subroutines/hydrology.jl")
include("models/MechanisticModel/growth_subroutines/isotope.jl")
include("models/MechanisticModel/growth_subroutines/photosynthesis.jl")
include("models/MechanisticModel/growth_subroutines/respiration.jl")

# Main BIOME4 model (after all dependencies)
include("models/MechanisticModel/biome4.jl")

# Climatic envelope models
include("models/ClimaticEnvelope/koppenbiomes.jl")
include("models/ClimaticEnvelope/thornthwaitebiomes.jl")
include("models/ClimaticEnvelope/trollpfaffenbiomes.jl")
include("models/ClimaticEnvelope/wissmannbiomes.jl")

# Export all necessary types and functions
export AbstractPFTList, AbstractPFTCharacteristics, AbstractPFT,
       AbstractBiomeCharacteristics, AbstractBiome, AbstractBiomeList,
       BiomeModel, WissmannModel, BIOME4Model, ThornthwaiteModel, KoppenModel, TrollPfaffenModel,
       
       # Constants
       T, P0, CP, T0, G, M, R0,
       QEFFC3, DRESPC3, DRESPC4, ABS1, TETA, SLO2, JTOE, OPTRATIO,
       KO25, KC25, TAO25, CMASS, KCQ10, KOQ10, TAOQ10,
       TWIGLOSS, TUNE, LEAFRESP, MAXTEMP,
       LN, Y0, M10, P1, STEMCARBON,
       E0, TREF, TEMP0,
       A, ES, A1, B3, B,
       
       # PFT types and functions
       PFTClassification, Default, None, get_characteristic, PFTState,
       TropicalEvergreen, TropicalDroughtDeciduous, TemperateBroadleavedEvergreen,
       TemperateDeciduous, CoolConifer, BorealEvergreen, BorealDeciduous,
       C4TropicalGrass, LichenForb, TundraShrubs, ColdHerbaceous,
       WoodyDesert, C3C4TemperateGrass,
       
       # Biome types
       TropicalEvergreenForest, TropicalSemiDeciduousForest, TropicalDeciduousForestWoodland,
       TropicalGrassland, TropicalSavanna, TropicalXerophyticShrubland,
       TemperateSclerophyllWoodland, TemperateBroadleavedSavanna,
       OpenConiferWoodland, BorealParkland, Barren, LandIce,
       
       # Functions
       get_biome_characteristic, climdata, competition2, constraints, daily_interp, findnpp,
       phenology, ppeett, snow, soiltemp, safe_exp, safe_round_to_int,
       c4photo, calcphi, fire, hetresp, hydrology, isotope, photosynthesis, respiration, table
       
       # Main functions
        run
       
       # Constants instances
       NONE_INSTANCE, DEFAULT_INSTANCE

end # Module