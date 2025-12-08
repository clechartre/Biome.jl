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

    isoatm = T(-8)
    if nppann <= T(0)
        return Rlit, Rfst, Rslo, Rtot, isoR, isoflux, Rmean, meanKlit, meanKsoil
    end

    Plit = zero(T)
    Pfst = zero(T)
    Pslo = zero(T)

    # PFT-dependent partitioning (Foley strategy)
    if isa(pft, BIOME4.TropicalEvergreen) || isa(pft, BIOME4.TropicalDroughtDeciduous)
        Plit = T(0.650) * nppann
        Pfst = T(0.980) * T(0.350) * nppann
        Pslo = T(0.020) * T(0.350) * nppann
    else
        Plit = T(0.700) * nppann
        Pfst = T(0.985) * T(0.300) * nppann
        Pslo = T(0.015) * T(0.300) * nppann
    end

    Klitsum = zero(T)
    Kfstsum = zero(T)
    Kslosum = zero(T)
    Rten = one(T)

    @inbounds for m in 1:12
        mfact = T(0.25) + T(0.75) * moist[m]

        # Litter decay coefficient
        kl = T(10)^(-T(1.4553) + T(0.0014175) * aet[m])
        Rlit[m] = kl
        Klitsum += kl

        # Soil decay coefficient
        ksoil = mfact * Rten *
            exp(T(308.56) * ( (T(1)/T(56.02)) -
                              (T(1)/(tsoil[m] + T(273) - T(227.13))) ))

        Rfst[m] = ksoil
        Rslo[m] = ksoil

        Kfstsum += ksoil
        Kslosum += ksoil
    end

    meanKlit  = Klitsum / T(12)
    meanKsoil = Kfstsum / T(12)

    Rmean = zero(T)

    @inbounds for m in 1:12
        Rlit[m] = Plit * (Rlit[m] / Klitsum)
        Rfst[m] = Pfst * (Rfst[m] / Kfstsum)
        Rslo[m] = Pslo * (Rslo[m] / Kslosum)

        Rtot[m] = Rlit[m] + Rfst[m] + Rslo[m]
        Rmean  += Rtot[m] / T(12)
    end

    isolit = isoveg - T(0.75)
    isofst = isoveg - T(1.5)
    isoslo = isoveg - T(2.25)

    @inbounds for m in 1:12
        isoR[m] = (Plit/nppann)*isolit +
                  (Pfst/nppann)*isofst +
                  (Pslo/nppann)*isoslo

        isoflux[m] = (isoatm - isoR[m]) * Rtot[m]
    end

    return Rlit, Rfst, Rslo, Rtot, isoR, isoflux, Rmean, meanKlit, meanKsoil
end
