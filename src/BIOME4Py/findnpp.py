"""Find NPP subroutine."""

# Standard library
from typing import List, Tuple

# Third-party
import numpy as np

# First-party
from BIOME4Py.growth import growth


def findnpp(
    pfts: List[int],
    pft: int,
    optlai: float,
    optnpp: float,
    annp: np.ndarray,
    dtemp: np.ndarray,
    sun: np.ndarray,
    temp: np.ndarray,
    dprec: np.ndarray,
    dmelt: np.ndarray,
    dpet: np.ndarray,
    dayl: np.ndarray,
    k: float,
    pftpar: List[List[float]],
    optdata: np.ndarray,
    dphen: np.ndarray,
    co2: float,
    p: float,
    tsoil: np.ndarray,
    realout: np.ndarray,
    numofpfts: float,
) -> Tuple[np.ndarray, float, float, np.ndarray]:
    """Run NPP optimization model for one pft"""

    # Initialize variables
    inv = np.zeros(500, dtype=int)
    realin = np.zeros(500, dtype=int)

    # If pft is not equal to 1, this is a dummy call of subroutine
    # return zero values
    if pfts[pft] != 1:
        return

    # Calculate NPP at a range of different leaf areas by iteration
    lowbound = 0.01
    range_val = 8.0

    for iterate in range(8):
        alai = np.zeros(2)
        alai[0] = lowbound + (1.0 / 4.0) * range_val
        alai[1] = lowbound + (3.0 / 4.0) * range_val

        npp, inv, realin = growth(
            alai[1],
            annp,
            sun,
            temp,
            dprec,
            dmelt,
            dpet,
            k,
            pftpar,
            pft,
            dayl,
            dtemp,
            inv,
            dphen,
            co2,
            p,
            tsoil,
            realin,
        )
        if npp >= optnpp:
            optlai = alai[0]
            optnpp = npp
            optdata[pft, :500] = inv[:500]

        npp, inv, realin = growth(
            alai[1],
            annp,
            sun,
            temp,
            dprec,
            dmelt,
            dpet,
            k,
            pftpar,
            pft,
            dayl,
            dtemp,
            inv,
            dphen,
            co2,
            p,
            tsoil,
            realin,
        )

        # Find the leaf area which gives the highest NPP
        if npp >= optnpp:
            optlai = alai[1]
            optnpp = npp
            optdata[pft, :500] = inv[:500]
            realout[pft, :500] = realin[:500]

        range_val /= 2.0
        lowbound = optlai - range_val / 2.0
        if lowbound <= 0.0:
            lowbound = 0.01

    return optdata, optlai, optnpp, realin
