"""
    assign_biome(optpft::AbstractNeedleleafEvergreenPFT)

Assign biome for AbstractNeedleleafEvergreenPFT  plant functional type.

Returns NeedleleafEvergreenForest.
"""
function assign_biome(
    optpft::AbstractNeedleleafEvergreenPFT;
    kwargs...
)::AbstractBiome
    return NeedleleafEvergreenForest()
end

"""
    assign_biome(optpft::BroadleafEvergreenBase)

Assign biome for BroadleafEvergreenBase plant functional type.

Returns BroadleafEvergreenForest.
"""
function assign_biome(
    optpft::AbstractBroadleafEvergreenPFT;
    subpft::AbstractPFT,
    pftstates::Dict{AbstractPFT, PFTState},
    kwargs...
)::AbstractBiome
    # If the Difference in NPP between the dominant and subdominant PFT is very small 
    if subpft isa AbstractDeciduousPFT &&
        abs(pftstates[subpft].npp - pftstates[optpft].npp) / pftstates[optpft].npp ≤ 0.07
        return MixedForest()
    else
        return BroadleafEvergreenForest()
    end
end

"""
    assign_biome(optpft::NeedleleafDeciduousBase)

Assign biome for NeedleleafDeciduousBase plant functional type.

Returns NeedleleafDeciduousForest.
"""
function assign_biome(
    optpft::AbstractNeedleleafDeciduousPFT;
    kwargs...
)::AbstractBiome
    return NeedleleafDeciduousForest()
end


"""
    assign_biome(optpft::BroadleafDeciduousBase)

Assign biome for BroadleafDeciduousBase plant functional type.

Returns BroadleafDeciduousForest.
"""
function assign_biome(
    optpft::AbstractBroadleafDeciduousPFT;
    subpft::AbstractPFT,
    pftstates::Dict{AbstractPFT, PFTState},
    kwargs...
)::AbstractBiome
    if subpft isa AbstractEvergreenPFT &&
        abs(pftstates[subpft].npp - pftstates[optpft].npp) / pftstates[optpft].npp ≤ 0.07
        return MixedForest()
    else
        return BroadleafDeciduousForest()
    end
end

"""
    assign_biome(optpft::AbstractC3GrassPFT)

Assign biome for C3GrassBase plant functional type.

Returns C3Grassland.
"""
function assign_biome(
    optpft::AbstractC3GrassPFT;
    pftstates::Dict{AbstractPFT, PFTState},
    gdom::AbstractPFT,
    kwargs...
)::AbstractBiome
    if pftstates[gdom].npp > 400
        return C3Grassland()
    else
        return HotandColdDesert()
    end
end

"""
    assign_biome(optpft::AbstractC4GrassPFT)

Assign biome for C4GrassBase plant functional type.

Returns C4Grassland.
"""
function assign_biome(
    optpft::Union{AbstractC4GrassPFT, Default};
    pftstates::Dict{AbstractPFT, PFTState},
    gdom::AbstractPFT,
    kwargs...
)::AbstractBiome
    if pftstates[gdom].npp > 400
        return C4Grassland()
    else
        return HotandColdDesert()
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
    return HotandColdDesert()
end

