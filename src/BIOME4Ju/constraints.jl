"""Provide environmental sieve."""

module Constraints

using LinearAlgebra: undef

function constraints(
    tcm::Float64,
    twm::Float64,
    tminin::AbstractFloat,
    gdd5::Float64,
    rad0::Float64,
    gdd0::Float64,
    maxdepth::Float64
)::Tuple{Float64, Float64, AbstractArray{Float64}, Vector{Int}}
    npft = 13
    nclin = 6
    undef = -99.9

    limits = [
        [[-99.9, -99.9], [0.0, -99.9], [-99.9, -99.9], [-99.9, -99.9], [10.0, -99.9], [-99.9, -99.9]],
        [[-99.9, -99.9], [0.0, -99.9], [-99.9, -99.9], [-99.9, -99.9], [10.0, -99.9], [-99.9, -99.9]],
        [[-99.9, -99.9], [-8.0, 5.0], [1200.0, -99.9], [-99.9, -99.9], [10.0, -99.9], [-99.9, -99.9]],
        [[-15.0, -99.9], [-99.9, -8.0], [1200.0, -99.9], [-99.9, -99.9], [-99.9, -99.9], [-99.9, -99.9]],
        [[-2.0, -99.9], [-99.9, 10.0], [900.0, -99.9], [-99.9, -99.9], [10.0, -99.9], [-99.9, -99.9]],
        [[-32.5, -2.0], [-99.9, -99.9], [-99.9, -99.9], [-99.9, -99.9], [21.0, -99.9], [-99.9, -99.9]],
        [[-99.9, 5.0], [-99.9, -10.0], [-99.9, -99.9], [-99.9, -99.9], [21.0, -99.9], [-99.9, -99.9]],
        [[-99.9, -99.9], [-99.9, 0.0], [550.0, -99.9], [-99.9, -99.9], [-99.9, -99.9], [-99.9, -99.9]],
        [[-99.9, -99.9], [-3.0, -99.9], [-99.9, -99.9], [-99.9, -99.9], [10.0, -99.9], [-99.9, -99.9]],
        [[-99.9, -99.9], [-45.0, -99.9], [500.0, -99.9], [-99.9, -99.9], [10.0, -99.9], [-99.9, -99.9]],
        [[-99.9, -99.9], [-99.9, -99.9], [-99.9, -99.9], [50.0, -99.9], [15.0, -99.9], [15.0, -99.9]],
        [[-99.9, -99.9], [-99.9, -99.9], [-99.9, -99.9], [50.0, -99.9], [15.0, -99.9], [-99.9, -99.9]],
        [[-99.9, -99.9], [-99.9, -99.9], [-99.9, -99.9], [-99.9, -99.9], [15.0, -99.9], [-99.9, -99.9]]
    ]

    tmin = tminin <= tcm ? tminin : tcm - 5.0
    ts = twm - tcm

    clindex = [tcm, tmin, gdd5, gdd0, twm, maxdepth]
    pfts = zeros(Int, npft)

    for ip in 1:npft
        for iv in 1:nclin
            lower_limit, upper_limit = limits[ip][iv]

            if (
                (lower_limit != undef && upper_limit != undef && lower_limit <= clindex[iv] < upper_limit) ||
                (lower_limit == undef && upper_limit != undef && clindex[iv] < upper_limit) ||
                (lower_limit != undef && upper_limit == undef && lower_limit <= clindex[iv]) ||
                (lower_limit == undef && upper_limit == undef)
            )
                pfts[ip] = 1
            else
                pfts[ip] = 0
                break
            end
        end
    end

    return tmin, ts, clindex, pfts
end

end # module
