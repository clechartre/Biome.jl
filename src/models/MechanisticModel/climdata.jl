"""
    climdata(temp, prec, dtemp, env=nothing)

Calculate growing degree days (GDD), temperature extremes, and precipitation.

This function computes various climate indices including growing degree days
above different temperature thresholds, coldest and warmest monthly temperatures,
and total annual precipitation. If environment data is provided, it will be used
to override the calculated values.

# Arguments
- `temp`: Monthly temperature array (12 elements, °C)
- `prec`: Monthly precipitation array (12 elements, mm)
- `dtemp`: Daily temperature array (365 elements, °C)
- `env`: Optional NamedTuple with pre-calculated values (:tcm, :gdd5, :gdd0, :twm)

# Returns
A tuple containing:
- `tcm`: Temperature of coldest month (°C)
- `gdd5`: Growing degree days above 5°C
- `gdd0`: Growing degree days above 0°C
- `twm`: Temperature of warmest month (°C)

# Notes
- GDD calculations use daily temperature data
- Negative temperature differences are set to zero for GDD calculations
- Function assumes 365-day year
- If env data is provided, those values take precedence over calculated ones
"""
function climdata(
    temp::AbstractArray{T},
    prec::AbstractArray{T},
    dtemp::AbstractArray{T},
    env::Union{NamedTuple,Nothing}=nothing
)::Tuple{T,T,T,T} where {T<:Real}

    # Initialize temperature extremes
    tcm = T(100.0)  # coldest month temperature
    twm = T(-100.0) # warmest month temperature
    annual_precip = T(0.0)

    # Find coldest and warmest months, sum precipitation
    for m in 1:12
        if temp[m] < tcm
            tcm = temp[m]
        end
        if temp[m] > twm
            twm = temp[m]
        end
        annual_precip += prec[m]
    end

    # Initialize growing degree day accumulators
    gdd10 = T(0.0)
    gdd5 = T(0.0)
    gdd0 = T(0.0)

    # Calculate growing degree days for each day of year
    for day in 1:365
        # Calculate temperature differences above thresholds
        above_10 = max(dtemp[day] - T(10.0), T(0.0))
        above_5 = max(dtemp[day] - T(5.0), T(0.0))
        above_0 = max(dtemp[day], T(0.0))
        
        # Accumulate growing degree days
        gdd10 += above_10
        gdd5 += above_5
        gdd0 += above_0
    end

    # Use env data if available, otherwise use calculated values
    if env !== nothing
        return (
            get(env, :tcm, tcm),
            get(env, :gdd5, gdd5),
            get(env, :gdd0, gdd0),
            get(env, :twm, twm)
        )
    else
        return (tcm, gdd5, gdd0, twm)
    end
end