abstract type BiomeModel end # Main model structure 

# Subtypes
abstract type ClimateModel <: BiomeModel end
abstract type MechanisticModel <: BiomeModel end

# Specific Types
struct KoppenModel <: ClimateModel end
struct ThornthwaiteModel <: ClimateModel end
struct TrollPfaffenModel <: ClimateModel end
struct WissmannModel <: ClimateModel end

# Define child types
struct BaseModel <: MechanisticModel end
struct BIOME4Model <: MechanisticModel end
struct BIOMEDominanceModel <: MechanisticModel end


