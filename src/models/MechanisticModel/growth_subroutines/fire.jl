
"""
fire(wet::AbstractVector{T}, pft::U, lai::T, npp::T)::firedays::T, wetday::T, dryday::T, firefraction::T, burnfraction::T

Calculate the number of potential fire days in a year based on threshold values for soil moisture.

# Arguments
- `wet`: A vector of 365 T values representing daily wetness.
- `pft`: An integer representing the Plant Functional Type (PFT).
- `lai`: The Leaf Area Index.
- `npp`: Net Primary Productivity.

# Returns
- A tuple containing:
- `firedays`: Total number of fire days in the year.
- `wetday`: Maximum wetness observed during the year.
- `dryday`: Minimum wetness observed during the year.
- `firefraction`: Fraction of days with fire potential.
- `burnfraction`: Fraction of litter burned based on fire potential.
"""
function fire(wet::AbstractVector{T},
    pft::U,
    lai::T,
    npp::T,
    BIOME4PFTS::AbstractPFTList
)::Tuple{T, T, T, T, T} where {T <: Real, U <: Int}

    # Threshold values per PFT
    threshold = get_threshold(BIOME4PFTS.pft_list[pft])

    # Initialize variables
    firedays = T(0.0)
    wetday = T(0.0)
    dryday = T(100.0)
    burn = zeros(T, 365)

    # Loop through each day of the year
    for day in 1:365
        if wet[day] < threshold
            burn[day] = T(1.0)
        elseif wet[day] > threshold + T(0.05)
            burn[day] = T(0.0)
        else
            burn[day] = T(1.0) / exp(wet[day] - threshold)
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
    return firedays, wetday, dryday, firefraction, burnfraction
end