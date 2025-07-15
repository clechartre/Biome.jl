"""
Calculate the total fractionation of 13C as it goes from free air (as 13CO2) to 
fixed carbon in the leaf. For use with the BIOME3 model of A. Haxeltine (1996).
There are separate routines for calculating fractionation by both C3 and C4 plants.
This program is based upon the model used by Lloyd and Farquhar (1994).
"""

"""
    isoC3(Cratio, Ca, temp, Rd)

Calculate the isotopic fractionation for C3 plants based on the given parameters.

# Arguments
- `Cratio`: The ratio of intercellular to ambient CO2 concentration.
- `Ca`: Ambient CO2 concentration (ppm).
- `temp`: Air temperature (°C).
- `Rd`: Daytime respiration rate (µmol m⁻² s⁻¹).

# Returns
- `delC3`: The isotopic fractionation value for C3 plants.
"""
function isoC3(Cratio::T, Ca::T, temp::T, Rd::T)::T where {T<:Real}
    if Rd <= T(0.0)
        Rd = T(0.01)
    end

    leaftemp = T(1.05) * (temp + T(2.5))
    gamma = T(1.54) * leaftemp
    Rd = Rd / (T(86400.0) * T(12.0))
    Catm = Ca * T(1.0e6)
    k = Rd / T(11.0)  # From Farquhar et al. 1982 p. 126

    # Calculate the fractionation
    q = A * (T(1.0) - Cratio + T(0.025))
    r = T(0.075) * (ES + A1)
    s = B * (Cratio - T(0.1))
    t = T(0.0)  # (e * Rd / k + f * gamma) / Catm

    DeltaA = q + r + s - t
    delC3 = DeltaA

    return delC3
end

"""
    isoC4(Cratio, phi, temp)

Calculate the isotopic fractionation for C4 plants based on the given parameters.

# Arguments
- `Cratio`: The ratio of intercellular to ambient CO2 concentration.
- `phi`: Maximum quantum yield of photosynthesis.
- `temp`: Air temperature (°C).

# Returns
- `delC4`: The isotopic fractionation value for C4 plants.
"""
function isoC4(Cratio::T, phi::T, temp::T)::T where {T<:Real}
    b4 = T(26.19) - (T(9483.0) / (T(273.2) + temp))

    DeltaA = (
        A * (T(1.0) - Cratio + T(0.0125))
        + T(0.0375) * (ES + A1)
        + (b4 + (B3 - ES - A1) * phi) * (Cratio - T(0.05))
    )

    delC4 = DeltaA

    return delC4
end

"""
    isotope(Cratio, Ca, temp, Rd, c4month, mgpp, phi, gpp)

Calculate the total fractionation of 13C as it goes from free air (as 13CO2) to 
fixed carbon in the leaf. For use with the BIOME3 model of A. Haxeltine (1996).
There are separate routines for calculating fractionation by both C3 and C4 plants.
This program is based upon the model used by Lloyd and Farquhar (1994).

# Arguments
- `Cratio`: Monthly ratios of intercellular to ambient CO2 concentration.
- `Ca`: Ambient CO2 concentration (ppm).
- `temp`: Monthly air temperatures (°C).
- `Rd`: Monthly daytime respiration rates (µmol m⁻² s⁻¹).
- `c4month`: Boolean vector indicating C4 photosynthesis months.
- `mgpp`: Monthly gross primary productivity values.
- `phi`: Maximum quantum yield of photosynthesis.
- `gpp`: Annual gross primary productivity.

# Returns
A tuple containing:
- `meanC3`: Mean C3 isotopic fractionation weighted by GPP.
- `meanC4`: Mean C4 isotopic fractionation weighted by GPP.
- `C3DA`: Monthly C3 isotopic fractionation values.
- `C4DA`: Monthly C4 isotopic fractionation values.
"""
function isotope(
    Cratio::AbstractArray{T},
    Ca::T,
    temp::AbstractArray{T},
    Rd::AbstractArray{T},
    c4month::Vector{Bool},
    mgpp::AbstractArray{T},
    phi::T,
    gpp::T
)::Tuple{T,T,AbstractArray{T},AbstractArray{T}} where {T<:Real}
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

    return meanC3, meanC4, C3DA, C4DA
end