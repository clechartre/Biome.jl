"""Calculate photosynthesis metrics from C4 plants."""

# Standard library
import math

# First-party
from BIOME4Py.growth_subroutines.photosynthesis import PhotosynthesisResults


def c4photo(
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
    drespc4 = 0.03
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

    # PFT specific parameters
    t0 = [10.0] * 13

    # Determine qeffc4 and tune based on PFT
    if pft in [8, 9]:
        qeffc4 = 0.0633
        tune = 1.0
    elif pft == 10:
        qeffc4 = 0.0565
        tune = 0.75
    else:
        qeffc4 = 0.0633  # Default value
        tune = 1.0  # Default value

    # Derived parameters
    leafcost = (age / 12.0) ** 0.25
    mfo2 = slo2 / 1e5
    o2 = p * mfo2
    if daytime <= 4.0:
        daytime = 4.0

    # Temperature stress calculation
    mintemp = t0[pft]
    maxtemp = 55.0
    if mintemp + 0.1 < temp < maxtemp:
        tstress = math.exp(-10.0 / (temp - mintemp))
    else:
        tstress = 0.0

    if tstress > 1.0:
        tstress = 1.0

    # Temperature adjusted values
    tao = tao25 * (taoq10 ** ((temp - 25.0) / 10.0))

    s = drespc4 * (24.0 / daytime)
    ts = o2 / (2.0 * tao)
    z = cmass * jtoe * dsun * fpar * twigloss * tune

    # Optimal pi value and non-co2-dependent parameters
    pi = optratio * ca * p
    c1 = qeffc4 * tstress
    c2 = 1.0
    oc = ((s - teta * s) / (c2 - teta * s)) ** 0.5

    # Estimate the optimal value of Vm at ratio=0.8 g(C).m-2.day-1
    if z == 0.0:
        vmaxc4 = 0.0
    else:
        vmaxc4 = (
            (z / drespc4)
            * (c1 / c2)
            * ((2.0 * teta - 1.0) * s - (2.0 * teta * s - c2) * oc)
        )

    # Actual photosynthesis calculation
    if pi <= ts:
        grossphotc4 = 0.0
    else:
        if z == 0.0:
            je = 0.0
        else:
            je = c1 * z / daytime

        if vmaxc4 == 0.0:
            jc = 0.0
        else:
            jc = c2 * vmaxc4 / 24.0

        # Damage gives the limitation of c4 photosynthesis by pi
        damage = ratio / 0.4 if ratio < 0.4 else 1.0
        wif = damage * daytime / (2.0 * teta)

        if je == 0.0 and jc == 0.0:
            grossphotc4 = 0.0
        else:
            grossphotc4 = wif * (
                je + jc - ((je + jc) ** 2.0 - 4.0 * teta * je * jc) ** 0.5
            )

    adaygcc4 = grossphotc4 - (daytime / 24.0) * drespc4 * vmaxc4
    leafrespc4 = drespc4 * vmaxc4 * leafcost

    if grossphotc4 == 0.0 and vmaxc4 == 0.0:
        adayc4 = 0.0
    else:
        adayc4 = (adaygcc4 / cmass) * (8.314 * (temp + 273.3) / p) * 1000.0

    return PhotosynthesisResults(
        leafresp=leafrespc4, grossphot=grossphotc4, aday=adayc4
    )


if __name__ == "__main__":
    c4photo()
