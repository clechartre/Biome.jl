module Daily

"""
    daily(mly::AbstractVector{Float64})::AbstractVector{Float64}

Linearly interpolate the mid-month values (mly) to daily values.

# Arguments
- `mly`: A vector of 12 Float64 values representing mid-month values.

# Returns
- A vector of 365 Float64 values representing daily interpolated values.
"""
function daily(mly::AbstractVector{Float64})::AbstractVector{Float64}
    midday = [
        16.0, 44.0, 75.0, 105.0, 136.0, 166.0,
        197.0, 228.0, 258.0, 289.0, 319.0, 350.0
    ]
    dly = zeros(Float64, 365)

    # Initial vinc calculation and boundary conditions
    vinc = (mly[1] - mly[12]) / 31.0
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

end # module
