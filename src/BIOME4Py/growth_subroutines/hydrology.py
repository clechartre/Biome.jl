"""Calculate water balance and phenology for this pft/s and fvc/s
Subroutine hydrology returns monthly mean gc & summed fvc value."""

# Standard library
import math
from dataclasses import dataclass
from typing import List


@dataclass
class HydrologyResults:
    meanfvc: List[float]
    meangc: List[float]
    meanwr: List[List[float]]
    meanaet: List[float]
    runoffmonth: List[float]
    wet: List[float]
    dayfvc: List[float]
    annaet: float
    sumoff: float
    greendays: int
    runnoff: int


def hydrology(
    dprec: List[float],
    dmelt: List[float],
    deq: List[float],
    root: float,
    k: List[float],
    maxfvc: float,
    pft: int,
    phentype: int,
    wst: float,
    gcopt: List[float],
    mgmin: float,
    dphen: List[List[float]],
    dtemp: List[float],
    grass: int,
    emax: float,
    pftpar: List[List[float]],
) -> HydrologyResults:
    # Initialize variables
    days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    alfam = 1.4
    gm = 5.0
    onnw = pftpar[pft][3]
    offw = pftpar[pft][3]

    # Initialize result variables
    meanfvc = [0.0] * 12
    meangc = [0.0] * 12
    meanwr = [[0.0, 0.0, 0.0] for _ in range(12)]
    meanaet = [0.0] * 12
    runoffmonth = [0.0] * 12
    wet = [0.0] * 365
    dayfvc = [0.0] * 365
    runnoff = 0.0
    drainage = 0.0
    gc = 0
    fvc = 0

    # Initialize soil moisture stores for
    # day one of the "spin-up" year
    w_initial = [wst, wst]

    for _ in range(2):
        # Reset the soil moisture stores to
        # initial values for the second iteration
        w = w_initial[:]
        annaet = 0.0
        sumoff = 0.0
        greendays = 0
        wilt = False

        for month in range(12):
            meanfvc[month] = 0.0
            meangc[month] = 0.0
            meanwr[month] = [0.0, 0.0, 0.0]
            meanaet[month] = 0.0
            runoffmonth[month] = 0.0

            for dayofmonth in range(days[month]):
                d = (
                    sum(days[:month]) + dayofmonth
                )  # Calculate the day of the year (0-based index)
                wr = root * w[0] + (1.0 - root) * w[1]

                # Vegetation phenology
                if phentype == 1:  # Evergreen
                    fvc = maxfvc
                elif phentype == 2 or grass == 2:  # Cold deciduous
                    fvc = maxfvc * dphen[d][grass - 1]  # -1 for 0-based indexing
                    if fvc > 0.01 and wr > offw:
                        fvc = fvc
                    elif fvc < 0.01 and wr > onnw:
                        fvc = fvc
                    else:
                        fvc = 0.0
                elif fvc > 0.01 and wr > offw:  # Drought deciduous
                    fvc = maxfvc
                elif fvc < 0.01 and wr > onnw:
                    fvc = maxfvc
                else:
                    fvc = 0.0

                if fvc > 0.0:
                    greendays += 1

                if dtemp[d] <= -10.0:
                    gc = 0.0
                    aet = 0.0
                    perc = 0.0
                else:
                    if fvc == 0.0:
                        aet = 0.25 * deq[d]
                    else:
                        gmin = mgmin * fvc
                        gc = gcopt[d] * (fvc / maxfvc)
                        gsurf = gc + gmin
                        if gsurf > 0.0:
                            alfa = min(1.0, alfam * (1.0 - math.exp(-gsurf / gm)))
                            aet = alfa * deq[d]
                        else:
                            alfa = 0.0
                            aet = 0.0

                    wetphytomass = 0.01 * aet
                    waste = 0.01 * aet
                    demand = aet + wetphytomass + waste
                    supply = emax * wr

                    if demand > supply:
                        a = 1.0 - supply / (deq[d] * alfam)
                        if a < 0.0:
                            a = 0.0
                        gsurf = -gm * math.log(a)
                        gmin = mgmin * fvc
                        aet = supply
                        gc = gsurf - gmin
                        if gc <= 0.0:
                            gc = 0.0
                            wilt = True

                    perc = k[0] * w[0] ** 4.0
                    evap = 0.0

                    if wr > 0.0:
                        r1 = [root * (w[0] / wr), (1.0 - root) * (w[1] / wr)]
                    else:
                        r1 = [0.0, 0.0]

                    if k[4] != 0.0:
                        w[0] = (
                            w[0]
                            + (dprec[d] + dmelt[d] - perc - evap - r1[0] * aet) / k[4]
                        )
                    else:
                        w[0] = 0.0

                    if k[5] != 0.0:
                        w[1] = w[1] + (perc - r1[1] * aet) / k[5]
                    else:
                        w[1] = 0.0

                    if w[1] >= 1.0:
                        drainage = (w[1] - 1.0) * k[5]
                        w[1] = 1.0

                    if w[0] >= 1.0:
                        runnoff = (w[0] - 1.0) * k[4]
                        w[0] = 1.0

                    if w[0] <= 0.0:
                        w[0] = 0.0
                    if w[1] <= 0.0:
                        w[1] = 0.0

                annaet += aet
                sumoff += runnoff + drainage
                runoffmonth[month] += runnoff + drainage
                meanwr[month][0] += wr / days[month]
                meanwr[month][1] += w[0] / days[month]
                meanwr[month][2] += w[1] / days[month]

                if gc != 0.0:
                    meangc[month] += gc / days[month]
                if fvc != 0.0:
                    meanfvc[month] += fvc / days[month]
                meanaet[month] += aet / days[month]

                wet[d] = wr
                dayfvc[d] = fvc

    return HydrologyResults(
        meanfvc=meanfvc,
        meangc=meangc,
        meanwr=meanwr,
        meanaet=meanaet,
        runoffmonth=runoffmonth,
        wet=wet,
        dayfvc=dayfvc,
        annaet=annaet,
        sumoff=sumoff,
        greendays=greendays,
        runnoff=runnoff,
    )
