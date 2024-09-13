"""Calculate the total fractionation of 13C
as it goes from free air (as 13CO2) to fixed carbon in the leaf.
For use with the BIOME3 model of A. Haxeltine (1996).
There are separate routines for calculating fractionation by both
C3 and C4 plants.  This program is based upon the model used by
Lloyd and Farquhar (1994)."""

module Isotopes

struct IsotopeResult
    meanC3::Float64
    meanC4::Float64
    C3DA::AbstractArray{Float64}
    C4DA::AbstractArray{Float64}
end

function isoC3(Cratio::Float64, Ca::Float64, temp::Float64, Rd::Float64)::Float64
    # Define fractionation parameters
    a = 4.4
    es = 1.1
    a1 = 0.7
    b = 27.5
    e = 0.0
    f = 8.0

    if Rd <= 0
        Rd = 0.01
    end

    leaftemp = 1.05 * (temp + 2.5)
    gamma = 1.54 * leaftemp
    Rd = Rd / (86400.0 * 12.0)
    Catm = Ca * 1.0e6
    k = Rd / 11.0  # From Farquhar et al. 1982 p. 126

    # Calculate the fractionation
    q = a * (1 - Cratio + 0.025)
    r = 0.075 * (es + a1)
    s = b * (Cratio - 0.1)
    t = 0.0  # (e * Rd / k + f * gamma) / Catm

    DeltaA = q + r + s - t
    delC3 = DeltaA

    return delC3
end

function isoC4(Cratio::Float64, phi::Float64, temp::Float64)::Float64
    # Define fractionation parameters
    a = 4.4
    es = 1.1
    a1 = 0.7
    b3 = 30.0

    b4 = 26.19 - (9483 / (273.2 + temp))

    DeltaA = (
        a * (1 - Cratio + 0.0125)
        + 0.0375 * (es + a1)
        + (b4 + (b3 - es - a1) * phi) * (Cratio - 0.05)
    )

    delC4 = DeltaA

    return delC4
end

function isotope(
    Cratio::AbstractArray{Float64},
    Ca::Float64,
    temp::AbstractArray{Float64},
    Rd::AbstractArray{Float64},
    c4month::Vector{Bool},
    mgpp::AbstractArray{Float64},
    phi::Float64,
    gpp::Float64
)::IsotopeResult
    wtC3 = 0.0
    wtC4 = 0.0
    C3DA = zeros(Float64, 12)
    C4DA = zeros(Float64, 12)

    for m in 1:12
        if mgpp[m] > 0.0
            if Cratio[m] < 0.05
                Cratio[m] = 0.05
            end

            if c4month[m]
                delC4 = isoC4(Cratio[m], phi, temp[m])
                C4DA[m] = delC4
                wtC4 += delC4 * mgpp[m]
            else
                delC3 = isoC3(Cratio[m], Ca, temp[m], Rd[m])
                C3DA[m] = delC3
                wtC3 += delC3 * mgpp[m]
            end
        else
            C3DA[m] = 0.0
            C4DA[m] = 0.0
        end
    end

    meanC3 = gpp != 0 ? wtC3 / gpp : 0.0
    meanC4 = gpp != 0 ? wtC4 / gpp : 0.0

    return IsotopeResult(meanC3, meanC4, C3DA, C4DA)
end

end # module
