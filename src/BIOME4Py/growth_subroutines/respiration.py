"""Calculate annual respiration costs."""

# Standard library
import math
from dataclasses import dataclass
from typing import List


@dataclass
class RespirationResults:
    npp: float
    stemresp: float
    percentcost: float
    mstemresp: List[float]
    mrootresp: List[float]
    backleafresp: List[float]


def respiration(
    gpp: float,
    alresp: float,
    temp: List[float],
    grass: int,
    lai: float,
    fpar: float,
    pft: int,
) -> RespirationResults:
    # Constants
    Ln = 50.0
    y = 0.8
    m10 = 1.6
    p1 = 0.25
    stemcarbon = 0.5
    e0 = 308.56
    tref = 10.0
    t0 = 46.02

    respfact = [0.8, 0.8, 1.4, 1.6, 0.8, 4.0, 4.0, 1.6, 0.8, 1.4, 4.0, 4.0, 4.0]
    allocfact = [1.0, 1.0, 1.2, 1.2, 1.2, 1.2, 1.2, 1.0, 1.0, 1.0, 1.0, 1.0, 1.5]

    # Calculate leafmass and litterfall
    litterfall = lai * Ln * allocfact[pft]

    # Calculate stem maintenance respiration costs
    stemresp = 0.0
    mstemresp = [0.0] * 12
    for m in range(12):
        if temp[m] <= -46.02:
            mstemresp[m] = 0.0
        else:
            mstemresp[m] = (
                lai
                * stemcarbon
                * respfact[pft]
                * math.exp(e0 * (1.0 / (tref + t0) - 1.0 / (temp[m] + t0)))
            )
        stemresp += mstemresp[m]

    # Calculate belowground maintenance respiration costs
    leafmaint = 0.0
    finerootresp = p1 * litterfall
    mrootresp = [0.0] * 12
    backleafresp = [0.0] * 12
    for m in range(12):
        mrootresp[m] = (mstemresp[m] / stemresp) * finerootresp
        backleafresp[m] = mrootresp[m] * fpar * 4.0
        leafmaint += backleafresp[m]

    # Leaf respiration costs
    leafresp = alresp + leafmaint

    # Clear out the stem respiration if grass
    if grass == 2:
        stemresp = 0.0
        mstemresp = [0.0] * 12

    # Growth respiration and annual NPP
    growthresp = (1.0 - y) * (gpp - stemresp - leafresp - finerootresp)
    npp = gpp - stemresp - leafresp - finerootresp - growthresp

    # Minimum allocation requirement
    minallocation = 1.0 * litterfall
    if npp < minallocation:
        npp = -9999.0

    # Respiration costs as a percentage of GPP
    if gpp > 0.0 and npp != -9999.0:
        percentcost = 100.0 * (gpp - npp) / gpp
    else:
        percentcost = 0.0

    return RespirationResults(
        npp=npp,
        stemresp=stemresp,
        percentcost=percentcost,
        mstemresp=mstemresp,
        mrootresp=mrootresp,
        backleafresp=backleafresp,
    )


if __name__ == "__main__":
    respiration()
