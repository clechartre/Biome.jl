struct NeedleleafEvergreenForest <: AbstractBiome
    value::Int
    NeedleleafEvergreenForest() = new(1)
end

struct BroadleafEvergreenForest <: AbstractBiome
    value::Int
    BroadleafEvergreenForest() = new(2)
end

struct NeedleleafDeciduousForest <: AbstractBiome
    value::Int
    NeedleleafDeciduousForest() = new(3)
end

struct BroadleafDeciduousForest <: AbstractBiome
    value::Int
    BroadleafDeciduousForest() = new(4)
end

struct MixedForest <: AbstractBiome
    value::Int
    MixedForest() = new(5)
end

struct C3Grassland <: AbstractBiome
    value::Int
    C3Grassland() = new(6)
end

struct C4Grassland <: AbstractBiome
    value::Int
    C4Grassland() = new(7)
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
