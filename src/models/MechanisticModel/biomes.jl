# Define the Biome structures
struct TropicalForest <: AbstractBiome
    value::Int
    TropicalForest() = new(1)
end

struct TemperateForest <: AbstractBiome
    value::Int
    TemperateForest() = new(2)
end

struct BorealForest <: AbstractBiome
    value::Int
    BorealForest() = new(3)
end

struct Grassland <: AbstractBiome
    value::Int
    Grassland() = new(4)
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
