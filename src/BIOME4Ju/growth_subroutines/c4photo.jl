"""Calculate photosynthesis metrics from C4 plants."""

module C4Photosynthesis

include("./photosynthesis.jl")
using Base.Math: exp
using .Photosynthesis: PhotosynthesisResults

function c4photo(
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
    drespc4 = 0.03
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

    # PFT specific parameters
    t0 = fill(10.0, 13)

    # Determine qeffc4 and tune based on PFT
    qeffc4, tune = if pft in [8, 9]
        0.0633, 1.0
    elseif pft == 10
        0.0565, 0.75
    else
        0.0633, 1.0
    end

    # Derived parameters
    leafcost = (age / 12.0) ^ 0.25
    mfo2 = slo2 / 1e5
    o2 = p * mfo2
    if daytime <= 4.0
        daytime = 4.0
    end

    # Temperature stress calculation
    mintemp = t0[pft]
    maxtemp = 55.0
    tstress = if mintemp + 0.1 < temp < maxtemp
        exp(-10.0 / (temp - mintemp))
    else
        0.0
    end    

    tstress = min(tstress, 1.0)

    # Temperature adjusted values
    tao = tao25 * (taoq10 ^ ((temp - 25.0) / 10.0))

    s = drespc4 * (24.0 / daytime)
    ts = o2 / (2.0 * tao)
    z = cmass * jtoe * dsun * fpar * twigloss * tune

    # Optimal pi value and non-co2-dependent parameters
    pi = optratio * ca * p
    c1 = qeffc4 * tstress
    c2 = 1.0
    oc = sqrt((s - teta * s) / (c2 - teta * s))

    # Estimate the optimal value of Vm at ratio=0.8 g(C).m-2.day-1
    vmaxc4 = if z == 0.0
        0.0
    else
        (z / drespc4) * (c1 / c2) * ((2.0 * teta - 1.0) * s - (2.0 * teta * s - c2) * oc)
    end

    # Actual photosynthesis calculation
    grossphotc4 = if pi <= ts
        0.0
    else
        je = if z == 0.0
            0.0
        else
            c1 * z / daytime
        end

        jc = if vmaxc4 == 0.0
            0.0
        else
            c2 * vmaxc4 / 24.0
        end

        damage = ratio < 0.4 ? ratio / 0.4 : 1.0
        wif = damage * daytime / (2.0 * teta)

        if je == 0.0 && jc == 0.0
            0.0
        else
            wif * (je + jc - sqrt((je + jc) ^ 2.0 - 4.0 * teta * je * jc))
        end
    end

    adaygcc4 = grossphotc4 - (daytime / 24.0) * drespc4 * vmaxc4
    leafrespc4 = drespc4 * vmaxc4 * leafcost

    adayc4 = if grossphotc4 == 0.0 && vmaxc4 == 0.0
        0.0
    else
        (adaygcc4 / cmass) * (8.314 * (temp + 273.3) / p) * 1000.0
    end

    return PhotosynthesisResults(leafrespc4, grossphotc4, adayc4)
end

end # module

using .C4Photosynthesis

# # Example run
# ratio = 0.8
# dsun = 5.0
# daytime = 12.0
# temp = 30.0
# age = 6.0
# fpar = 0.5
# p = 101.3
# ca = 400.0
# pft = 8

# result = C4Photosynthesis.c4photo(ratio, dsun, daytime, temp, age, fpar, p, ca, pft)
# println(result)
