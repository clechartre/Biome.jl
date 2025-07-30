# """
#     assign_biome(optpft::EvergreenBase)

# Assign biome for EvergreenBase plant functional type.

# Returns EvergreenForest.
# """
# function assign_biome(
#     optpft::AbstractEvergreenPFT;
#     subpft::AbstractPFT,
#     pftstates::Dict{AbstractPFT, PFTState},
#     kwargs...
# )::AbstractBiome
#     if subpft isa AbstractDeciduousPFT && # they have more or less the same npp 
#         pftstates[subpft].npp > 400
#         return MixedForest()
#     else
#         return EvergreenForest()
#     end
# end

# """
#     assign_biome(optpft::DeciduousBase)

# Assign biome for DeciduousBase plant functional type.

# Returns DeciduousForest.
# """
# function assign_biome(
#     optpft::AbstractDeciduousPFT;
#     subpft::AbstractPFT,
#     pftstates::Dict{AbstractPFT, PFTState},
#     kwargs...
# )::AbstractBiome
#     if subpft isa AbstractEvergreenPFT && # they have more or less the same npp 
#         pftstates[subpft].npp > 400
#         return MixedForest()
#     else
#         return DeciduousForest()
#     end
# end

# """
#     assign_biome(optpft::GrassBase)

# Assign biome for GrassBase plant functional type.

# Returns Grassland.
# """
# function assign_biome(
#     optpft::Union{AbstractGrassPFT, Default};
#     pftstates::Dict{AbstractPFT, PFTState},
#     wdom::AbstractPFT,
#     gdom::AbstractPFT,
#     kwargs...
# )::AbstractBiome
#     if pftstates[gdom].npp > 400
#         return Grassland()
#     else
#         return Desert()
#     end
# end

# """
#     assign_biome(optpft::Union{None, Default})

# Assign biome for None/Default plant functional type.

# Returns Desert biomes.
# """
# function assign_biome(
#     optpft::TundraPFT;
#     kwargs...
# )::AbstractBiome
#     return Tundra()
# end

"""
    assign_biome(optpft::AbstractNeedleleafEvergreenPFT)

Assign biome for AbstractNeedleleafEvergreenPFT  plant functional type.

Returns NeedleleafEvergreenForest.
"""
function assign_biome(
    optpft::AbstractNeedleleafEvergreenPFT;
    subpft::AbstractPFT,
    pftstates::Dict{AbstractPFT, PFTState},
    kwargs...
)::AbstractBiome
    if subpft isa AbstractDeciduousPFT && abs(pftstates[subpft].npp - pftstates[optpft].npp) / pftstates[optpft].npp ≤ 0.15
        return MixedForest()
         
        return MixedForest()
    else
        return NeedleleafEvergreenForest()
    end
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
    if subpft isa AbstractDeciduousPFT &&
        abs(pftstates[subpft].npp - pftstates[optpft].npp) / pftstates[optpft].npp ≤ 0.15
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
    subpft::AbstractPFT,
    pftstates::Dict{AbstractPFT, PFTState},
    kwargs...
)::AbstractBiome
    if subpft isa AbstractEvergreenPFT &&
        abs(pftstates[subpft].npp - pftstates[optpft].npp) / pftstates[optpft].npp ≤ 0.15
        return MixedForest()
    else
        return NeedleleafDeciduousForest()
    end
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
        abs(pftstates[subpft].npp - pftstates[optpft].npp) / pftstates[optpft].npp ≤ 0.15
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
    wdom::AbstractPFT,
    gdom::AbstractPFT,
    kwargs...
)::AbstractBiome
    if pftstates[gdom].npp > 400
        return C3Grassland()
    else
        return Desert()
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
    wdom::AbstractPFT,
    gdom::AbstractPFT,
    kwargs...
)::AbstractBiome
    if pftstates[gdom].npp > 400
        return C4Grassland()
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

