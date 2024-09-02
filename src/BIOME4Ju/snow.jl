"""Mask precipitation to account for effects of snow."""

module Snow

using Dates

struct SnowResults
    dprec::AbstractArray{Float64}
    dmelt::AbstractArray{Float64}
    maxdepth::Float64
end

function snow(dtemp::AbstractArray{Float64}, dprecin::AbstractArray{Float64})::SnowResults
    tsnow = -1.0
    km = 0.7
    snowpack = 0.0
    maxdepth = 0.0

    dprec = zeros(Float64, 365)
    dmelt = zeros(Float64, 365)

    for it in 1:2
        sum1 = 0.0
        sum2 = 0.0

        for day in 1:365
            drain = dprecin[day] / (365.0 / 12.0)

            # Calculate snow melt and new snow for today
            if dtemp[day] < tsnow
                newsnow = drain
                snowmelt = 0.0
            else
                newsnow = 0.0
                snowmelt = km * (dtemp[day] - tsnow)
            end

            # Reduce snowmelt if greater than total snow remaining
            if snowmelt > snowpack
                snowmelt = snowpack
            end

            # Update snowpack store
            snowpack = snowpack + newsnow - snowmelt
            if snowpack > maxdepth
                maxdepth = snowpack
            end

            # Calculate effective water supply (as daily values in mm/day)
            dprec[day] = drain - newsnow
            dmelt[day] = snowmelt

            sum1 += dprec[day] + dmelt[day]
            sum2 += drain
        end
    end

    return SnowResults(dprec, dmelt, maxdepth)
end

end # module

using .Snow

# Example run
dtemp = [rand() * 20.0 - 10.0 for _ in 1:365]
dprecin = [rand() * 10.0 for _ in 1:365]

result = Snow.snow(dtemp, dprecin)
println("dprec: ", result.dprec)
println("dmelt: ", result.dmelt)
println("maxdepth: ", result.maxdepth)
