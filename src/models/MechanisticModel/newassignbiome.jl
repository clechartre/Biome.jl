"""
    assign_biome(optpft::TropicalBase)

Assign biome for TropicalBase plant functional type.

Returns TropicalForest.
"""
function assign_biome(
    optpft::TropicalBase;
    kwargs...
)::AbstractBiome
    return TropicalForest()
end

"""
    assign_biome(optpft::TemperateBase)

Assign biome for TemperateBase plant functional type.

Returns TemperateForest.
"""
function assign_biome(
    optpft::TemperateBase;
    kwargs...
)::AbstractBiome
    return TemperateForest()
end

"""
    assign_biome(optpft::BorealBase)

Assign biome for BorealBase plant functional type.

Returns BorealForest.
"""
function assign_biome(
    optpft::BorealBase;
    kwargs...
)::AbstractBiome
    return BorealForest()
end

"""
    assign_biome(optpft::GrassBase)

Assign biome for GrassBase plant functional type.

Returns Grassland.
"""
function assign_biome(
    optpft::GrassBase;
    kwargs...
)::AbstractBiome
    return Grassland()
end

"""
    assign_biome(optpft::Union{None, Default})

Assign biome for None/Default plant functional type.

Returns Desert biomes.
"""
function assign_biome(
    optpft::Union{None, Default};
    kwargs...
)::AbstractBiome
    return Desert()
end
