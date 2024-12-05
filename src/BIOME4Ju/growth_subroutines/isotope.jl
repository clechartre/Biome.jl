"""Calculate the total fractionation of 13C
as it goes from free air (as 13CO2) to fixed carbon in the leaf.
For use with the BIOME3 model of A. Haxeltine (1996).
There are separate routines for calculating fractionation by both
C3 and C4 plants.  This program is based upon the model used by
Lloyd and Farquhar (1994)."""

module Isotopes

struct IsotopeResult{T <: Real}
    meanC3::T
    meanC4::T
    C3DA::AbstractArray{T}
    C4DA::AbstractArray{T}
end

function isoC3(Cratio::T, Ca::T, temp::T, Rd::T)::T where {T <: Real}
    # Define fractionation parameters
    a = T(4.4)
    es = T(1.1)
    a1 = T(0.7)
    b = T(27.5)
    e = T(0.0)
    f = T(8.0)

    if Rd <= T(0.0)
        Rd = T(0.01)
    end

    leaftemp = T(1.05) * (temp + T(2.5))
    gamma = T(1.54) * leaftemp
    Rd = Rd / (T(86400.0) * T(12.0))
    Catm = Ca * T(1.0e6)
    k = Rd / T(11.0)  # From Farquhar et al. 1982 p. 126

    # Calculate the fractionation
    q = a * (T(1.0) - Cratio + T(0.025))
    r = T(0.075) * (es + a1)
    s = b * (Cratio - T(0.1))
    t = T(0.0)  # (e * Rd / k + f * gamma) / Catm

    DeltaA = q + r + s - t
    delC3 = DeltaA

    return delC3
end

function isoC4(Cratio::T, phi::T, temp::T)::T where {T <: Real}
    # Define fractionation parameters
    a = T(4.4)
    es = T(1.1)
    a1 = T(0.7)
    b3 = T(30.0)

    b4 = T(26.19) - (T(9483.0) / (T(273.2) + temp))

    DeltaA = (
        a * (T(1.0) - Cratio + T(0.0125))
        + T(0.0375) * (es + a1)
        + (b4 + (b3 - es - a1) * phi) * (Cratio - T(0.05))
    )

    delC4 = DeltaA

    return delC4
end

function isotope(
    Cratio::AbstractArray{T},
    Ca::T,
    temp::AbstractArray{T},
    Rd::AbstractArray{T},
    c4month::Vector{Bool},
    mgpp::AbstractArray{T},
    phi::T,
    gpp::T
)::IsotopeResult{T} where {T <: Real}
    wtC3 = T(0.0)
    wtC4 = T(0.0)
    C3DA = zeros(T, 12)
    C4DA = zeros(T, 12)

    for m in 1:12
        if mgpp[m] > T(0.0)
            if Cratio[m] < T(0.05)
                Cratio[m] = T(0.05)
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
            C3DA[m] = T(0.0)
            C4DA[m] = T(0.0)
        end
    end

    meanC3 = gpp != T(0.0) ? wtC3 / gpp : T(0.0)
    meanC4 = gpp != T(0.0) ? wtC4 / gpp : T(0.0)

    return IsotopeResult(meanC3, meanC4, C3DA, C4DA)
end

end # module
