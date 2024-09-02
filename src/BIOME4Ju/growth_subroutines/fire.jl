module FireCalculation

"""
    struct FireResult
        firedays::Float64
        wetday::Float64
        dryday::Float64
        firefraction::Float64
        burnfraction::Float64
    end

A struct to store the results of the fire calculation.
"""

struct FireResult
    firedays::Float64
    wetday::Float64
    dryday::Float64
    firefraction::Float64
    burnfraction::Float64
end

"""
    fire(wet::AbstractVector{Float64}, pft::Int, lai::Float64, npp::Float64)::FireResult

Calculate the number of potential fire days in a year based on threshold values for soil moisture.

# Arguments
- `wet`: A vector of 365 Float64 values representing daily wetness.
- `pft`: An integer representing the Plant Functional Type (PFT).
- `lai`: The Leaf Area Index.
- `npp`: Net Primary Productivity.

# Returns
- A `FireResult` struct containing firedays, wetday, dryday, firefraction, and burnfraction.
"""
function fire(wet::AbstractVector{Float64}, pft::Int, lai::Float64, npp::Float64)::FireResult
    threshold = [
        0.25, 0.20, 0.40, 0.33, 0.40, 0.33, 0.33, 0.40,
        0.40, 0.33, 0.33, 0.33, 0.33
    ]
    firedays = 0.0
    wetday = 0.0
    dryday = 100.0
    burn = zeros(Float64, 365)

    for day in 1:365
        if wet[day] < threshold[pft]
            burn[day] = 1.0
        elseif wet[day] > threshold[pft] + 0.05
            burn[day] = 0.0
        else
            burn[day] = 1 / exp(wet[day] - threshold[pft])
        end

        if wet[day] > wetday
            wetday = wet[day]
        end
        if wet[day] < dryday
            dryday = wet[day]
        end

        firedays += burn[day]
    end

    firefraction = firedays / 365.0
    litter = (lai / 5.0) * npp
    burnfraction = litter * (1 - (exp(-0.2 * firefraction^1.5))^1.5)

    if npp < 1000.0
        firedays *= npp / 1000.0
    end

    return FireResult(
        firedays, wetday, dryday, firefraction, burnfraction
    )
end

end # module
