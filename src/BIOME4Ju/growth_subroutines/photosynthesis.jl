module Photosynthesis

using ComponentArrays: ComponentArray

struct PhotosynthesisResults{T <: Real}
    leafresp::T
    grossphot::T
    aday::T
end

"""
    photosynthesis(ratio, dsun, daytime, temp, age, fpar, p, ca, pft) :: PhotosynthesisResults

Calculate C3 photosynthesis based on environmental and plant functional type (PFT) parameters.

Arguments:
- `ratio`: The ratio of intercellular to ambient CO2 concentration.
- `dsun`: Daily solar radiation (MJ/m²/day).
- `daytime`: Length of the day (hours).
- `temp`: Air temperature (°C).
- `age`: Leaf age (months).
- `fpar`: Fraction of photosynthetically active radiation absorbed by the canopy.
- `p`: Atmospheric pressure (kPa).
- `ca`: Ambient CO2 concentration (ppm).
- `pft`: Plant Functional Type (integer index).

Returns:
- `PhotosynthesisResults`: A struct containing:
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
    pft::U,
    pft_dict::ComponentArray
)::PhotosynthesisResults{T} where {T <: Real, U <: Int}
    # Constants
    qeffc3 = T(0.08)
    drespc3 = T(0.015)
    abs1 = T(1.0)
    teta = T(0.7)
    slo2 = T(20.9e3)
    jtoe = T(2.3e-6)
    optratio = T(0.95)
    ko25 = T(30.0e3)
    kc25 = T(30.0)
    tao25 = T(2600.0)
    cmass = T(12.0)
    kcq10 = T(2.1)
    koq10 = T(1.2)
    taoq10 = T(0.57)
    twigloss = T(1.0)
    tune = T(1.0)
    leafresp = T(0.0)

    # PFT specific parameters
    t0 = [pft_dict[plant_type].additional_params.t0 for plant_type in keys(pft_dict)]
    tcurve = [pft_dict[plant_type].additional_params.tcurve for plant_type in keys(pft_dict)]

    # Derived parameters
    leafcost = (age / T(12.0)) ^ T(0.25)
    mfo2 = slo2 / T(1e5)
    o2 = p * mfo2
    if daytime <= T(4.0)
        daytime = T(4.0)
    end

    # Temperature stress calculation
    mintemp = t0[pft]
    tstress = if temp > mintemp + T(1.0)
        tcurve[pft] * (T(2.71828) ^ (-T(10.0) / (temp - mintemp)))
    else
        T(0.0)
    end

    # Temperature adjusted values
    ko = ko25 * (koq10 ^ ((temp - T(25.0)) / T(10.0)))
    kc = kc25 * (kcq10 ^ ((temp - T(25.0)) / T(10.0)))
    tao = tao25 * (taoq10 ^ ((temp - T(25.0)) / T(10.0)))

    s = drespc3 * (T(24.0) / daytime)
    ts = o2 / (T(2.0) * tao)
    kk = kc * (T(1.0) + (o2 / ko))
    z = cmass * jtoe * dsun * fpar * twigloss * tune

    # Calculate optimal vm value based on a ratio of 0.95
    pi = optratio * ca * p
    c1 = tstress * qeffc3 * ((pi - ts) / (pi + T(2.0) * ts))
    c2 = (pi - ts) / (pi + kk)
    numerator = s - teta * s
    denominator = c2 - teta * s

    oc = if denominator != T(0.0)
        result = numerator / denominator
        if result < T(0.0)
            sign(result) * abs(result) ^ T(0.5)
        else
            result ^ T(0.5)
        end
    else
        T(0.0)
    end

    vmax = if z == T(0.0)
        T(0.0)
    else
        (z / drespc3) * (c1 / c2) * ((T(2.0) * teta - T(1.0)) * s - (T(2.0) * teta * s - c2) * oc)
    end

    # Actual photosynthesis calculation
    pi = ratio * ca * p

    grossphot = if pi <= ts
        T(0.0)
    else
        c1 = tstress * qeffc3 * ((pi - ts) / (pi + T(2.0) * ts))
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

        wif = daytime / (T(2.0) * teta)

        if je == T(0.0) && jc == T(0.0)
            T(0.0)
        else
            wif * (je + jc - ((je + jc) ^ T(2.0) - T(4.0) * teta * je * jc) ^ T(0.5))
        end
    end

    adaygc = grossphot - (daytime / T(24.0)) * drespc3 * vmax
    leafresp = drespc3 * vmax * leafcost
    leafresp = max(leafresp, T(0.0))

    aday = if adaygc == T(0.0)
        T(0.0)
    else
        (adaygc / cmass) * (T(8.314) * (temp + T(273.3)) / p) * T(1000.0)
    end

    return PhotosynthesisResults(T(leafresp), T(grossphot), T(aday))
end

end # module
