"""Assign biomes as in BIOME3.5 according to a new scheme of biomes.
Jed Kaplan 3/1998"""

module BiomeAssignment

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
    present::Vector{Bool},
    woodylai::T,
    grasslai::T,
    tmin::T
)::U where {T <: Real, U <: Int}
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
        if gdd0 < T(200.0)
            return 25
        elseif gdd0 < T(500.0)
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
        if gdd5 > T(900.0) && tcm > T(-19.0)
            if present[4]
                return 7
            else
                return 8
            end
        else
            if present[4]
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
        elseif gdd5 > T(900.0) && tcm > T(-19.0)
            return 9
        else
            return 11
        end
    end

    # Temperate Biomes
    if optpft == 8
        if gdd0 >= T(800.0)
            return 20
        else
            return 22
        end
    end
    if optpft == 3
        return 6
    end
    if optpft == 4
        if present[6]
            if tcm < T(-15.0)
                return 9
            else
                return 7
            end
        elseif present[3] || (present[5] && gdd5 > T(3000.0) && tcm > T(3.0))
            return 6
        else
            return 4
        end
    end
    if optpft == 5
        if present[3]
            return 6
        elseif subpft == 4 && nppdif < T(50.0)
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
            if woodylai > T(4.0)
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
            if greendays > U(300)
                return 1
            elseif greendays > U(250)
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
