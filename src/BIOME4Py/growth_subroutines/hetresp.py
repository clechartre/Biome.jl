"""Model heterotrophic respiration of litter and soil
organic carbon in both a fast and a slow pool.  It assumes equilibrium
and so decays all of a given year's NPP.  The 13C composition of respired
CO2 is also modelled.  Models are based on the work of Foley, Lloyd and
Taylor, and Sitch."""

# Standard library
import math
from dataclasses import dataclass
from typing import List


@dataclass
class HetRespResults:
    Rlit: List[float]
    Rfst: List[float]
    Rslo: List[float]
    Rtot: List[float]
    isoR: List[float]
    isoflux: List[float]
    Rmean: float
    meanKlit: float
    meanKsoil: float


def hetresp(
    pft: int,
    nppann: float,
    tair: List[float],
    tsoil: List[float],
    aet: List[float],
    moist: List[float],
    isoveg: float,
) -> HetRespResults:
    isoatm = -8.0
    # P is pool sizes for partitioning,
    # R is respired CO2
    # The soil temp subroutine must have been called by now
    Plit, Pfst, Pslo = 0.0, 0.0, 0.0
    Rten = 1.0
    # Initialize storage
    Rlit = [0.0] * 12
    Rfst = [0.0] * 12
    Rslo = [0.0] * 12
    Rtot = [0.0] * 12
    Klit = [0.0] * 12
    Kfst = [0.0] * 12
    Kslo = [0.0] * 12
    isolit = [0.0] * 12
    isofst = [0.0] * 12
    isoslo = [0.0] * 12
    isoflux = [0.0] * 12
    isoR = [0.0] * 12

    if nppann <= 0.0:
        Rlit = [0.0] * 12
        Rfst = [0.0] * 12
        Rslo = [0.0] * 12
        Rtot = [0.0] * 12
        isoR = [0.0] * 12
        isoflux = [0.0] * 12
        isoveg = 0
        return HetRespResults(
            Rlit=Rlit,
            Rfst=Rfst,
            Rslo=Rslo,
            Rtot=Rtot,
            isoR=isoR,
            isoflux=isoflux,
            Rmean=0,
            meanKlit=0,
            meanKsoil=0,
        )
    else:
        if pft == 1 or pft == 2:
            Plit = 0.650 * nppann
            Pfst = 0.980 * 0.350 * nppann
            Pslo = 0.020 * 0.350 * nppann
        else:
            Plit = 0.700 * nppann
            Pfst = 0.985 * 0.300 * nppann
            Pslo = 0.015 * 0.300 * nppann

        #  Calculate respiration for each pool with an R10 base resp.
        #  Litter needs to decay according to a basic temp and moist function.
        #  Soil decay can be calculated according to temp. response of
        #  Lloyd and moisture of Foley with a turnover time built into the Rten

        #  Two ways to decay NPP, one based on surface temp and AET for litter
        #  (Foley).  The other is for soil decay and is based on soil
        #  temperature and moisture.

        Klitsum, Kfstsum, Kslosum = 0.0, 0.0, 0.0

        for m in range(12):
            mfact = 0.25 + 0.75 * moist[m]

            Klit[m] = 1.0 * 10.0 ** (-1.4553 + 0.0014175 * aet[m])
            Klitsum += Klit[m]

            Kfst[m] = (
                mfact
                * Rten
                * math.exp(308.56 * ((1 / 56.02) - (1 / (tsoil[m] + 273.0 - 227.13))))
            )
            Kfstsum += Kfst[m]

            Kslo[m] = (
                mfact
                * Rten
                * math.exp(308.56 * ((1 / 56.02) - (1 / (tsoil[m] + 273.0 - 227.13))))
            )
            Kslosum += Kslo[m]

        meanKlit = Klitsum / 12.0
        meanKsoil = Kfstsum / 12.0

        Rmean = 0.0

        for m in range(12):
            Rlit[m] = Plit * (Klit[m] / Klitsum)
            Rfst[m] = Pfst * (Kfst[m] / Kfstsum)
            Rslo[m] = Pslo * (Kslo[m] / Kslosum)
            Rtot[m] = Rlit[m] + Rfst[m] + Rslo[m]
            Rmean += Rtot[m] / 12.0

        #  Calculate the isotope ratio of respired CO2 based on
        #  the NPP weighted mean 13C in the vegetation
        #  Since 13C is enriched in organic matter over time add factors

        for m in range(12):
            isolit[m] = isoveg - 0.75
            isofst[m] = isoveg - 1.5
            isoslo[m] = isoveg - 2.25
            isoR[m] = (
                ((Plit / nppann) * isolit[m])
                + ((Pfst / nppann) * isofst[m])
                + ((Pslo / nppann) * isoslo[m])
            )
            isoflux[m] = (isoatm - isoR[m]) * Rtot[m]

        return HetRespResults(
            Rlit=Rlit,
            Rfst=Rfst,
            Rslo=Rslo,
            Rtot=Rtot,
            isoR=isoR,
            isoflux=isoflux,
            Rmean=Rmean,
            meanKlit=meanKlit,
            meanKsoil=meanKsoil,
        )


if __name__ == "__main__":
    hetresp()
