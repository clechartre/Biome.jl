"""Calculate the total fractionation of 13C
as it goes from free air (as 13CO2) to fixed carbon in the leaf.
For use with the BIOME3 model of A. Haxeltine (1996).
There are separate routines for calculating fractionation by both
C3 and C4 plants.  This program is based upon the model used by
Lloyd and Farquhar (1994)."""

# Standard library
from dataclasses import dataclass
from typing import List


@dataclass
class IsotopeResult:
    meanC3: float
    meanC4: float
    C3DA: List[float]
    C4DA: List[float]


def isoC3(Cratio: float, Ca: float, temp: float, Rd: float) -> float:
    # Define fractionation parameters
    a = 4.4
    es = 1.1
    a1 = 0.7
    b = 27.5
    e = 0.0
    f = 8.0

    if Rd <= 0:
        Rd = 0.01

    leaftemp = 1.05 * (temp + 2.5)
    gamma = 1.54 * leaftemp
    Rd = Rd / (86400.0 * 12.0)
    Catm = Ca * 1.0e6
    k = Rd / 11.0  # From Farquhar et al. 1982 p. 126

    # Calculate the fractionation
    q = a * (1 - Cratio + 0.025)
    r = 0.075 * (es + a1)
    s = b * (Cratio - 0.1)
    t = 0.0  # (e * Rd / k + f * gamma) / Catm

    DeltaA = q + r + s - t
    delC3 = DeltaA

    return delC3


def isoC4(Cratio: float, phi: float, temp: float) -> float:
    # Define fractionation parameters
    a = 4.4
    es = 1.1
    a1 = 0.7
    b3 = 30.0

    b4 = 26.19 - (9483 / (273.2 + temp))

    DeltaA = (
        a * (1 - Cratio + 0.0125)
        + 0.0375 * (es + a1)
        + (b4 + (b3 - es - a1) * phi) * (Cratio - 0.05)
    )

    delC4 = DeltaA

    return delC4


def isotope(
    Cratio: List[float],
    Ca: float,
    temp: List[float],
    Rd: List[float],
    c4month: List[bool],
    mgpp: List[float],
    phi: float,
    gpp: float,
) -> IsotopeResult:
    wtC3 = 0.0
    wtC4 = 0.0
    C3DA = [0.0] * 12
    C4DA = [0.0] * 12

    for m in range(12):
        if mgpp[m] > 0.0:
            if Cratio[m] < 0.05:
                Cratio[m] = 0.05

            if c4month[m]:
                delC4 = isoC4(Cratio[m], phi, temp[m])
                C4DA[m] = delC4
                wtC4 += delC4 * mgpp[m]
            else:
                delC3 = isoC3(Cratio[m], Ca, temp[m], Rd[m])
                C3DA[m] = delC3
                wtC3 += delC3 * mgpp[m]
        else:
            C3DA[m] = 0.0
            C4DA[m] = 0.0

    meanC3 = wtC3 / gpp if gpp != 0 else 0.0
    meanC4 = wtC4 / gpp if gpp != 0 else 0.0

    return IsotopeResult(meanC3=meanC3, meanC4=meanC4, C3DA=C3DA, C4DA=C4DA)


if __name__ == "__main__":
    isotope()
