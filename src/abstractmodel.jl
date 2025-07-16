abstract type BiomeModel end # Main model structure 

# Define child types
struct BaseModel <: BiomeModel end
struct BIOME4Model <: BiomeModel end
struct BIOMEDominanceModel <: BiomeModel end
struct KoppenModel <: BiomeModel end
struct ThornthwaiteModel <: BiomeModel end
struct TrollPfaffenModel <: BiomeModel end
struct WissmannModel <: BiomeModel end
