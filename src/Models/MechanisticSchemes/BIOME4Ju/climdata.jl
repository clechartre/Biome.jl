module ClimateData

"""
Calculate GDDs, TCM, wrin, and total precipitation.
"""

using Dates

struct ClimateResults{T <: Real}
    cold::T
    warm::T
    gdd5::T
    gdd0::T
    rain::T
    alttmin::T
end

function climdata(temp::AbstractArray{T},
    prec::AbstractArray{T},
    dtemp::AbstractArray{T}
)::ClimateResults where {T <: Real}

    cold = T(100.0)
    warm = T(-100.0)
    rain = T(0.0)

    for m in 1:12
        if temp[m] < cold
            cold = temp[m]
        end
        if temp[m] > warm
            warm = temp[m]
        end
        rain += prec[m]
    end

    gdd10 = T(0.0)
    gdd5 = T(0.0)
    gdd0 = T(0.0)

    for day in 1:365
        minus10 = dtemp[day] - T(10.0)
        minus5 = dtemp[day] - T(5.0)
        minus0 = dtemp[day]
        minus10 = max(minus10, T(0.0))
        minus5 = max(minus5, T(0.0))
        minus0 = max(minus0, T(0.0))
        gdd10 += minus10
        gdd5 += minus5
        gdd0 += minus0
    end

    alttmin = (T(0.006) * cold^2) + (T(1.316) * cold) - T(21.9)

    return ClimateResults(cold, warm, gdd5, gdd0, rain, alttmin)
end

end # module

