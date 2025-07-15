# Define the Biome structures
struct TropicalEvergreenForest <: AbstractBiome
    value::Int
    TropicalEvergreenForest() = new(1)
end

struct TropicalSemiDeciduousForest <: AbstractBiome
    value::Int
    TropicalSemiDeciduousForest() = new(2)
end

struct TropicalDeciduousForestWoodland <: AbstractBiome
    value::Int
    TropicalDeciduousForestWoodland() = new(3)
end

struct TemperateDeciduousForest <: AbstractBiome
    value::Int
    TemperateDeciduousForest() = new(4)
end

struct TemperateConiferForest <: AbstractBiome
    value::Int
    TemperateConiferForest() = new(5)
end

struct WarmMixedForest <: AbstractBiome
    value::Int
    WarmMixedForest() = new(6)
end

struct CoolConiferForest <: AbstractBiome
    value::Int
    CoolConiferForest() = new(7)
end

struct CoolMixedForest <: AbstractBiome
    value::Int
    CoolMixedForest() = new(8)
end

struct ColdMixedForest <: AbstractBiome
    value::Int
    ColdMixedForest() = new(9)
end

struct EvergreenTaigaMontaneForest <: AbstractBiome
    value::Int
    EvergreenTaigaMontaneForest() = new(10)
end

struct DeciduousTaigaMontaneForest <: AbstractBiome
    value::Int
    DeciduousTaigaMontaneForest() = new(11)
end

struct TropicalSavanna <: AbstractBiome
    value::Int
    TropicalSavanna() = new(12)
end

struct TropicalXerophyticShrubland <: AbstractBiome
    value::Int
    TropicalXerophyticShrubland() = new(13)
end

struct TemperateXerophyticShrubland <: AbstractBiome
    value::Int
    TemperateXerophyticShrubland() = new(14)
end

struct TemperateSclerophyllWoodland <: AbstractBiome
    value::Int
    TemperateSclerophyllWoodland() = new(15)
end

struct TemperateBroadleavedSavanna <: AbstractBiome
    value::Int
    TemperateBroadleavedSavanna() = new(16)
end

struct OpenConiferWoodland <: AbstractBiome
    value::Int
    OpenConiferWoodland() = new(17)
end

struct BorealParkland <: AbstractBiome
    value::Int
    BorealParkland() = new(18)
end

struct TropicalGrassland <: AbstractBiome
    value::Int
    TropicalGrassland() = new(19)
end

struct TemperateGrassland <: AbstractBiome
    value::Int
    TemperateGrassland() = new(20)
end

struct Desert <: AbstractBiome
    value::Int
    Desert() = new(21)
end

struct SteppeTundra <: AbstractBiome
    value::Int
    SteppeTundra() = new(22)
end

struct ShrubTundra <: AbstractBiome
    value::Int
    ShrubTundra() = new(23)
end

struct DwarfShrubTundra <: AbstractBiome
    value::Int
    DwarfShrubTundra() = new(24)
end

struct ProstateShrubTundra <: AbstractBiome
    value::Int
    ProstateShrubTundra() = new(25)
end

struct CushionForbsLichenMoss <: AbstractBiome
    value::Int
    CushionForbsLichenMoss() = new(26)
end

struct Barren <: AbstractBiome
    value::Int
    Barren() = new(27)
end

struct LandIce <: AbstractBiome
    value::Int
    LandIce() = new(28)
end


function get_biome_characteristic(biome::AbstractBiome, prop::Symbol)
    if hasproperty(biome, prop)
        return getproperty(biome, prop)
    else
        throw(ArgumentError("`$(prop)` is not a field of Characteristics"))
    end
end
