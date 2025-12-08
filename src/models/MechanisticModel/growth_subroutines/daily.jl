"""
    daily_interp!(dly, mly)

Fully allocation-free. Caller provides a 365-element workspace `dly`.
"""
function daily_interp!(
    dly::AbstractVector{T},
    mly::AbstractVector{T}
) where {T<:Real}

    @assert length(mly) == 12
    @assert length(dly) == 365

    @inbounds midday = T.(MIDDAY_365)

    # Wrap-around Dec→Jan
    vinc = (mly[1] - mly[12]) / T(31)

    dly[350] = mly[12]
    @inbounds for id in 351:365
        dly[id] = dly[id - 1] + vinc
    end

    dly[1] = dly[365] + vinc
    @inbounds for id in 2:15
        dly[id] = dly[id - 1] + vinc
    end

    # Midpoint interpolation loops
    @inbounds for im in 1:11
        startd = Int(midday[im])
        endd   = Int(midday[im+1])
        vinc   = (mly[im+1] - mly[im]) / (midday[im+1] - midday[im])

        dly[startd] = mly[im]

        for id in startd+1:endd-1
            dly[id] = dly[id - 1] + vinc
        end
    end

    return dly
end
