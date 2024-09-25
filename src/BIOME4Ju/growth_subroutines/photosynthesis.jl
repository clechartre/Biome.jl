module Photosynthesis

struct PhotosynthesisResults
    leafresp::Float64
    grossphot::Float64
    aday::Float64
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
    ratio::Float64,
    dsun::Float64,
    daytime::Float64,
    temp::Float64,
    age::Float64,
    fpar::Float64,
    p::Real,
    ca::Float64,
    pft::Int
)::PhotosynthesisResults
    # Constants
    qeffc3 = 0.08
    drespc3 = 0.015
    abs1 = 1.0
    teta = 0.7
    slo2 = 20.9 * 1e3
    jtoe = 2.3 * 1e-6
    optratio = 0.95
    ko25 = 30.0 * 1e3
    kc25 = 30.0
    tao25 = 2600.0
    cmass = 12.0
    kcq10 = 2.1
    koq10 = 1.2
    taoq10 = 0.57
    twigloss = 1.0
    tune = 1.0

    # PFT specific parameters
    t0 = [10.0, 10.0, 5.0, 4.0, 3.0, 0.0, 0.0, 4.5, 10.0, 5.0, -7.0, -7.0, -12.0]
    tcurve = [1.0, 1.0, 1.0, 1.0, 0.9, 0.8, 0.8, 1.0, 1.0, 1.0, 0.6, 0.6, 0.5]

    # Derived parameters
    leafcost = (age / 12.0) ^ 0.25
    mfo2 = slo2 / 1e5
    o2 = p * mfo2
    if daytime <= 4.0
        daytime = 4.0
    end

    # Temperature stress calculation
    mintemp = t0[pft]
    tstress = if temp > mintemp + 1
        tcurve[pft] * (2.71828 ^ (-10.0 / (temp - mintemp)))
    else
        0.0
    end

    # Temperature adjusted values
    ko = ko25 * (koq10 ^ ((temp - 25.0) / 10.0))
    kc = kc25 * (kcq10 ^ ((temp - 25.0) / 10.0))
    tao = tao25 * (taoq10 ^ ((temp - 25.0) / 10.0))

    s = drespc3 * (24.0 / daytime)
    ts = o2 / (2.0 * tao)
    kk = kc * (1.0 + (o2 / ko))
    z = cmass * jtoe * dsun * fpar * twigloss * tune

    # Calculate optimal vm value based on a ratio of 0.95
    pi = optratio * ca * p
    c1 = tstress * qeffc3 * ((pi - ts) / (pi + 2.0 * ts))
    c2 = (pi - ts) / (pi + kk)
    numerator = s - teta * s
    denominator = c2 - teta * s

    oc = if denominator != 0
        result = numerator / denominator
        if result < 0
            sign(result) * abs(result) ^ 0.5
        else
            result ^ 0.5
        end
    else
        0.0
    end

    vmax = if z == 0.0
        0.0
    else
        (z / drespc3) * (c1 / c2) * ((2.0 * teta - 1.0) * s - (2.0 * teta * s - c2) * oc)
    end

    # Actual photosynthesis calculation
    pi = ratio * ca * p

    grossphot = if pi <= ts
        0.0
    else
        c1 = tstress * qeffc3 * ((pi - ts) / (pi + 2.0 * ts))
        c2 = (pi - ts) / (pi + kk)

        je = if z == 0.0
            0.0
        else
            c1 * z / daytime
        end

        jc = if vmax == 0.0
            0.0
        else
            c2 * vmax / 24.0
        end

        wif = daytime / (2.0 * teta)

        if je == 0.0 && jc == 0.0
            0.0
        else
            wif * (je + jc - ((je + jc) ^ 2.0 - 4.0 * teta * je * jc) ^ 0.5)
        end
    end

    adaygc = grossphot - (daytime / 24.0) * drespc3 * vmax
    leafresp = drespc3 * vmax * leafcost
    leafresp = max(leafresp, 0.0)

    aday = if adaygc == 0.0
        0.0
    else
        (adaygc / cmass) * (8.314 * (temp + 273.3) / p) * 1000.0
    end

    return PhotosynthesisResults(leafresp, grossphot, aday)
end

end # module
