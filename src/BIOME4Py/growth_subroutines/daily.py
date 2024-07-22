"""Linearly interpolate the mid-month optgc & ga values to daily values."""

# Standard library
from typing import List

# Third-party
import numpy as np


def daily(mly: List[float]) -> List:
    midday = np.array(
        [
            16.0,
            44.0,
            75.0,
            105.0,
            136.0,
            166.0,
            197.0,
            228.0,
            258.0,
            289.0,
            319.0,
            350.0,
        ]
    )
    mly = np.array(mly)
    dly = np.zeros(365)

    # Initial vinc calculation and boundary conditions
    vinc = (mly[0] - mly[11]) / 31.0
    dly[349] = mly[11]  # Note: Adjusting for zero-index in Python
    for id in range(350, 365):
        dly[id] = dly[id - 1] + vinc
    dly[0] = dly[364] + vinc
    for id in range(1, 15):
        dly[id] = dly[id - 1] + vinc

    # Interpolation between midpoints
    for im in range(11):
        vinc = (mly[im + 1] - mly[im]) / (midday[im + 1] - midday[im])
        dly[int(midday[im]) - 1] = mly[im]  # Adjust for zero-index
        for id in range(int(midday[im]), int(midday[im + 1]) - 1):
            dly[id] = dly[id - 1] + vinc

    return dly


if __name__ == "__main__":
    daily()
