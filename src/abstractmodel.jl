abstract type BiomeModel end # Main model structure 

# Define child types
struct WissmannModel <: BiomeModel end
struct BIOME4Model <: BiomeModel end
struct BIOMEDominanceModel <: BiomeModel end
struct ThornthwaiteModel <: BiomeModel end
struct KoppenModel <: BiomeModel end
struct TrollPfaffenModel <: BiomeModel end