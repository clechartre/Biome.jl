"""Calculate the maximum quantum yield of photosynthesis."""

# Standard library
from typing import List


def calcphi(gpp: List[float]) -> float:
    totgpp = 0.0
    svar = [0.0, 0.0, 0.0, 0.0]
    snormavg = [0.0, 0.0, 0.0, 0.0]

    # Calculate total GPP and mean GPP
    totgpp = sum(gpp)
    meangpp = totgpp / 12.0

    # Normalize GPP
    normgpp = [g / meangpp for g in gpp]

    # Calculate seasonal normalized averages
    snormavg[0] = sum(normgpp[0:3]) / 3.0
    snormavg[1] = sum(normgpp[3:6]) / 3.0
    snormavg[2] = sum(normgpp[6:9]) / 3.0
    snormavg[3] = sum(normgpp[9:12]) / 3.0

    # Calculate population variances by season
    for m in range(3):
        a = ((normgpp[m] - snormavg[0]) ** 2) / 3.0
        svar[0] += a

    for m in range(3, 6):
        a = ((normgpp[m] - snormavg[1]) ** 2) / 3.0
        svar[1] += a

    for m in range(6, 9):
        a = ((normgpp[m] - snormavg[2]) ** 2) / 3.0
        svar[2] += a

    for m in range(9, 12):
        a = ((normgpp[m] - snormavg[3]) ** 2) / 3.0
        svar[3] += a

    avar = sum(svar)

    # Calculate phi based on the annual variability
    phi = 0.3518717 * avar + 0.2552359
    if phi >= 1.0:
        phi /= 10.0

    return phi


if __name__ == "__main__":
    calcphi()
