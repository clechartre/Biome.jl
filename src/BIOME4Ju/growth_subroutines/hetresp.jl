module HeterotrophicRespiration

struct HetRespResults
    Rlit::AbstractVector{Float64}
    Rfst::AbstractVector{Float64}
    Rslo::AbstractVector{Float64}
    Rtot::AbstractVector{Float64}
    isoR::AbstractVector{Float64}
    isoflux::AbstractVector{Float64}
    Rmean::Float64
    meanKlit::Float64
    meanKsoil::Float64
end

"""
    hetresp(pft, nppann, tair, tsoil, aet, moist, isoveg)

Model heterotrophic respiration of litter and soil organic carbon
in both a fast and a slow pool. It assumes equilibrium and so decays
all of a given year's NPP. The 13C composition of respired CO2 is also
modeled. Models are based on the work of Foley, Lloyd and Taylor, and Sitch.

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
    pft::Int,
    nppann::Float64,
    tair::AbstractVector{Float64},
    tsoil::AbstractVector{Float64},
    aet::AbstractVector{Float64},
    moist::AbstractVector{Float64},
    isoveg::Float64
)::HetRespResults

    # Constants and initializations
    isoatm = -8.0  # Atmospheric 13C composition
    Plit, Pfst, Pslo = 0.0, 0.0, 0.0
    Rten = 1.0
    Rlit = zeros(Float64, 12)
    Rfst = zeros(Float64, 12)
    Rslo = zeros(Float64, 12)
    Rtot = zeros(Float64, 12)
    Klit = zeros(Float64, 12)
    Kfst = zeros(Float64, 12)
    Kslo = zeros(Float64, 12)
    isolit = zeros(Float64, 12)
    isofst = zeros(Float64, 12)
    isoslo = zeros(Float64, 12)
    isoflux = zeros(Float64, 12)
    isoR = zeros(Float64, 12)

    if nppann <= 0.0
        # If NPP is zero or less, all respiration values should be zero
        return HetRespResults(
            Rlit, Rfst, Rslo, Rtot, isoR, isoflux, 0.0, 0.0, 0.0
        )
    else
        # Partition annual NPP into pools according to Foley strategy
        if pft == 1 || pft == 2
            Plit = 0.650 * nppann
            Pfst = 0.980 * 0.350 * nppann
            Pslo = 0.020 * 0.350 * nppann
        else
            Plit = 0.700 * nppann
            Pfst = 0.985 * 0.300 * nppann
            Pslo = 0.015 * 0.300 * nppann
        end

        # Calculate respiration for each pool with an R10 base respiration.
        # Litter decay follows a temperature and moisture function.
        # Soil decay is calculated based on soil temperature and moisture.

        Klitsum, Kfstsum, Kslosum = 0.0, 0.0, 0.0

        for m in 1:12
            # Moisture factor
            mfact = 0.25 + 0.75 * moist[m]

            # Litter decay
            Klit[m] = 1.0 * 10.0 ^ (-1.4553 + 0.0014175 * aet[m])
            Klitsum += Klit[m]

            # Fast and slow soil pool decay
            Kfst[m] = mfact * Rten * exp(308.56 * ((1 / 56.02) - (1 / (tsoil[m] + 273.0 - 227.13))))
            Kfstsum += Kfst[m]

            Kslo[m] = mfact * Rten * exp(308.56 * ((1 / 56.02) - (1 / (tsoil[m] + 273.0 - 227.13))))
            Kslosum += Kslo[m]
        end

        meanKlit = Klitsum / 12.0
        meanKsoil = Kfstsum / 12.0

        Rmean = 0.0

        for m in 1:12
            # Calculate monthly respiration for each pool
            Rlit[m] = Plit * (Klit[m] / Klitsum)
            Rfst[m] = Pfst * (Kfst[m] / Kfstsum)
            Rslo[m] = Pslo * (Kslo[m] / Kslosum)
            Rtot[m] = Rlit[m] + Rfst[m] + Rslo[m]
            Rmean += Rtot[m] / 12.0
        end

        for m in 1:12
            # Calculate the isotope ratio of respired CO2 based on NPP weighted mean 13C
            isolit[m] = isoveg - 0.75  # 13C enrichment factors
            isofst[m] = isoveg - 1.5
            isoslo[m] = isoveg - 2.25
            isoR[m] = ((Plit / nppann) * isolit[m]) + ((Pfst / nppann) * isofst[m]) + ((Pslo / nppann) * isoslo[m])
            isoflux[m] = (isoatm - isoR[m]) * Rtot[m]
        end

        return HetRespResults(
            Rlit, Rfst, Rslo, Rtot, isoR, isoflux, Rmean, meanKlit, meanKsoil
        )
    end
end

end # module

using .HeterotrophicRespiration

# # Example run
# pft = 1
# nppann = 1200.0
# tair = [15.0 for _ in 1:12]
# tsoil = [10.0 for _ in 1:12]
# aet = [50.0 for _ in 1:12]
# moist = [0.5 for _ in 1:12]
# isoveg = -25.0

# result = HeterotrophicRespiration.hetresp(pft, nppann, tair, tsoil, aet, moist, isoveg)
# println(result)
