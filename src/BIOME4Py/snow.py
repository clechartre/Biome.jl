"""Mask precipitation to account for effects of snow."""

# Standard library
from dataclasses import dataclass
from typing import List


@dataclass
class SnowResults:
    dprec: List[float]
    dmelt: List[float]
    maxdepth: float


def snow(dtemp: List[float], dprecin: List[float]) -> SnowResults:
    tsnow = -1.0
    km = 0.7
    snowpack = 0.0
    maxdepth = 0.0

    dprec = [0.0] * 365
    dmelt = [0.0] * 365

    for it in range(2):
        sum1 = 0.0
        sum2 = 0.0

        for day in range(365):
            drain = dprecin[day] / (365.0 / 12.0)

            # Calculate snow melt and new snow for today
            if dtemp[day] < tsnow:
                newsnow = drain
                snowmelt = 0.0
            else:
                newsnow = 0.0
                snowmelt = km * (dtemp[day] - tsnow)

            # Reduce snowmelt if greater than total snow remaining
            if snowmelt > snowpack:
                snowmelt = snowpack

            # Update snowpack store
            snowpack = snowpack + newsnow - snowmelt
            if snowpack > maxdepth:
                maxdepth = snowpack

            # Calculate effective water supply (as daily values in mm/day)
            dprec[day] = drain - newsnow
            dmelt[day] = snowmelt

            sum1 += dprec[day] + dmelt[day]
            sum2 += drain

    return SnowResults(dprec=dprec, dmelt=dmelt, maxdepth=maxdepth)


if __name__ == "__main__":
    snow()
