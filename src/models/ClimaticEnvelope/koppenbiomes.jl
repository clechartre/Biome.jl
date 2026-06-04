# Third-party
using Statistics

"""
    runmodel(m::KoppenModel, vars_in::Vector{Union{T, U}}, args...; kwargs...) where {T <: Real, U <: Int}

Classify climate data using the Köppen-Geiger climate classification system.

# Arguments
- `m::KoppenModel`: The Köppen climate model instance
- `vars_in::Vector{Union{T, U}}`: Vector of climate variables (typically temperature and precipitation data)
- `args...`: Additional positional arguments
- `kwargs...`: Additional keyword arguments

# Returns
- Köppen-Geiger climate class identifier (integer 1-16+ corresponding to climate types)

# Köppen-Geiger Classes
The function classifies climate into the following categories:
- **Tropical (A)**: Af (1), Am (2), As (3), Aw (4)
- **Arid (B)**: BWk (5), BWh (6), BSk (7), BSh (8)  
- **Temperate (C)**: Cfa (9), Cfb (10), Cfc (11), Csa (12), Csb (13), Csc (14), Cwa (15), Cwb (16)
"""
# Define the Köppen-Geiger classification function
function runmodel(m::KoppenModel, input_variables::NamedTuple, args...; kwargs...)
    # Define Köppen-Geiger classes
    KG = Dict(
        :Af => 1,  # Equatorial, fully humid
        :Am => 2,  # Equatorial, monsoonal
        :As => 3,  # Equatorial, summer dry
        :Aw => 4,  # Equatorial, winter dry
        :BWk => 5,  # Cold desert
        :BWh => 6,  # Hot desert
        :BSk => 7,  # Cold steppe
        :BSh => 8,  # Hot steppe
        :Cfa => 9,  # Warm temperate, fully humid, hot summer
        :Cfb => 10, # Warm temperate, fully humid, warm summer
        :Cfc => 11, # Warm temperate, fully humid, cool summer
        :Csa => 12, # Warm temperate, summer dry, hot summer
        :Csb => 13, # Warm temperate, summer dry, warm summer
        :Csc => 14, # Warm temperate, summer dry, cool summer
        :Cwa => 15, # Warm temperate, winter dry, hot summer
        :Cwb => 16, # Warm temperate, winter dry, warm summer
        :Cwc => 17, # Warm temperate, winter dry, cool summer
        :Dfa => 18, # Snow, fully humid, hot summer
        :Dfb => 19, # Snow, fully humid, warm summer
        :Dfc => 20, # Snow, fully humid, cool summer
        :Dfd => 21, # Snow, fully humid, extremely continental
        :Dsa => 22, # Snow, summer dry, hot summer
        :Dsb => 23, # Snow, summer dry, warm summer
        :Dsc => 24, # Snow, summer dry, cool summer
        :Dsd => 25, # Snow, summer dry, extremely continental
        :Dwa => 26, # Snow, winter dry, hot summer
        :Dwb => 27, # Snow, winter dry, warm summer
        :Dwc => 28, # Snow, winter dry, cool summer
        :Dwd => 29, # Snow, winter dry, extremely continental
        :ET => 30,  # Polar tundra
        :EF => 31   # Polar frost
    )

    # Extract variables from vars_in
    @unpack_namedtuple_climate input_variables

    # Initialize intermediate variables
    tas_min = minimum(tas)
    tas_max = maximum(tas)
    tas_mean = mean(tas)

    pr_sum = sum(pr)
    pr_min = minimum(pr)

    # Calculate seasonal precipitation sums
    winter_pr = sum(pr[10:12]) + sum(pr[1:2])
    summer_pr = sum(pr[3:9])

    # Determine hemisphere
    is_northern_hemisphere = sum(tas[3:9]) > sum(tas[10:12]) + sum(tas[1:2])
    if !is_northern_hemisphere
        winter_pr, summer_pr = summer_pr, winter_pr
    end

    # Classification logic
    biome = classify_kg(tas, tas_min, tas_max, tas_mean, pr_sum, pr_min, winter_pr, summer_pr, KG)

    # Write results to the output
    output = (koppen_class = biome, lon = lon, lat = lat)

    return output
end

# Helper function for classification logic
function classify_kg(tas, tas_min, tas_max, tas_mean, pr_sum, pr_min, winter_pr, summer_pr, KG)
    # Polar climates
    if tas_max < 0
        return KG[:EF]  # Polar frost
    elseif tas_max < 10
        return KG[:ET]  # Polar tundra
    end

    # Arid climates
    threshold = if winter_pr >= 0.7 * pr_sum # Not sure about this
        tas_mean + 0
    elseif summer_pr >= 0.7 * pr_sum
        tas_mean + 14
    else
        tas_mean + 7
    end

    if pr_sum < 10 * threshold
        return tas_mean < 18 ? KG[:BWk] : KG[:BWh]  # Desert
    elseif pr_sum < 20 * threshold
        return tas_mean < 18 ? KG[:BSk] : KG[:BSh]  # Steppe
    end

    # Tropical climates
    if tas_min >= 18
        if pr_min >= 60
            return KG[:Af]
        elseif pr_sum >= 25 * (100 - pr_min)
            return KG[:Am]
        else
            return winter_pr < 60 ? KG[:Aw] : KG[:As]
        end
    end

    # Temperate climates
    dry_winter = summer_pr >= 10 * winter_pr
    dry_summer = winter_pr >= 3 * summer_pr && summer_pr < 30

    if dry_winter && dry_summer
        dry_winter = winter_pr > summer_pr
        dry_summer = !dry_winter
    end

    if tas_min >= 0
        if dry_winter
            return tas_max > 22 ? KG[:Cwa] : (count(x -> x > 10, tas) >= 4 ? KG[:Cwb] : KG[:Cwc])
        elseif dry_summer
            return tas_max > 22 ? KG[:Csa] : (count(x -> x > 10, tas) >= 4 ? KG[:Csb] : KG[:Csc])
        else
            return tas_max > 22 ? KG[:Cfa] : (count(x -> x > 10, tas) >= 4 ? KG[:Cfb] : KG[:Cfc])
        end
    end

    # Snow climates
    if dry_winter
        return tas_max > 22 ? KG[:Dwa] : (count(x -> x > 10, tas) >= 4 ? KG[:Dwb] : (tas_min > -38 ? KG[:Dwc] : KG[:Dwd]))
    elseif dry_summer
        return tas_max > 22 ? KG[:Dsa] : (count(x -> x > 10, tas) >= 4 ? KG[:Dsb] : (tas_min > -38 ? KG[:Dsc] : KG[:Dsd]))
    else
        return tas_max > 22 ? KG[:Dfa] : (count(x -> x > 10, tas) >= 4 ? KG[:Dfb] : (tas_min > -38 ? KG[:Dfc] : KG[:Dfd]))
    end

    # Default to undefined
    return -1
end

