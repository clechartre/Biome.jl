"""Calculate monthly mean soil temperature
based on monthly mean air temperature assuming a thermal
conductivity of the soil and a time lag between soil and air
temperatures. Based on work by S. Sitch."""

# Standard library
import math
from typing import List


def soiltemp(tair: List[float], soiltext: List[float]) -> List[float]:
    pie = 4.0 * math.atan(1.0)

    therm = [8.0, 4.5, 1.0, 5.25, 4.5, 2.75, 1.0, 1.0, 8.0]
    sumtemp = 0.0

    # Calculate a soil-texture based thermal conductivity and lag time
    diffus = therm[1]
    damp = 0.25 / (math.sqrt(diffus))
    lag = damp * (6 / pie)
    amp = math.exp(-damp)

    # Calculate mean annual air temperature
    for m in range(12):
        sumtemp += tair[m]
    meantemp = sumtemp / 12.0

    # Calculate soil temperature
    tsoil = [0.0] * 12
    tsoil[0] = (1.0 - amp) * meantemp + amp * (
        tair[11] + (1.0 - lag) * (tair[0] - tair[11])
    )

    for m in range(1, 12):
        tsoil[m] = (1.0 - amp) * meantemp + amp * (
            tair[m - 1] + (1.0 - lag) * (tair[m] - tair[m - 1])
        )

    # Due to snow cover don't allow soil temp < -10
    for m in range(12):
        if tsoil[m] < -10.0:
            tsoil[m] = -10.0

    return tsoil


if __name__ == "__main__":
    soiltemp()
