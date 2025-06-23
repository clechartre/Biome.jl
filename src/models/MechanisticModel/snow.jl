module Snow

using Dates

function snow(dtemp::AbstractArray{T}, dprecin::AbstractArray{T})::Tuple{AbstractArray{T}, AbstractArray{T}, T} where {T <: Real}
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

            sum1 += dprec[day]+dmelt[day]
            sum2 += drain 
        end
    end

    return dprec, dmelt, maxdepth
end

end # module
