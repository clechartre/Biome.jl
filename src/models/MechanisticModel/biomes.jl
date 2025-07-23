struct EvergreenForest <: AbstractBiome
    value::Int
    EvergreenForest() = new(1)
end

struct DeciduousForest <: AbstractBiome
    value::Int
    DeciduousForest() = new(2)
end

struct MixedForest <: AbstractBiome
    value::Int
    MixedForest() = new(3)
end

struct Grassland <: AbstractBiome
    value::Int
    Grassland() = new(4)
end

struct Tundra <: AbstractBiome
    value::Int
    Tundra() = new(5)
end

struct Desert <: AbstractBiome
    value::Int
    Desert() = new(21)
end
 
function get_biome_characteristic(biome::AbstractBiome, prop::Symbol)
    if hasproperty(biome, prop)
        return getproperty(biome, prop)
    else
        throw(ArgumentError("`$(prop)` is not a field of Characteristics"))
    end
end
