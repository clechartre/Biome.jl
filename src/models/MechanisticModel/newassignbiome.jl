# ————— Biome assignment —————

# 1) A generic catch‑all that gives grasslands if the PFT has grass=true:
function assign_biome(
    pft::AbstractPFT;
    PFTStates::Dict{AbstractPFT,PFTState{T,U}},
    wdom::AbstractPFT=nothing,
    gdom::AbstractPFT=nothing,
    kwargs...
)::AbstractBiome where {T<:Real, U<:Int}
    # if this PFT has been “grassed” …
    if get_characteristic(pft, :grass)
        if PFTStates[gdom].npp > 400
            return Grassland()
        else
            return Desert()
        end
    end
    # otherwise fall back to the type hierarchy
    if pft isa AbstractTropicalPFT
        return TropicalForest()
    elseif pft isa AbstractTemperatePFT
        return TemperateForest()
    elseif pft isa AbstractBorealPFT
        return BorealForest()
    elseif pft isa AbstractTundraPFT
        return Tundra()
    else
        # default/no PFT → desert
        return Desert()
    end
end



# """
#     assign_biome(optpft::TropicalBase)

# Assign biome for TropicalBase plant functional type.

# Returns TropicalForest.
# """
# function assign_biome(
#     optpft::AbstractTropicalPFT;
#     kwargs...
# )::AbstractBiome
#     return TropicalForest()
# end

# """
#     assign_biome(optpft::TemperateBase)

# Assign biome for TemperateBase plant functional type.

# Returns TemperateForest.
# """
# function assign_biome(
#     optpft::AbstractTemperatePFT;
#     kwargs...
# )::AbstractBiome
#     return TemperateForest()
# end

# """
#     assign_biome(optpft::BorealBase)

# Assign biome for BorealBase plant functional type.

# Returns BorealForest.
# """
# function assign_biome(
#     optpft::AbstractBorealPFT;
#     kwargs...
# )::AbstractBiome
#     return BorealForest()
# end

# """
#     assign_biome(optpft::GrassBase)

# Assign biome for GrassBase plant functional type.

# Returns Grassland.
# """
# function assign_biome(
#     optpft::Union{AbstractGrassPFT, Default};
#     PFTStates::Dict{AbstractPFT, PFTState{Float64, Int}},
#     wdom::AbstractPFT,
#     kwargs...
# )::AbstractBiome
#     if PFTStates[wdom].npp > 1000
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

# """
#     assign_biome(optpft::Union{None, Default})

# Assign biome for None/Default plant functional type.

# Returns Desert biomes.
# """
# function assign_biome(
#     optpft::None;
#     kwargs...
# )::AbstractBiome
#     return Desert()
# end

