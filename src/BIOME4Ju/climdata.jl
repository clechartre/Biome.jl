module ClimateData

"""
Calculate GDDs, TCM, wrin, and total precipitation.
"""

using Dates

struct ClimateResults
    cold::Float64
    warm::Float64
    gdd5::Float64
    gdd0::Float64
    rain::Float64
    alttmin::Float64
end

function climdata(temp::AbstractArray{Float64}, prec::AbstractArray{Float64}, dtemp::AbstractArray{Float64})::ClimateResults
    cold = 100.0
    warm = -100.0
    rain = 0.0

    for m in 1:12
        if temp[m] < cold
            cold = temp[m]
        end
        if temp[m] > warm
            warm = temp[m]
        end
        rain += prec[m]
    end

    gdd10 = 0.0
    gdd5 = 0.0
    gdd0 = 0.0

    for day in 1:365
        minus10 = dtemp[day] - 10.0
        minus5 = dtemp[day] - 5.0
        minus0 = dtemp[day]
        minus10 = max(minus10, 0.0)
        minus5 = max(minus5, 0.0)
        minus0 = max(minus0, 0.0)
        gdd10 += minus10
        gdd5 += minus5
        gdd0 += minus0
    end

    alttmin = (0.006 * cold^2) + (1.316 * cold) - 21.9

    return ClimateResults(cold, warm, gdd5, gdd0, rain, alttmin)
end

end # module

using .ClimateData

# Example run
temp = [0.0, 1.0, 5.0, 10.0, 15.0, 20.0, 25.0, 25.0, 20.0, 15.0, 10.0, 5.0]
prec = [30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0, 110.0, 120.0, 130.0, 140.0]
dtemp = [rand() * 30.0 - 10.0 for _ in 1:365]

result = ClimateData.climdata(temp, prec, dtemp)
println(result)
