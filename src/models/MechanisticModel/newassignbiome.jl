"""Assign biomes as in BIOME3.5 according to a new scheme of biomes.
Jed Kaplan 3/1998"""

module BiomeAssignment

abstract struct AbstractBiome end

struct Desert <: AbstractBiome end

function assign_biome(pft_vec, biomes::Desert)

    if pftpar[optpft].name == "C3_C4_woody_desert"
            if grasslai > T(1.0)
                if tmin >= T(0.0)
                    return 13
                else
                    return 14
                end
            else
                return 21
            end
        elseif optnpp <= T(100.0)
            if pftpar[optpft].name in ["tropical_evergreen", 
                "tropical_drought_deciduous", "temperate_broadleaved_evergreen",
                "temperate_deciduous", "cool_conifer",
                "C4_tropical_grass", "C3_C4_woody_desert"]
                # What characteristic of the PFT is being used here? 
                # TODO find common characteristic of PFT 1 to 5 and 9 and 10
                return 21 
            elseif optpft != 0 && pftpar[optpft].name == "C3_C4_temperate_grass"
                if subpft != 0 && (pftpar[subpft].name != "boreal_evergreen" || pftpar[subpft].name != "boreal_deciduous")
                    return 21
                end
            end
        end

end

"""

Arguments:
- Vector{AbstractPFT}
- Vector{AbstractBiome}

"""
function newassignbiome(
    optpft::U,
    woodpft::U,
    subpft::U,
    optnpp::Union{U, T},
    subnpp::Union{U, T},
    greendays::U,
    gdd0::T,
    gdd5::T,
    tcm::T,
    present::Dict{String, Bool},
    woodylai::T,
    grasslai::T,
    tmin::T,
    pftpar
)::U where {T <: Real, U <: Int}
    nppdif = optnpp - subnpp

    # Barren
    if optpft == 0
        return 27
    end

    if optpft != 14
        # Arctic/Alpine Biomes
        # if optpft == 13        
        if pftpar[optpft].name == "lichen_forb"
            return 26
        end

        # if optpft == 11
        if pftpar[optpft].name == "tundra_shrubs"
            if gdd0 < T(200.0)
                return 25
            elseif gdd0 < T(500.0)
                return 24
            else
                return 23
            end
        end
        # if optpft == 12
        if pftpar[optpft].name == "cold_herbaceous"
            return 22
        end

        # Desert
        # if optpft == 10
        

        # Boreal Biomes
        # if optpft == 6
        if pftpar[optpft].name == "boreal_evergreen"
            if gdd5 > T(900.0) && tcm > T(-19.0)
                if present["temperate_deciduous"]
                    return 7
                else
                    return 8
                end
            else
                if present["temperate_deciduous"]
                    return 9
                else
                    return 10
                end
            end
        end
        # if optpft == 7
        if pftpar[optpft].name == "boreal_deciduous"
            if subpft != 0 && pftpar[subpft].name == "temperate_deciduous"
                return 4
            elseif subpft != 0 && pftpar[subpft].name == "cool_conifer"
                return 9
            elseif gdd5 > T(900.0) && tcm > T(-19.0)
                return 9
            else
                return 11
            end
        end

        # Temperate Biomes
        # if optpft == 8
        if pftpar[optpft].name == "C3_C4_temperate_grass"
            if gdd0 >= T(800.0)
                return 20
            else
                return 22
            end
        end
        # if optpft == 3
        if pftpar[optpft].name == "temperate_broadleaved_evergreen"
            return 6
        end
        # if optpft == 4
        if pftpar[optpft].name == "temperate_deciduous"
            if present["boreal_evergreen"]
                if tcm < T(-15.0)
                    return 9
                else
                    return 7
                end
            elseif present["temperate_broadleaved_evergreen"] || (present["cool_conifer"] && gdd5 > T(3000.0) && tcm > T(3.0))
                return 6
            else
                return 4
            end
        end
        # if optpft == 5
        if pftpar[optpft].name == "cool_conifer"
            if present["temperate_broadleaved_evergreen"]
                return 6
            elseif subpft != 0 && pftpar[subpft].name == "temperate_deciduous" && nppdif < T(50.0)
                return 5
            elseif subpft != 0 && pftpar[subpft].name == "boreal_deciduous"
                return 9
            else
                return 5
            end
        end

        # Tropical Biomes
        if pftpar[optpft].name in ["tropical_evergreen", "tropical_drought_deciduous", "C4_tropical_grass"]
            if pftpar[optpft].name == "tropical_evergreen"
                return 1
            end
            if pftpar[optpft].name == "tropical_drought_deciduous"
                if greendays > U(300)
                    return 1
                elseif greendays > U(250)
                    return 2
                else
                    return 3
                end
            end
            if pftpar[optpft].name == "C4_tropical_grass"
                return 19
            end
        end

    # Savanna and Woodland
    elseif optpft == 14
        if woodpft == 0 || pftpar[woodpft].name == "tropical_evergreen" || pftpar[woodpft].name == "tropical_drought_deciduous"
            if woodylai > T(4.0)
                return 12
            else
                return 13
            end
        elseif woodpft != 0 && pftpar[woodpft].name == "temperate_broadleaved_evergreen"
            return 15
        elseif woodpft != 0 && pftpar[woodpft].name == "temperate_deciduous"
            return 16
        elseif woodpft != 0 && pftpar[woodpft].name == "cool_conifer"
            return 17
        elseif woodpft != 0 && pftpar[woodpft].name in ["boreal_evergreen", "boreal_deciduous"]
            return 18
        end

    end
    # Default to 0 if no conditions are met
    return 0
end

end # module
