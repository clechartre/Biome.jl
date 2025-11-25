"""
    hetresp(pft, nppann, tair, tsoil, aet, moist, isoveg, Rlit, Rfst, Rslo, Rtot, isoR, isoflux, Rmean, meanKlit, meanKsoil)

Model heterotrophic respiration of litter and soil organic carbon
in both a fast and a slow pool. It assumes equilibrium and so decays
all of a given year's NPP. The 13C composition of respired CO2 is also
modeled.

# Arguments
- `pft`: Plant Functional Type.
- `nppann`: Annual Net Primary Productivity.
- `tair`: Array of monthly air temperatures.
- `tsoil`: Array of monthly soil temperatures.
- `aet`: Array of monthly Actual Evapotranspiration values.
- `moist`: Array of monthly soil moisture values.
- `isoveg`: 13C composition of vegetation.
- `Rlit`: Vector for litter respiration values (modified in place).
- `Rfst`: Vector for fast pool respiration values (modified in place).
- `Rslo`: Vector for slow pool respiration values (modified in place).
- `Rtot`: Vector for total respiration values (modified in place).
- `isoR`: Vector for isotope respiration values (modified in place).
- `isoflux`: Vector for isotope flux values (modified in place).
- `Rmean`: Mean respiration value.
- `meanKlit`: Mean litter decay constant.
- `meanKsoil`: Mean soil decay constant.

# Returns
A tuple containing:
- `Rlit`: Monthly litter respiration rates (Vector{T}).
- `Rfst`: Monthly fast pool respiration rates (Vector{T}).
- `Rslo`: Monthly slow pool respiration rates (Vector{T}).
- `Rtot`: Monthly total respiration rates (Vector{T}).
- `isoR`: Monthly isotope respiration values (Vector{T}).
- `isoflux`: Monthly isotope flux values (Vector{T}).
- `Rmean`: Mean annual respiration rate (T).
- `meanKlit`: Mean litter decay constant (T).
- `meanKsoil`: Mean soil decay constant (T).
"""
function hetresp(
    pft::AbstractPFT,
    nppann::T,
    tsoil::AbstractVector{T},
    aet::AbstractVector{T},
    moist::AbstractVector{T},
    isoveg::T,
    Rlit::AbstractVector{T},
    Rfst::AbstractVector{T},
    Rslo::AbstractVector{T},
    Rtot::AbstractVector{T},
    isoR::AbstractVector{T},
    isoflux::AbstractVector{T},
    Rmean::T,
    meanKlit::T,
    meanKsoil::T
)::Tuple{Vector{T},Vector{T},Vector{T},Vector{T},Vector{T},Vector{T},T,T,T} where {T<:Real}

    # Constants and initializations
    isoatm = T(-8.0)
    Plit, Pfst, Pslo = T(0.0), T(0.0), T(0.0)
    Rten = T(1.0)
    Klit = zeros(T, 12)
    Kfst = zeros(T, 12)
    Kslo = zeros(T, 12)
    isolit = zeros(T, 12)
    isofst = zeros(T, 12)
    isoslo = zeros(T, 12)

    if nppann <= T(0.0)
        # If NPP is zero or less, all respiration values should be zero
        return Rlit, Rfst, Rslo, Rtot, isoR, isoflux, Rmean, meanKlit, meanKsoil
    else
        # Partition annual NPP into pools according to Foley strategy
        if isa(pft, BIOME4.TropicalEvergreen) || isa(pft, BIOME4.TropicalDroughtDeciduous)
            Plit = T(0.650) * nppann
            Pfst = T(0.980) * T(0.350) * nppann
            Pslo = T(0.020) * T(0.350) * nppann
        else
            Plit = T(0.700) * nppann
            Pfst = T(0.985) * T(0.300) * nppann
            Pslo = T(0.015) * T(0.300) * nppann
        end

        Klitsum, Kfstsum, Kslosum = T(0.0), T(0.0), T(0.0)

        for m in 1:12
            # Moisture factor
            mfact = T(0.25) + T(0.75) * moist[m]

            # Litter decay
            Klit[m] = T(10.0)^(-T(1.4553) + T(0.0014175) * aet[m])
            Klitsum += Klit[m]

            # Fast and slow soil pool decay
            Kfst[m] = mfact * Rten * exp(T(308.56) * ((T(1.0) / T(56.02)) - (T(1.0) / (tsoil[m] + T(273.0) - T(227.13)))))
            Kfstsum += Kfst[m]

            Kslo[m] = mfact * Rten * exp(T(308.56) * ((T(1.0) / T(56.02)) - (T(1.0) / (tsoil[m] + T(273.0) - T(227.13)))))
            Kslosum += Kslo[m]
        end

        meanKlit = Klitsum / T(12.0)
        meanKsoil = Kfstsum / T(12.0)

        Rmean = T(0.0)

        for m in 1:12
            Rlit[m] = Plit * (Klit[m] / Klitsum)
            Rfst[m] = Pfst * (Kfst[m] / Kfstsum)
            Rslo[m] = Pslo * (Kslo[m] / Kslosum)
            Rtot[m] = Rlit[m] + Rfst[m] + Rslo[m]
            Rmean += Rtot[m] / T(12.0)
        end

        for m in 1:12
            isolit[m] = isoveg - T(0.75)
            isofst[m] = isoveg - T(1.5)
            isoslo[m] = isoveg - T(2.25)
            isoR[m] = ((Plit / nppann) * isolit[m]) + ((Pfst / nppann) * isofst[m]) + ((Pslo / nppann) * isoslo[m])
            isoflux[m] = (isoatm - isoR[m]) * Rtot[m]
        end

        return Rlit, Rfst, Rslo, Rtot, isoR, isoflux, Rmean, meanKlit, meanKsoil
    end
end