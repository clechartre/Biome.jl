include("./photosynthesis.jl")
include("../../constants.jl")
using Base.Math: exp
using .Photosynthesis: PhotosynthesisResults
using .Constants: MAXTEMP, TAO25, TAOQ10, SLO2, JTOE, OPTRATIO, CMASS, TWIGLOSS, TUNE
"""
    c4photo(ratio, dsun, daytime, temp, age, fpar, p, ca, pft) :: PhotosynthesisResults
Calculate C4 photosynthesis based on environmental and plant functional type (PFT) parameters.
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
- `leafresp`: Leaf respiration rate.
- `grossphot`: Gross photosynthesis rate.
- `aday`: Net daily photosynthesis.
"""
function c4photo(
    ratio::T,
    dsun::T,
    daytime::T,
    temp::T,
    age::T,
    fpar::T,
    p::T,
    ca::T,
    pft::U,
    BIOME4PFTS::AbstractPFTList,
)::Tuple{T,T,T} where {T <: Real, U <: Int}
    # PFT-specific parameters
    # TODO verify that this gives the same result as the original code
    t0 = T(10.0)

    # Determine qeffc4 and tune based on PFT
    # FIXME this is a bit of a hack, we should have a better way to handle PFT-specific parameters - ask if C4 and then define these parameters in C4 plants
    qeffc4, tune = if get_name(BIOME4PFTS, pft) in ["C3_C4_temperate_grass", "C4_tropical_grass"]
        (T(0.0633), T(1.0))
    elseif get_name(BIOME4PFTS, pft) == "C3_C4_woody_desert"
        (T(0.0565), T(0.75))
    else
        println("Running the c4 photosynthesis routine with a non-c4 PFT")
    end

    # Derived parameters
    leafcost = (age / T(12.0)) ^ T(0.25)
    mfo2 = slo2 / T(1e5)
    o2 = p * mfo2
    daytime = max(daytime, T(4.0))

    # Temperature stress calculation
    mintemp = t0
    tstress = if mintemp + T(1) < temp < maxtemp
        exp(-T(10.0) / (temp - mintemp))
    else
        T(0.0)
    end
    tstress = min(tstress, T(1.0))

    # Temperature adjusted values
    tao = tao25 * (taoq10 ^ ((temp - T(25.0)) / T(10.0)))

    s = drespc4 * (T(24.0) / daytime)
    ts = o2 / (T(2.0) * tao)
    z = cmass * jtoe * dsun * fpar * twigloss * tune

    # Optimal pi value and non-co2-dependent parameters
    pi = optratio * ca * p
    c1 = qeffc4 * tstress
    c2 = T(1.0)
    oc = sqrt((s - teta * s) / (c2 - teta * s))

    # Estimate the optimal value of Vm at ratio = 0.8 g(C).m-2.day-1
    vmaxc4 = if z == T(0.0)
        T(0.0)
    else
        (z / drespc4) * (c1 / c2) * ((T(2.0) * teta - T(1.0)) * s - (T(2.0) * teta * s - c2) * oc)
    end

    # Actual photosynthesis calculation
    grossphotc4 = if pi <= ts
        T(0.0)
    else
        je = if z == T(0.0)
            T(0.0)
        else
            c1 * z / daytime
        end

        jc = if vmaxc4 == T(0.0)
            T(0.0)
        else
            c2 * vmaxc4 / T(24.0)
        end

        damage = ratio < T(0.4) ? ratio / T(0.4) : T(1.0)
        wif = damage * daytime / (T(2.0) * teta)

        if je == T(0.0) && jc == T(0.0)
            T(0.0)
        else
            wif * (je + jc - sqrt((je + jc) ^ T(2.0) - T(4.0) * teta * je * jc))
        end
    end

    adaygcc4 = grossphotc4 - (daytime / T(24.0)) * drespc4 * vmaxc4
    leafrespc4 = drespc4 * vmaxc4 * leafcost

    adayc4 = if grossphotc4 == T(0.0) && vmaxc4 == T(0.0)
        T(0.0)
    else
        (adaygcc4 / cmass) * (T(8.314) * (temp + T(273.3)) / p) * T(1000.0)
    end

    return T(leafrespc4), T(grossphotc4), T(adayc4)
end
