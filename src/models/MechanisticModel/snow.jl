using Dates

"""
    snow(dtemp, dprecin)

Calculate daily precipitation and snowmelt from daily temperature and 
precipitation input. Snow accumulates when temperature is below
the snow threshold and melts when temperature is above it.

# Arguments
- `dtemp`: Daily temperature array (365 elements, °C)
- `dprecin`: Daily precipitation input array (365 elements, mm)

# Returns
A tuple containing:
- `dprec`: Daily precipitation (rain) after accounting for snow (365 elements)
- `dmelt`: Daily snowmelt (365 elements, mm)
- `maxdepth`: Maximum snow depth reached during the year (mm)

# Notes
- Snow threshold temperature is set to -1.0°C
- Melt coefficient is 0.7 mm/°C/day
- Function runs twice to ensure equilibrium
"""
function snow(
    dtemp::AbstractArray{T}, 
    dprecin::AbstractArray{T}
)::Tuple{AbstractArray{T},AbstractArray{T},T} where {T<:Real}
    tsnow = T(-1.0)
    km = T(0.7)
    snowpack = T(0.0)
    maxdepth = T(0.0)

    dprec = zeros(T, 365)
    dmelt = zeros(T, 365)

    for _ in 1:2
        sum1 = T(0.0)
        sum2 = T(0.0)

        drain_factor = T(365.0) / T(12.0)  # Precompute drain factor
        for day in 1:365
            drain = dprecin[day] / drain_factor

            if dtemp[day] < tsnow
                newsnow = drain
                snowmelt = T(0.0)
            else
                newsnow = T(0.0)
                snowmelt = km * (dtemp[day] - tsnow)
            end

            if snowmelt > snowpack
                snowmelt = snowpack
            end

            snowpack += newsnow - snowmelt
            maxdepth = max(maxdepth, snowpack)

            dprec[day] = drain - newsnow
            dmelt[day] = snowmelt

            sum1 += dprec[day] + dmelt[day]
            sum2 += drain
        end
    end

    return dprec, dmelt, maxdepth
end