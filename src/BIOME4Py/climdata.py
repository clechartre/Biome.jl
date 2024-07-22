"""Calculate GDDs, TCM, wrin, and total precipitation."""

# Standard library
from dataclasses import dataclass
from typing import List


@dataclass
class ClimateResults:
    cold: float
    warm: float
    gdd5: float
    gdd0: float
    rain: float
    alttmin: float


def climdata(
    temp: List[float], prec: List[float], dtemp: List[float]
) -> ClimateResults:
    cold = 100.0
    warm = -100.0
    rain = 0.0

    for m in range(12):
        if temp[m] < cold:
            cold = temp[m]
        if temp[m] > warm:
            warm = temp[m]
        rain += prec[m]

    gdd10 = 0.0
    gdd5 = 0.0
    gdd0 = 0.0

    for day in range(365):
        minus10 = dtemp[day] - 10.0
        minus5 = dtemp[day] - 5.0
        minus0 = dtemp[day]
        if minus10 <= 0.0:
            minus10 = 0.0
        if minus5 <= 0.0:
            minus5 = 0.0
        if minus0 <= 0.0:
            minus0 = 0.0
        gdd10 += minus10
        gdd5 += minus5
        gdd0 += minus0

    alttmin = (0.006 * cold**2) + (1.316 * cold) - 21.9

    return ClimateResults(
        cold=cold, warm=warm, gdd5=gdd5, gdd0=gdd0, rain=rain, alttmin=alttmin
    )


if __name__ == "__main__":
    climdata()
