# Third-party imports
using Printf

"""
    ppeett(lat, dtemp, dclou, temp)

Calculate insolation and potential evapotranspiration (PET) for each month.

This function computes daily potential evapotranspiration, day length, solar 
radiation, and annual radiation based on latitude, temperature, and cloud cover.

# Arguments
- `lat`: Latitude in degrees
- `dtemp`: Daily temperature array (365 elements, °C)
- `dclou`: Daily cloud cover array (365 elements, %)
- `temp`: Monthly temperature array (12 elements, °C)

# Returns
A tuple containing:
- `dpet`: Daily potential evapotranspiration (365 elements, mm/day)
- `dayl`: Monthly day length (12 elements, hours)
- `sun`: Monthly solar radiation (12 elements, MJ/m²/day)
- `rad0`: Annual radiation sum (MJ/m²/year)
- `ddayl`: Daily day length (365 elements, hours)
"""
function ppeett(
    lat::T,
    dtemp::AbstractArray{T},
    dclou::AbstractArray{T},
    temp::AbstractArray{T},
    env::NamedTuple
)::Tuple{AbstractArray{T},AbstractArray{T},AbstractArray{T},T,AbstractArray{T}} where {T<:Real}
    midday = Int[16, 44, 75, 105, 136, 166, 197, 228, 258, 289, 319, 350]
    daysinmonth = Int[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    pie = T(4.0) * atan(T(1.0))
    dip = pie / T(180.0)

    b = T(0.2)
    radup = T(107.0)
    qoo = T(1360.0)
    d = T(0.5)
    c = T(0.25)
    albedo = T(0.17)

    dpet = zeros(T, 365)
    ddayl = zeros(T, 365)
    dayl = zeros(T, 12)
    sun = zeros(T, 12)

    day = 0
    rad0 = T(0.0)

    for month in 1:12
        for _ in 1:daysinmonth[month]
            day += 1

            psi, l = table(dtemp[day])

            rl = (b + (T(1) - b) * (dclou[day] / T(100.0))) * (radup - dtemp[day])
            rl *= 1 # originally radanom but not used in this version

            qo = qoo * (T(1.0) + T(2.0) * T(0.01675) * 
                       cos(dip * (T(360.0) * day) / T(365.0)))
            rs = qo * (c + d * (dclou[day] / T(100.0))) * (T(1.0) - albedo)
            rs *= 1 # originally radanom but not used in this version

            a = -dip * T(23.4) * 
                cos(dip * T(360.0) * (day + T(10.0)) / T(365.0))
            cla = cos(lat * dip) * cos(a)
            sla = sin(lat * dip) * sin(a)
            u = rs * sla - rl
            v = rs * cla

            if u >= v
                ho = pie
            elseif u <= -v
                ho = T(0.0)
            else
                ho = acos(-u / v)
            end

            # Safe exponential calculation
            exp_arg = (T(17.27) * dtemp[day]) / (T(237.3) + dtemp[day])
            exp_val = try
                exp(exp_arg)
            catch
                T(Inf)
            end
            
            sat = (T(2.5) * T(10)^T(6) * exp_val) / 
                  ((T(237.3) + dtemp[day])^T(2.0))
            
            if (sat + psi) != T(0.0) && psi != T(0.0)
                fd = (T(3600.0) / (l * T(1e6))) * (sat / (sat + psi))
            else
                fd = T(0.0)
            end

            dpet[day] = fd * T(2.0) * 
                       ((rs * sla - rl) * ho + rs * cla * sin(ho)) / 
                       (pie / T(12.0))

            if ho == T(0.0)
                ddayl[day] = T(0.0)
            else
                ddayl[day] = T(24.0) * (ho / pie)
            end

            if day == midday[month]
                dayl[month] = ddayl[day]

                us = rs * sla
                vs = rs * cla
                if us >= vs
                    hos = pie
                elseif us <= -vs
                    hos = T(0.0)
                else
                    hos = acos(-us / vs)
                end

                sun[month] = T(2.0) * (rs * sla * hos + rs * cla * sin(hos)) * 
                            (T(3600.0) * T(12.0) / pie)
                if sun[month] <= T(0.0)
                    sun[month] = T(0.0)
                end

                if temp[month] > T(0.0)
                    rad0 += daysinmonth[month] * sun[month] * T(1e-9) * T(0.5)
                end
            end
        end
    end

    return (
        get(env, :dpet, dpet),
        get(env, :dayl, dayl),
        get(env, :sun, sun),
        get(env, :rad0, rad0),
        get(env, :ddayl, ddayl)
    )
end
