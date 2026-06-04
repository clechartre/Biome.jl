using Statistics

"""
    runmodel(m::WissmannModel, vars_in::Vector{<:Union{<:Real,<:Int}}, args...; kwargs...)

Classify climate by the Wissmann scheme using 12 months of temperature and precipitation.

# Arguments
- `m::WissmannModel`  
  Model instance (for dispatch).
- `vars_in::Vector{Union{T,U}}`  
  Length‑28 vector where:
  - indices 5–16: monthly mean temperatures
  - indices 17–28: monthly precipitation totals
- `args..., kwargs...`  
  Ignored extras.

# Returns
- `output::Vector{Int}` (length 1)  
  Single-element vector holding the integer code (1–22) of the matched Wissmann zone.

# Notes
- Computes seasonal totals, mean, min/max temperatures.
- Determines hemisphere to compare winter vs summer precipitation.
- Applies tiered thresholds for Polar, Boreal, Temperate, and Tropical groups.
"""
function runmodel(m::WissmannModel, input_variables::NamedTuple, args...; kwargs...)
    # Define Wissmann climate zones
    WI = Dict(
        :IA  => 1, #("I A", "Rainforest, equatorial"),
        :IF  => 2, # ("I F", "Rainforest, weak dry period"),
        :IT  => 3, #("I T", "Savannah and monsoonal rainforest"),
        :IS  => 4, #("I S", "Steppe, tropical"),
        :ID  => 5, #("I D", "Desert, tropical"),
        :II_Fa => 6, #("II Fa", "Warm temperate, humid, summer dry"),
        :II_Fb => 7, #("II Fb", "Warm temperate, humid"),
        :II_Tw => 8, #("II Tw", "Warm temperate, winter dry"),
        :II_Ts => 9, #("II Ts", "Warm temperate, cool summer"),
        :II_S  => 10, #("II S", "Steppe, warm temperate"),
        :II_D  => 11, #("II D", "Desert, warm temperate"),
        :III_F => 12, #("III F", "Cool temperate, humid"),
        :III_Tw => 13, #("III Tw", "Cool temperate, winter dry"),
        :III_Ts => 14, #("III Ts", "Cool temperate, summer dry"),
        :III_S  => 15, #("III S", "Steppe, cool temperate"),
        :III_D  => 16, #("III D", "Desert, cool temperate"),
        :IV_F => 17, #("IV F", "Boreal, humid"),
        :IV_T => 18, #("IV T", "Boreal, winter dry"),
        :IV_S => 19, #("IV S", "Steppe, boreal"),
        :IV_D => 20, #("IV D", "Desert, boreal"),
        :V   => 21, #("V", "Polar tundra"),
        :VI  => 22, #("VI", "Polar frost")
    )

    # Extract temperature and precipitation data
    @unpack_namedtuple_climate input_variables

    # Temperature and precipitation statistics
    tas_min = minimum(tas)
    tas_max = maximum(tas)
    tas_mean = mean(tas)
    pr_sum = sum(pr)
    pr_min = minimum(pr)

    winter_pr = sum(pr[10:12]) + sum(pr[1:2])
    summer_pr = sum(pr[3:9])

    is_northern_hemisphere = sum(tas[3:9]) > sum(tas[10:12]) + sum(tas[1:2])

    if !is_northern_hemisphere
        winter_pr, summer_pr = summer_pr, winter_pr
    end

    t_threshold = 10 * (winter_pr > summer_pr ? tas_mean : tas_mean + 14.0)

    # VI - Polar frost
    if tas_max < 0
        return (climate_zone = WI[:VI],)
    # V - Polar tundra
    elseif tas_max < 10
        return (climate_zone = WI[:V],)
    end

    # IV - Boreal climates
    if tas_mean < 4
        if pr_sum > 2.5 * t_threshold
            return (climate_zone = WI[:IV_F],)
        elseif pr_sum > 2.0 * t_threshold
            return (climate_zone = WI[:IV_T],)
        elseif pr_sum > 1.0 * t_threshold
            return (climate_zone = WI[:IV_S],)
        else
            return (climate_zone = WI[:IV_D],)
        end
    end

    # III - Cool temperate
    if tas_min < 2
        if pr_sum > 2.5 * t_threshold
            return (climate_zone = WI[:III_F],)
        elseif pr_sum > 2.0 * t_threshold
            return (climate_zone = winter_pr < summer_pr ? WI[:III_Tw] : WI[:III_Ts],)
        elseif pr_sum > 1.0 * t_threshold
            return (climate_zone = WI[:III_S],)
        else
            return (climate_zone = WI[:III_D],)
        end
    end

    # II - Warm temperate
    if tas_min < 13
        if pr_sum > 2.5 * t_threshold
            return (climate_zone = tas_max > 23 ? WI[:II_Fa] : WI[:II_Fb],)
        elseif pr_sum > 2.0 * t_threshold
            return (climate_zone = winter_pr < summer_pr ? WI[:II_Tw] : WI[:II_Ts],)
        elseif pr_sum > 1.0 * t_threshold
            return (climate_zone = WI[:IS],)
        else
            return (climate_zone = WI[:ID],)
        end
    end

    # I - Tropical
    if tas_min >= 13
        if pr_min >= 60
            return (climate_zone = WI[:IA],)
        elseif pr_sum > 2.5 * t_threshold
            return (climate_zone = WI[:IF],)
        elseif pr_sum > 2.0 * t_threshold
            return (climate_zone = WI[:IT],)
        elseif pr_sum > 1.0 * t_threshold
            return (climate_zone = WI[:IS],)
        else
            return (climate_zone = WI[:ID],)
        end
    end

    return (wissmann_climate_zone = -1,)  # fallback if classification fails
end