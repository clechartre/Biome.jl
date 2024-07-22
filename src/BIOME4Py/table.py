"""Extract Gamma and Lambda based on temperature."""

# Standard library
from typing import Tuple


def table(tc: float) -> Tuple[float, float]:
    """
    Looks up gamma and lambda from the table based on the given temperature (tc).

    Author: Wolfgang Cramer, Dept. of Geography, Trondheim University-AVH,
    N-7055 Dragvoll, Norway.
    Latest revisions 14/2-1991

    Args:
        tc (float): Temperature for which gamma and lambda are looked up.

    Returns:
        tuple: gamma and lambda values based on the provided temperature.
    """

    gbase = [
        [-5.0, 64.6],
        [0.0, 64.9],
        [5.0, 65.2],
        [10.0, 65.6],
        [15.0, 65.9],
        [20.0, 66.1],
        [25.0, 66.5],
        [30.0, 66.8],
        [35.0, 67.2],
        [40.0, 67.5],
        [45.0, 67.8],
    ]

    lbase = [
        [-5.0, 2.513],
        [0.0, 2.501],
        [5.0, 2.489],
        [10.0, 2.477],
        [15.0, 2.465],
        [20.0, 2.454],
        [25.0, 2.442],
        [30.0, 2.430],
        [35.0, 2.418],
        [40.0, 2.406],
        [45.0, 2.394],
    ]

    # Temperature above highest value - set highest gamma and lambda and return
    if tc > gbase[-1][0]:
        gamma = gbase[-1][1]
        lambda_val = lbase[-1][1]
        return gamma, lambda_val

    # Temperature at or below value - set gamma and lambda
    for gb, lb in zip(gbase, lbase):
        if tc <= gb[0]:
            gamma = gb[1]
            lambda_val = lb[1]
            return gamma, lambda_val

    # If the temperature doesn't fall within the table, return None
    return None, None


if __name__ == "__main__":
    table()
