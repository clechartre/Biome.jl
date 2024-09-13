module SoilTemperature

"""
Calculate monthly mean soil temperature
based on monthly mean air temperature assuming a thermal
conductivity of the soil and a time lag between soil and air
temperatures. Based on work by S. Sitch.
"""

function soiltemp(tair::AbstractArray{Float64}, soiltext::AbstractArray{Float64})::AbstractArray{Float64}
    pie = 4.0 * atan(1.0)

    therm = [8.0, 4.5, 1.0, 5.25, 4.5, 2.75, 1.0, 1.0, 8.0]
    sumtemp = 0.0

    # Calculate a soil-texture based thermal conductivity and lag time
    diffus = therm[2]
    damp = 0.25 / sqrt(diffus)
    lag = damp * (6 / pie)
    amp = exp(-damp)

    # Calculate mean annual air temperature
    for m in 1:12
        sumtemp += tair[m]
    end
    meantemp = sumtemp / 12.0

    # Calculate soil temperature
    tsoil = zeros(Float64, 12)
    tsoil[1] = (1.0 - amp) * meantemp + amp * (tair[12] + (1.0 - lag) * (tair[1] - tair[12]))

    for m in 2:12
        tsoil[m] = (1.0 - amp) * meantemp + amp * (tair[m - 1] + (1.0 - lag) * (tair[m] - tair[m - 1]))
    end

    # Due to snow cover don't allow soil temp < -10
    for m in 1:12
        if tsoil[m] < -10.0
            tsoil[m] = -10.0
        end
    end

    return tsoil
end

end # module

