"""Calculate the a generic phenology for any summergreen pft
three month period centred around the coldest month is
defined as the minimum period during which foliage is not
present. Plants then start growing leaves and the end of this
3 month period or when the temperature gos above 5oC if this
occurs later. Plants take 200 gdd5 to grow a full leaf canopy."""

# Third-party
import numpy as np


def phenology(
    dtemp: np.ndarray,
    temp: np.ndarray,
    tcm: float,
    tdif: float,
    tmin: float,
    pft: int,
    ddayl: np.ndarray,
    pftpar: np.ndarray,
) -> np.ndarray:
    daysinmonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    dphen = np.zeros((365, 2))
    ramp = [0.0, pftpar[pft][7], pftpar[pft][8]]

    if pft == 7:
        ont = 0.0  # minimum temp for growth
    else:
        ont = 5.0

    warm = tcm
    ncm = 0
    hotm = 0
    for m in range(12):
        if temp[m] == tcm:
            ncm = m + 1  # Fortran to Python index correction
        if temp[m] > warm:
            warm = temp[m]
            hotm = m + 1  # Fortran to Python index correction

    for phencase in range(2):
        coldm = [ncm - 1, ncm, ncm + 1]
        if coldm[0] == 0:
            coldm[0] = 12
        if coldm[2] == 13:
            coldm[2] = 1
        if hotm == 12:
            hotm = 0

        gdd = 0.0
        winter = 0
        for spinup in range(2):
            day = 0
            flip = 0
            for m in range(12):
                for dayofmonth in range(daysinmonth[m]):
                    day += 1
                    if dtemp[day - 1] > ont:
                        if m + 1 not in coldm:
                            today = max(dtemp[day - 1], 0.0)
                            gdd += today
                            if gdd == 0.0:
                                dphen[day - 1, phencase] = 0.0
                            else:
                                if ramp[phencase] != 0:
                                    dphen[day - 1, phencase] = gdd / ramp[phencase]
                                else:
                                    dphen[day - 1, phencase] = 0
                            if gdd >= ramp[phencase]:
                                dphen[day - 1, phencase] = 1.0
                            flip = 1
                        else:
                            if flip == 1:
                                winter = 0
                            winter += 1
                            dphen[day - 1, phencase] = 0.0
                            gdd = 0.0
                            flip = 0

                    if phencase == 1:
                        if m + 1 >= hotm:
                            if dtemp[day - 1] < -10.0 or ddayl[day - 1] < 10.0:
                                dphen[day - 1, phencase] = 0.0
                        elif m + 1 == coldm[0]:
                            dphen[day - 1, phencase] = 0.0
                    elif phencase == 2:
                        if dtemp[day - 1] < -5.0:
                            dphen[day - 1, phencase] = 0.0

    return dphen


if __name__ == "__main__":
    phenology()
