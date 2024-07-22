"""Provide environmental sieve."""

# Standard library
from typing import Tuple

# Third-party
import numpy as np


def constraints(
    tcm: float,
    twm: float,
    tminin: float,
    gdd5: float,
    rad0: float,
    gdd0: float,
    maxdepth: float,
) -> Tuple[float, float, np.ndarray, np.ndarray]:
    npft = 13
    nclin = 6
    undef = -99.9

    limits = np.array(
        [
            [
                [-99.9, -99.9],
                [0.0, -99.9],
                [-99.9, -99.9],
                [-99.9, -99.9],
                [10.0, -99.9],
                [-99.9, -99.9],
            ],  # 1
            [
                [-99.9, -99.9],
                [0.0, -99.9],
                [-99.9, -99.9],
                [-99.9, -99.9],
                [10.0, -99.9],
                [-99.9, -99.9],
            ],  # 2
            [
                [-99.9, -99.9],
                [-8.0, 5.0],
                [1200.0, -99.9],
                [-99.9, -99.9],
                [10.0, -99.9],
                [-99.9, -99.9],
            ],  # 3
            [
                [-15.0, -99.9],
                [-99.9, -8.0],
                [1200.0, -99.9],
                [-99.9, -99.9],
                [-99.9, -99.9],
                [-99.9, -99.9],
            ],  # 4
            [
                [-2.0, -99.9],
                [-99.9, 10.0],
                [900.0, -99.9],
                [-99.9, -99.9],
                [10.0, -99.9],
                [-99.9, -99.9],
            ],  # 5
            [
                [-32.5, -2.0],
                [-99.9, -99.9],
                [-99.9, -99.9],
                [-99.9, -99.9],
                [21.0, -99.9],
                [-99.9, -99.9],
            ],  # 6
            [
                [-99.9, 5.0],
                [-99.9, -10.0],
                [-99.9, -99.9],
                [-99.9, -99.9],
                [21.0, -99.9],
                [-99.9, -99.9],
            ],  # 7
            [
                [-99.9, -99.9],
                [-99.9, 0.0],
                [550.0, -99.9],
                [-99.9, -99.9],
                [-99.9, -99.9],
                [-99.9, -99.9],
            ],  # 8
            [
                [-99.9, -99.9],
                [-3.0, -99.9],
                [-99.9, -99.9],
                [-99.9, -99.9],
                [10.0, -99.9],
                [-99.9, -99.9],
            ],  # 9
            [
                [-99.9, -99.9],
                [-45.0, -99.9],
                [500.0, -99.9],
                [-99.9, -99.9],
                [10.0, -99.9],
                [-99.9, -99.9],
            ],  # 10
            [
                [-99.9, -99.9],
                [-99.9, -99.9],
                [-99.9, -99.9],
                [50.0, -99.9],
                [15.0, -99.9],
                [15.0, -99.9],
            ],  # 11
            [
                [-99.9, -99.9],
                [-99.9, -99.9],
                [-99.9, -99.9],
                [50.0, -99.9],
                [15.0, -99.9],
                [-99.9, -99.9],
            ],  # 12
            [
                [-99.9, -99.9],
                [-99.9, -99.9],
                [-99.9, -99.9],
                [-99.9, -99.9],
                [15.0, -99.9],
                [-99.9, -99.9],
            ],  # 13
        ]
    )

    if tminin <= tcm:
        tmin = tminin
    else:
        tmin = tcm - 5.0

    ts = twm - tcm

    clindex = np.array([tcm, tmin, gdd5, gdd0, twm, maxdepth])
    pfts = np.zeros(npft, dtype=int)

    for ip in range(npft):
        pfts[ip] = 1  # Default to present
        for iv in range(nclin):
            lower_limit, upper_limit = limits[ip, iv]

            if (
                (
                    lower_limit != undef
                    and upper_limit != undef
                    and lower_limit <= clindex[iv] < upper_limit
                )
                or (
                    lower_limit == undef
                    and upper_limit != undef
                    and clindex[iv] < upper_limit
                )
                or (
                    lower_limit != undef
                    and upper_limit == undef
                    and lower_limit <= clindex[iv]
                )
                or (lower_limit == undef and upper_limit == undef)
            ):
                continue
            else:
                pfts[ip] = 0
                break

    return tmin, ts, clindex, pfts


if __name__ == "__main__":
    constraints()
