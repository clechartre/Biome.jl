"""
    daily(mly::Vector{T})

Linearly interpolate the mid-month values (mly) to daily values, modifying `dly` in place.

# Arguments
- `mly`: A vector of 12 T values representing mid-month values.

# Returns
- `dly`:  A vector of 365T values representing daily interpolated values.
"""
function daily(mly::AbstractArray{T})::AbstractArray{T} where {T<:Real}
    # Ensure mly has 12 elements
    if length(mly) != 12
        error("mly must be of length 12")
    end
    dly = zeros(T, 365)

    # Initialize midday values
    midday = T[
        16.0, 44.0, 75.0, 105.0, 136.0, 166.0,
        197.0, 228.0, 258.0, 289.0, 319.0, 350.0
    ]

    # Initial vinc calculation and boundary conditions
    vinc = (mly[1] - mly[12]) / T(31.0)

    dly[350] = mly[12]
    for id in 351:365
        dly[id] = dly[id - 1] + vinc
    end
    dly[1] = dly[365] + vinc
    for id in 2:15
        dly[id] = dly[id - 1] + vinc
    end

    # Interpolation between midpoints
    for im in 1:11
        vinc = (mly[im + 1] - mly[im]) / (midday[im + 1] - midday[im])
        dly[Int(midday[im])] = mly[im]
        for id in Int(midday[im]) + 1:Int(midday[im + 1]) - 1
            dly[id] = dly[id - 1] + vinc
        end
    end

    return dly
end