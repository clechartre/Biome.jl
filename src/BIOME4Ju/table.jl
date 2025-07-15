module Table

"""
Extract Gamma and Lambda based on temperature.

Looks up gamma and lambda from the table based on the given temperature (tc).

Author: Wolfgang Cramer, Dept. of Geography, Trondheim University-AVH,
N-7055 Dragvoll, Norway.
Latest revisions 14/2-1991

Args:
    tc (T): Temperature for which gamma and lambda are looked up.

Returns:
    Tuple{T, T}: gamma and lambda values based on the provided temperature.
"""

function table(tc::T)::Tuple{T, T} where {T <: Real}
    gbase = [
        (-5.0, 64.6),
        (0.0, 64.9),
        (5.0, 65.2),
        (10.0, 65.6),
        (15.0, 65.9),
        (20.0, 66.1),
        (25.0, 66.5),
        (30.0, 66.8),
        (35.0, 67.2),
        (40.0, 67.5),
        (45.0, 67.8)
    ]

    lbase = [
        (-5.0, 2.513),
        (0.0, 2.501),
        (5.0, 2.489),
        (10.0, 2.477),
        (15.0, 2.465),
        (20.0, 2.454),
        (25.0, 2.442),
        (30.0, 2.430),
        (35.0, 2.418),
        (40.0, 2.406),
        (45.0, 2.394)
    ]

    # Temperature above highest value - set highest gamma and lambda and return
    if tc > gbase[end][1]
        gamma = T(gbase[end][2])
        lambda_val = T(lbase[end][2])
        return gamma, lambda_val
    end

    # Temperature at or below value - set gamma and lambda
    for (gb, lb) in zip(gbase, lbase)
        if tc <= gb[1]
            gamma = T(gb[2])
            lambda_val = T(lb[2])
            return gamma, lambda_val
        end
    end

    # If the temperature doesn't fall within the table, return nothing
    return nothing, nothing
end

end # module
