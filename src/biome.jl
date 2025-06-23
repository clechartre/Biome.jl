"""
    BIOME

A Julia module for climatr-based biome modeling.

This module provides implementations of various biome classification models and 
plant functional type (PFT) characterization systems. It includes both mechanistic
and empirical approaches for modeling vegetation patterns and climate-vegetation
relationships.

# Exported Types
- `AbstractPFTList`: Abstract type for plant functional type collections
- `AbstractPFTCharacteristics`: Abstract type for PFT trait definitions  
- `AbstractPFT`: Abstract type for individual plant functional types
- `AbstractPFTList`: Abstract type for PFT groupings that make up biome classifications

# Exported Models
- `BIOME4`: Mechanistic dynamic global vegetation model from Kaplan & Prentice, 2001
- `WissmannModel`: [Add description]
- `BIOME4Model`: [Add description] 
- `ThornthwaiteModel`: Climate classification model based on precipitation and temperature
- `KoppenModel`: Climate classification system
- `TrollPfaffenModel`: [Add description]
"""

module BIOME 

include("AbstractTypes.jl")
export AbstractPFTList, AbstractPFTCharacteristics, AbstractPFT, AbstractPFTList

include("models/MechanisticModel/biome4.jl")
export BIOME4 

include("models/abstractmodel.jl")
export WissmannModel, BIOME4, ThornthwaiteModel, KoppenModel, TrollPfaffenModel

end # Module