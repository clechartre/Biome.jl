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
    temp_min = minimum(temp)
    temp_max = maximum(temp)
    temp_mean = mean(temp)

    precip_sum = sum(prec)
    precip_min = minimum(prec)

    # Calculate seasonal precipitation sums
    winter_precip = sum(prec[10:12]) + sum(prec[1:2])
    summer_precip = sum(prec[3:9])

    # Determine hemisphere
    is_northern_hemisphere = sum(temp[3:9]) > sum(temp[10:12]) + sum(temp[1:2])
    if !is_northern_hemisphere
        winter_precip, summer_precip = summer_precip, winter_precip
    end

    # Classification logic
    biome = classify_kg(temp, temp_min, temp_max, temp_mean, precip_sum, precip_min, winter_precip, summer_precip, KG)

    # Write results to the output
    output = (koppen_class = biome, lon = lon, lat = lat)

    return output
end

# Helper function for classification logic
function classify_kg(temp, temp_min, temp_max, temp_mean, precip_sum, precip_min, winter_precip, summer_precip, KG)
    # Polar climates
    if temp_max < 0
        return KG[:EF]  # Polar frost
    elseif temp_max < 10
        return KG[:ET]  # Polar tundra
    end

    # Arid climates
    threshold = if winter_precip >= 0.7 * precip_sum # Not sure about this
        temp_mean + 0
    elseif summer_precip >= 0.7 * precip_sum
        temp_mean + 14
    else
        temp_mean + 7
    end

    if precip_sum < 10 * threshold
        return temp_mean < 18 ? KG[:BWk] : KG[:BWh]  # Desert
    elseif precip_sum < 20 * threshold
        return temp_mean < 18 ? KG[:BSk] : KG[:BSh]  # Steppe
    end

    # Tropical climates
    if temp_min >= 18
        if precip_min >= 60
            return KG[:Af]
        elseif precip_sum >= 25 * (100 - precip_min)
            return KG[:Am]
        else
            return winter_precip < 60 ? KG[:Aw] : KG[:As]
        end
    end

    # Temperate climates
    dry_winter = summer_precip >= 10 * winter_precip
    dry_summer = winter_precip >= 3 * summer_precip && summer_precip < 30

    if dry_winter && dry_summer
        dry_winter = winter_precip > summer_precip
        dry_summer = !dry_winter
    end

    if temp_min >= 0
        if dry_winter
            return temp_max > 22 ? KG[:Cwa] : (count(x -> x > 10, temp) >= 4 ? KG[:Cwb] : KG[:Cwc])
        elseif dry_summer
            return temp_max > 22 ? KG[:Csa] : (count(x -> x > 10, temp) >= 4 ? KG[:Csb] : KG[:Csc])
        else
            return temp_max > 22 ? KG[:Cfa] : (count(x -> x > 10, temp) >= 4 ? KG[:Cfb] : KG[:Cfc])
        end
    end

    # Snow climates
    if dry_winter
        return temp_max > 22 ? KG[:Dwa] : (count(x -> x > 10, temp) >= 4 ? KG[:Dwb] : (temp_min > -38 ? KG[:Dwc] : KG[:Dwd]))
    elseif dry_summer
        return temp_max > 22 ? KG[:Dsa] : (count(x -> x > 10, temp) >= 4 ? KG[:Dsb] : (temp_min > -38 ? KG[:Dsc] : KG[:Dsd]))
    else
        return temp_max > 22 ? KG[:Dfa] : (count(x -> x > 10, temp) >= 4 ? KG[:Dfb] : (temp_min > -38 ? KG[:Dfc] : KG[:Dfd]))
    end

    # Default to undefined
    return -1
end

