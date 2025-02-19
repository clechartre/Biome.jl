module HeterotrophicRespiration

struct HetRespResults{T <: Real}
    Rlit::Vector{T}
    Rfst::Vector{T}
    Rslo::Vector{T}
    Rtot::Vector{T}
    isoR::Vector{T}
    isoflux::Vector{T}
    Rmean::T
    meanKlit::T
    meanKsoil::T
end

"""
    hetresp(pft, nppann, tair, tsoil, aet, moist, isoveg)

Model heterotrophic respiration of litter and soil organic carbon
in both a fast and a slow pool. It assumes equilibrium and so decays
all of a given year's NPP. The 13C composition of respired CO2 is also
modeled.

Arguments:
- `pft`: Plant Functional Type.
- `nppann`: Annual Net Primary Productivity.
- `tair`: Array of monthly air temperatures.
- `tsoil`: Array of monthly soil temperatures.
- `aet`: Array of monthly Actual Evapotranspiration values.
- `moist`: Array of monthly soil moisture values.
- `isoveg`: 13C composition of vegetation.

Returns:
- A `HetRespResults` struct containing respiration and isotope-related results.
"""
function hetresp(
    pft::U,
    nppann::T,
    tair::AbstractArray{T},
    tsoil::AbstractArray{T},
    aet::AbstractArray{T},
    moist::AbstractArray{T},
    isoveg::T,
    Rlit::Vector{T},
    Rfst::Vector{T},
    Rslo::Vector{T},
    Rtot::Vector{T},
    isoR::Vector{T},
    isoflux::Vector{T},
    Rmean::T,
    meanKlit::T,
    meanKsoil::T,
    pftdict
)::HetRespResults{T} where {T <: Real, U <: Int}

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
        return HetRespResults(
            Rlit, Rfst, Rslo, Rtot, isoR, isoflux, Rmean, meanKlit, meanKsoil
        )
    else
        # Partition annual NPP into pools according to Foley strategy
        if pftdict[pft].name == "tropical_evergreen" || pftdict[pft].name == "tropical_drought_deciduous"
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
            Klit[m] = T(10.0) ^ (-T(1.4553) + T(0.0014175) * aet[m])
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

        return HetRespResults(
            Rlit, Rfst, Rslo, Rtot, isoR, isoflux, Rmean, meanKlit, meanKsoil
        )
    end
end

end # module
