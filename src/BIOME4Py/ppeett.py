"""Calculate insolation and PET for each month."""

# Standard library
import math
from dataclasses import dataclass
from typing import List

# First-party
from BIOME4Py.table import table


@dataclass
class PpeettResults:
    dpet: List[float]
    dayl: List[float]
    sun: List[float]
    rad0: float


def safe_exp(x):
    try:
        return math.exp(x)
    except OverflowError:
        return float("inf")


def ppeett(
    lat: float,
    dtemp: List[float],
    dclou: List[float],
    radanom: List[float],
    temp: List[float],
) -> PpeettResults:
    midday = [16, 44, 75, 105, 136, 166, 197, 228, 258, 289, 319, 350]
    daysinmonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    pie = 4.0 * math.atan(1.0)
    dip = pie / 180.0

    b = 0.2
    radup = 107.0
    qoo = 1360.0
    d = 0.5
    c = 0.25
    albedo = 0.17

    dpet = [0.0] * 365
    ddayl = [0.0] * 365
    dayl = [0.0] * 12
    sun = [0.0] * 12

    day = 0
    rad0 = 0.0

    for month in range(12):
        for dayofm in range(daysinmonth[month]):
            day += 1

            psi, l = table(dtemp[day - 1])

            # Calculation of longwave radiation
            rl = (b + (1 - b) * (dclou[day - 1] / 100.0)) * (radup - dtemp[day - 1])
            rl *= radanom[month]

            # Calculation of short wave radiation
            qo = qoo * (
                1.0 + 2.0 * 0.01675 * math.cos(dip * (360.0 * float(day)) / 365.0)
            )
            rs = qo * (c + d * (dclou[day - 1] / 100.0)) * (1.0 - albedo)
            rs *= radanom[month]

            a = -dip * 23.4 * math.cos(dip * 360.0 * (float(day) + 10.0) / 365.0)
            cla = math.cos(lat * dip) * math.cos(a)
            sla = math.sin(lat * dip) * math.sin(a)
            u = rs * sla - rl
            v = rs * cla

            if u >= v:
                ho = pie
            elif u <= -v:
                ho = 0.0
            else:
                ho = math.acos(-u / v)

            # Equations for demand function
            sat = (
                2.5
                * 10**6
                * safe_exp((17.27 * dtemp[day - 1]) / (237.3 + dtemp[day - 1]))
            ) / ((237.3 + dtemp[day - 1]) ** 2)
            if (sat + psi) != 0 and psi != 0:
                fd = (3600.0 / (l * 1e6)) * (sat / (sat + psi))
            else:
                fd = 0

            dpet[day - 1] = (
                fd
                * 2.0
                * ((rs * sla - rl) * ho + rs * cla * math.sin(ho))
                / (pie / 12.0)
            )

            # Calculate daylength in hours
            if ho == 0.0:
                ddayl[day - 1] = 0.0
            else:
                ddayl[day - 1] = 24.0 * (ho / pie)

            if day == midday[month]:
                dayl[month] = ddayl[day - 1]

                us = rs * sla
                vs = rs * cla
                if us >= vs:
                    hos = pie
                elif us <= -vs:
                    hos = 0.0
                else:
                    hos = math.acos(-us / vs)

                sun[month] = (
                    2.0
                    * (rs * sla * hos + rs * cla * math.sin(hos))
                    * (3600.0 * 12.0 / pie)
                )
                if sun[month] <= 0.0:
                    sun[month] = 0.0

                if temp[month] > 0.0:
                    rad0 += float(daysinmonth[month]) * sun[month] * 1e-9 * 0.5

    return PpeettResults(dpet=dpet, dayl=dayl, sun=sun, rad0=rad0)


if __name__ == "__main__":
    ppeett()
