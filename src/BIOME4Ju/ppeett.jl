module Ppeett

include("./table.jl")
using .Table
using Printf

struct PpeettResults
    dpet::AbstractArray{Float64}
    dayl::AbstractArray{Float64}
    sun::AbstractArray{Float64}
    rad0::Float64
    ddayl::AbstractArray{Float64}
end

function safe_exp(x::Float64)::Float64
    try
        return exp(x)
    catch e
        return Inf
    end
end

function ppeett(
    lat::Float32,
    dtemp::AbstractArray{Float64},
    dclou::AbstractArray{Float64},
    radanom::AbstractArray{Float64},
    temp::AbstractArray{Float64}
)::PpeettResults
    midday = [16, 44, 75, 105, 136, 166, 197, 228, 258, 289, 319, 350]
    daysinmonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    pie = 4.0 * atan(1.0)
    dip = pie / 180.0

    b = 0.2
    radup = 107.0
    qoo = 1360.0
    d = 0.5
    c = 0.25
    albedo = 0.17

    dpet = zeros(Float64, 365)
    ddayl = zeros(Float64, 365)
    dayl = zeros(Float64, 12)
    sun = zeros(Float64, 12)

    day = 0
    rad0 = 0.0

    for month in 1:12
        for dayofm in 1:daysinmonth[month]
            day += 1

            psi, l = Table.table(dtemp[day])

            rl = (b + (1 - b) * (dclou[day] / 100.0)) * (radup - dtemp[day])
            rl *= radanom[month]

            qo = qoo * (1.0 + 2.0 * 0.01675 * cos(dip * (360.0 * day) / 365.0))
            rs = qo * (c + d * (dclou[day] / 100.0)) * (1.0 - albedo)
            rs *= radanom[month]

            a = -dip * 23.4 * cos(dip * 360.0 * (day + 10.0) / 365.0)
            cla = cos(lat * dip) * cos(a)
            sla = sin(lat * dip) * sin(a)
            u = rs * sla - rl
            v = rs * cla

            if u >= v
                ho = pie
            elseif u <= -v
                ho = 0.0
            else
                ho = acos(-u / v)
            end

            sat = (2.5 * 10^6 * safe_exp((17.27 * dtemp[day]) / (237.3 + dtemp[day]))) / ((237.3 + dtemp[day]) ^ 2)
            if (sat + psi) != 0 && psi != 0
                fd = (3600.0 / (l * 1e6)) * (sat / (sat + psi))
            else
                fd = 0
            end

            dpet[day] = fd * 2.0 * ((rs * sla - rl) * ho + rs * cla * sin(ho)) / (pie / 12.0)

            if ho == 0.0
                ddayl[day] = 0.0
            else
                ddayl[day] = 24.0 * (ho / pie)
            end

            if day == midday[month]
                dayl[month] = ddayl[day]

                us = rs * sla
                vs = rs * cla
                if us >= vs
                    hos = pie
                elseif us <= -vs
                    hos = 0.0
                else
                    hos = acos(-us / vs)
                end

                sun[month] = 2.0 * (rs * sla * hos + rs * cla * sin(hos)) * (3600.0 * 12.0 / pie)
                if sun[month] <= 0.0
                    sun[month] = 0.0
                end

                if temp[month] > 0.0
                    rad0 += daysinmonth[month] * sun[month] * 1e-9 * 0.5
                end
            end
        end
    end

    return PpeettResults(dpet, dayl, sun, rad0, ddayl)
end

end # module Ppeett
