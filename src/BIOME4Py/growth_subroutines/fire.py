"""Calculate the number of potential fire days
in a year based on threshold values for soil moisture, which are
PFT dependent.  Jed Kaplan 1998."""

# Standard library
import math
from dataclasses import dataclass
from typing import List


@dataclass
class FireResult:
    firedays: float
    wetday: float
    dryday: float
    firefraction: float
    burnfraction: float


def fire(wet: List[float], pft: int, lai: float, npp: float) -> FireResult:
    threshold = [
        0.25,
        0.20,
        0.40,
        0.33,
        0.40,
        0.33,
        0.33,
        0.40,
        0.40,
        0.33,
        0.33,
        0.33,
        0.33,
    ]
    firedays = 0.0
    wetday = 0.0
    dryday = 100.0
    burn = [0.0] * 365

    for day in range(365):
        if wet[day] < threshold[pft]:
            burn[day] = 1.0
        elif wet[day] > threshold[pft] + 0.05:
            burn[day] = 0.0
        else:
            burn[day] = 1 / math.exp(wet[day] - threshold[pft])

        if wet[day] > wetday:
            wetday = wet[day]
        if wet[day] < dryday:
            dryday = wet[day]

        firedays += burn[day]

    firefraction = firedays / 365.0
    litter = (lai / 5.0) * npp
    burnfraction = litter * (1 - (math.exp(-0.2 * firefraction**1.5)) ** 1.5)

    if npp < 1000.0:
        firedays *= npp / 1000.0

    return FireResult(
        firedays=firedays,
        wetday=wetday,
        dryday=dryday,
        firefraction=firefraction,
        burnfraction=burnfraction,
    )


if __name__ == "__main__":
    fire()
