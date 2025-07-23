"""
    assign_biome(optpft::EvergreenBase)

Assign biome for EvergreenBase plant functional type.

Returns EvergreenForest.
"""
function assign_biome(
    optpft::AbstractEvergreenPFT;
    subpft::AbstractPFT,
    PFTStates::Dict{AbstractPFT, PFTState},
    kwargs...
)::AbstractBiome
    if subpft isa AbstractDeciduousPFT && # they have more or less the same npp 
        PFTStates[subpft].npp > 400
        return MixedForest()
    else
        return EvergreenForest()
    end
end

"""
    assign_biome(optpft::DeciduousBase)

Assign biome for DeciduousBase plant functional type.

Returns DeciduousForest.
"""
function assign_biome(
    optpft::AbstractDeciduousPFT;
    subpft::AbstractPFT,
    PFTStates::Dict{AbstractPFT, PFTState},
    kwargs...
)::AbstractBiome
    if subpft isa AbstractEvergreenPFT && # they have more or less the same npp 
        PFTStates[subpft].npp > 400
        return MixedForest()
    else
        return DeciduousForest()
    end
end

"""
    assign_biome(optpft::GrassBase)

Assign biome for GrassBase plant functional type.

Returns Grassland.
"""
function assign_biome(
    optpft::Union{AbstractGrassPFT, Default};
    PFTStates::Dict{AbstractPFT, PFTState},
    wdom::AbstractPFT,
    gdom::AbstractPFT,
    kwargs...
)::AbstractBiome
    if PFTStates[gdom].npp > 400
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
    optpft::TundraPFT;
    kwargs...
)::AbstractBiome
    return Tundra()
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

