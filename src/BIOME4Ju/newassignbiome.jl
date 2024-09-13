"""Assign biomes as in BIOME3.5 according to a new scheme of biomes.
Jed Kaplan 3/1998"""

module BiomeAssignment

function newassignbiome(
    optpft::Int,
    woodpft::Int,
    grasspft::Int,
    subpft::Int,
    optnpp::Union{Int, Float64},
    woodnpp::Union{Int, Float64},
    grassnpp::Union{Int, Float64},
    subnpp::Union{Int, Float64},
    greendays::Int,
    gdd0::Float64,
    gdd5::Float64,
    tcm::Float64,
    present::Vector{Bool},
    woodylai::Float64,
    grasslai::Float64,
    tmin::Float64
)::Int
    nppdif = optnpp - subnpp

    # Barren
    if optpft == 0
        return 27
    end

    # Arctic/Alpine Biomes
    if optpft == 13
        return 26
    end
    if optpft == 11
        if gdd0 < 200.0
            return 25
        elseif gdd0 < 500.0
            return 24
        else
            return 23
        end
    end
    if optpft == 12
        return 22
    end

    # Desert
    if optpft == 10
        if grasslai > 1.0
            if tmin >= 0.0
                return 13
            else
                return 14
            end
        else
            return 21 # this is the issue, I am plotting this as tundra??
        end
    elseif optnpp <= 100.0
        if optpft <= 5 || optpft in [9, 10]
            return 21 
        elseif optpft == 8
            if subpft != 6 || subpft != 7
                return 21
            end
        end
    end

    # Boreal Biomes
    if optpft == 6
        if gdd5 > 900.0 && tcm > -19.0
            if present[4+1]
                return 7
            else
                return 8
            end
        else
            if present[4+1]
                return 9
            else
                return 10
            end
        end
    end
    if optpft == 7
        if subpft == 4
            return 4
        elseif subpft == 5
            return 9
        elseif gdd5 > 900.0 && tcm > -19.0
            return 9
        else
            return 11
        end
    end

    # Temperate Biomes
    if optpft == 8
        if gdd0 >= 800.0
            return 20
        else
            return 22
        end
    end
    if optpft == 3
        return 6
    end
    if optpft == 4
        if present[6+1]
            if tcm < -15.0
                return 9
            else
                return 7
            end
        elseif present[3+1] || (present[5+1] && gdd5 > 3000.0 && tcm > 3.0)
            return 6
        else
            return 4
        end
    end
    if optpft == 5
        if present[3+1]
            return 6
        elseif subpft == 4 && nppdif < 50.0
            return 5
        elseif subpft == 7
            return 9
        else
            return 5
        end
    end

    # Savanna and Woodland
    if optpft == 14
        if woodpft <= 2
            if woodylai > 4.0
                return 12
            else
                return 13
            end
        elseif woodpft == 3
            return 15
        elseif woodpft == 4
            return 16
        elseif woodpft == 5
            return 17
        elseif woodpft in [6, 7]
            return 18
        end
    end

    # Tropical Biomes
    if optpft <= 2 || optpft == 9
        if optpft == 1
            return 1
        end
        if optpft == 2
            if greendays > 300
                return 1
            elseif greendays > 250
                return 2
            else
                return 3
            end
        end
        if optpft == 9
            return 19
        end
    end

    # Default to 0 if no conditions are met
    return 0
end

end # module
