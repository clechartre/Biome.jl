module FireCalculation

struct FireResult{T <: Real}
    firedays::T
    wetday::T
    dryday::T
    firefraction::T
    burnfraction::T
end

"""
    fire(wet::AbstractVector{T}, pft::U, lai::T, npp::T)::FireResult{T}

Calculate the number of potential fire days in a year based on threshold values for soil moisture.

# Arguments
- `wet`: A vector of 365 T values representing daily wetness.
- `pft`: An integer representing the Plant Functional Type (PFT).
- `lai`: The Leaf Area Index.
- `npp`: Net Primary Productivity.

# Returns
- A `FireResult` struct containing firedays, wetday, dryday, firefraction, and burnfraction.
"""
function fire(wet::AbstractVector{T}, pft::U, lai::T, npp::T)::FireResult{T} where {T <: Real, U <: Int}

    # Threshold values per PFT
    threshold = T[
        0.25, 0.20, 0.40, 0.33, 0.40, 0.33, 0.33, 0.40,
        0.40, 0.33, 0.33, 0.33, 0.33
    ]

    # Initialize variables
    firedays = T(0.0)
    wetday = T(0.0)
    dryday = T(100.0)
    burn = zeros(T, 365)

    # Loop through each day of the year
    for day in 1:365
        if wet[day] < threshold[pft]
            burn[day] = T(1.0)
        elseif wet[day] > threshold[pft] + T(0.05)
            burn[day] = T(0.0)
        else
            burn[day] = T(1.0) / exp(wet[day] - threshold[pft])
        end

        # Update wetday and dryday
        wetday = max(wetday, wet[day])
        dryday = min(dryday, wet[day])

        # Accumulate firedays
        firedays += burn[day]
    end

    # Calculate fire fraction and burn fraction
    firefraction = firedays / T(365.0)
    litter = (lai / T(5.0)) * npp
    burnfraction = litter * (T(1.0) - (exp(-T(0.2) * firefraction^T(1.5)))^T(1.5))

    # Adjust firedays based on NPP
    if npp < T(1000.0)
        firedays *= npp / T(1000.0)
    end

    # Return results as a FireResult
    return FireResult(
        firedays, wetday, dryday, firefraction, burnfraction
    )
end

end # module
