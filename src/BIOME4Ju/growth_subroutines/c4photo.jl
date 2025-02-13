module C4Photosynthesis

include("./photosynthesis.jl")
using Base.Math: exp
using .Photosynthesis: PhotosynthesisResults

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
)::PhotosynthesisResults{T} where {T <: Real, U <: Int}
    # Constants
    drespc4::T = T(0.03)
    abs1::T = T(1.0)
    teta::T = T(0.7)
    slo2::T = T(20.9e3)
    jtoe::T = T(2.3e-6)
    optratio::T = T(0.95)
    ko25::T = T(30.0e3)
    kc25::T = T(30.0)
    tao25::T = T(2600.0)
    cmass::T = T(12.0)
    kcq10::T = T(2.1)
    koq10::T = T(1.2)
    taoq10::T = T(0.57)
    twigloss::T = T(1.0)
    maxtemp::T = T(55.0)

    # PFT-specific parameters
    # TODO verify that this gives the same result as the original code
    t0 = T(10.0)

    # Determine qeffc4 and tune based on PFT
    qeffc4, tune = if pft in [8, 9]
        (T(0.0633), T(1.0))
    elseif pft == 10
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

    return PhotosynthesisResults(T(leafrespc4), T(grossphotc4), T(adayc4))
end

end # module
