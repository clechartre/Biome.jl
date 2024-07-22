"""Calculate C3 photoynthesis."""

# Standard library
from dataclasses import dataclass

# Third-party
import numpy as np


@dataclass
class PhotosynthesisResults:
    leafresp: float
    grossphot: float
    aday: float


def photosynthesis(
    ratio: float,
    dsun: float,
    daytime: float,
    temp: float,
    age: float,
    fpar: float,
    p: float,
    ca: float,
    pft: int,
) -> PhotosynthesisResults:
    # Constants
    qeffc3 = 0.08
    drespc3 = 0.015
    abs1 = 1.0
    teta = 0.7
    slo2 = 20.9 * 1e3
    jtoe = 2.3 * 1e-6
    optratio = 0.95
    ko25 = 30.0 * 1e3
    kc25 = 30.0
    tao25 = 2600.0
    cmass = 12.0
    kcq10 = 2.1
    koq10 = 1.2
    taoq10 = 0.57
    twigloss = 1.0
    tune = 1.0

    # PFT specific parameters
    t0 = [10.0, 10.0, 5.0, 4.0, 3.0, 0.0, 0.0, 4.5, 10.0, 5.0, -7.0, -7.0, -12.0]
    tcurve = [1.0, 1.0, 1.0, 1.0, 0.9, 0.8, 0.8, 1.0, 1.0, 1.0, 0.6, 0.6, 0.5]

    # Derived parameters
    leafcost = (age / 12.0) ** 0.25
    mfo2 = slo2 / 1e5
    o2 = p * mfo2
    if daytime <= 4.0:
        daytime = 4.0

    # Temperature stress calculation
    mintemp = t0[pft]
    if temp > mintemp + 0.1:
        tstress = tcurve[pft] * (2.71828 ** (-10.0 / (temp - mintemp)))
    else:
        tstress = 0.0

    # Temperature adjusted values
    ko = ko25 * (koq10 ** ((temp - 25.0) / 10.0))
    kc = kc25 * (kcq10 ** ((temp - 25.0) / 10.0))
    tao = tao25 * (taoq10 ** ((temp - 25.0) / 10.0))

    s = drespc3 * (24.0 / daytime)
    ts = o2 / (2.0 * tao)
    kk = kc * (1.0 + (o2 / ko))
    z = cmass * jtoe * dsun * fpar * twigloss * tune

    # Calculate optimal vm value based on a ratio of 0.95
    pi = optratio * ca * p
    c1 = tstress * qeffc3 * ((pi - ts) / (pi + 2.0 * ts))
    c2 = (pi - ts) / (pi + kk)
    numerator = s - teta * s
    denominator = c2 - teta * s
    # Handle potential issues with fractional powers of negative numbers
    if denominator != 0:
        result = numerator / denominator
        if result < 0:
            oc = np.sign(result) * np.abs(result) ** 0.5
        else:
            oc = result**0.5
    else:
        oc = 0

    if z == 0.0:
        vmax = 0.0
    else:
        vmax = (
            (z / drespc3)
            * (c1 / c2)
            * ((2.0 * teta - 1.0) * s - (2.0 * teta * s - c2) * oc)
        )

    # Actual photosynthesis calculation
    pi = ratio * ca * p

    # FIXME pi is always smaller than ts, so grossphot is always 0
    if pi <= ts:
        grossphot = 0.0
    else:
        c1 = tstress * qeffc3 * ((pi - ts) / (pi + 2.0 * ts))
        c2 = (pi - ts) / (pi + kk)

        if z == 0.0:
            je = 0.0
        else:
            je = c1 * z / daytime

        if vmax == 0.0:
            jc = 0.0
        else:
            jc = c2 * vmax / 24.0

        wif = daytime / (2.0 * teta)

        if je == 0.0 and jc == 0.0:
            grossphot = 0.0
        else:
            grossphot = wif * (
                je + jc - ((je + jc) ** 2.0 - 4.0 * teta * je * jc) ** 0.5
            )

    adaygc = grossphot - (daytime / 24.0) * drespc3 * vmax
    leafresp = drespc3 * vmax * leafcost
    if leafresp < 0.0:
        leafresp = 0.0

    if adaygc == 0.0:
        aday = 0.0
    else:
        aday = (adaygc / cmass) * (8.314 * (temp + 273.3) / p) * 1000.0

    return PhotosynthesisResults(leafresp=leafresp, grossphot=grossphot, aday=aday)


if __name__ == "__main__":
    photosynthesis()
