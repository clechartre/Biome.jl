"""
    assign_biome(optpft::TropicalBase)

Assign biome for TropicalBase plant functional type.

Returns TropicalForest.
"""
function assign_biome(
    optpft::AbstractTropicalPFT;
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
    optpft::AbstractTemperatePFT;
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
    optpft::AbstractBorealPFT;
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
    optpft::Union{AbstractGrassPFT, Default};
    PFTStates::Dict{AbstractPFT, PFTState{Float64, Int}},
    wdom::AbstractPFT,
    kwargs...
)::AbstractBiome
    if PFTStates[wdom].npp > 1000
        return Grassland()
    else
        return Desert()
    end
end

"""
    assign_biome(optpft::Union{None, Default})

Assign biome for None/Default plant functional type.

Returns Desert biomes.
"""
function assign_biome(
    optpft::None;
    kwargs...
)::AbstractBiome
    return Desert()
end

