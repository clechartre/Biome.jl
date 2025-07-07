"""
    photosynthesis(ratio, dsun, daytime, temp, age, fpar, p, ca, pft)

Calculate C3 photosynthesis based on environmental and plant functional type (PFT) parameters.

# Arguments
- `ratio`: The ratio of intercellular to ambient CO2 concentration.
- `dsun`: Daily solar radiation (MJ/m²/day).
- `daytime`: Length of the day (hours).
- `temp`: Air temperature (°C).
- `age`: Leaf age (months).
- `fpar`: Fraction of photosynthetically active radiation absorbed by the canopy.
- `p`: Atmospheric pressure (kPa).
- `ca`: Ambient CO2 concentration (ppm).
- `pft`: Plant Functional Type (integer index).

# Returns
- `leafresp`: Leaf respiration rate.
- `grossphot`: Gross photosynthesis rate.
- `aday`: Net daily photosynthesis.
"""
function photosynthesis(
    ratio::T,
    dsun::T,
    daytime::T,
    temp::T,
    age::T,
    fpar::T,
    p::T,
    ca::T,
    pft::AbstractPFT
)::Tuple{T,T,T} where {T<:Real}
    # PFT specific parameters
    t0 = get_characteristic(pft, :t0)
    tcurve = get_characteristic(pft, :tcurve)

    # Derived parameters
    leafcost = (age / T(12.0))^T(0.25)
    mfo2 = SLO2 / T(1e5)
    o2 = p * mfo2
    if daytime <= T(4.0)
        daytime = T(4.0)
    end

    # Temperature stress calculation
    mintemp = t0
    tstress = if temp > mintemp + T(1.0)
        tcurve * (T(2.71828)^(-T(10.0) / (temp - mintemp)))
    else
        T(0.0)
    end

    # Temperature adjusted values
    ko = KO25 * (KOQ10^((temp - T(25.0)) / T(10.0)))
    kc = KC25 * (KCQ10^((temp - T(25.0)) / T(10.0)))
    tao = TAO25 * (TAOQ10^((temp - T(25.0)) / T(10.0)))

    s = DRESPC3 * (T(24.0) / daytime)
    ts = o2 / (T(2.0) * tao)
    kk = kc * (T(1.0) + (o2 / ko))
    z = CMASS * JTOE * dsun * fpar * TWIGLOSS * TUNE

    # Calculate optimal vm value based on a ratio of 0.95
    pi = OPTRATIO * ca * p
    c1 = tstress * QEFFC3 * ((pi - ts) / (pi + T(2.0) * ts))
    c2 = (pi - ts) / (pi + kk)
    numerator = s - TETA * s
    denominator = c2 - TETA * s

    oc = if denominator != T(0.0)
        result = numerator / denominator
        if result < T(0.0)
            sign(result) * abs(result)^T(0.5)
        else
            result^T(0.5)
        end
    else
        T(0.0)
    end

    vmax = if z == T(0.0)
        T(0.0)
    else
        (z / DRESPC3) * (c1 / c2) * (
            (T(2.0) * TETA - T(1.0)) * s - (T(2.0) * TETA * s - c2) * oc
        )
    end

    # Actual photosynthesis calculation
    pi = ratio * ca * p

    grossphot = if pi <= ts
        T(0.0)
    else
        c1 = tstress * QEFFC3 * ((pi - ts) / (pi + T(2.0) * ts))
        c2 = (pi - ts) / (pi + kk)

        je = if z == T(0.0)
            T(0.0)
        else
            c1 * z / daytime
        end

        jc = if vmax == T(0.0)
            T(0.0)
        else
            c2 * vmax / T(24.0)
        end

        wif = daytime / (T(2.0) * TETA)

        if je == T(0.0) && jc == T(0.0)
            T(0.0)
        else
            wif * (
                je + jc - (
                    (je + jc)^T(2.0) - T(4.0) * TETA * je * jc
                )^T(0.5)
            )
        end
    end

    adaygc = grossphot - (daytime / T(24.0)) * DRESPC3 * vmax
    leafresp = DRESPC3 * vmax * leafcost
    leafresp = max(leafresp, T(0.0))

    aday = if adaygc == T(0.0)
        T(0.0)
    else
        (adaygc / CMASS) * (T(8.314) * (temp + T(273.3)) / p) * T(1000.0)
    end

    return T(leafresp), T(grossphot), T(aday)
end