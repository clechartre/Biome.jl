"""Assign biomes as in BIOME3.5 according to a new scheme of biomes.
Jed Kaplan 3/1998"""

# Standard library
from typing import Iterable


def newassignbiome(
    optpft: int,
    woodpft: int,
    grasspft: int,
    subpft: int,
    optnpp: int,
    woodnpp: int,
    grassnpp: int,
    subnpp: int,
    greendays: int,
    gdd0: float,
    gdd5: float,
    tcm: float,
    present: Iterable,
    woodylai: float,
    grasslai: float,
    tmin: float,
) -> int:
    nppdif = optnpp - subnpp

    # Barren
    if optpft == 0:
        return 27

    # Arctic/Alpine Biomes
    if optpft == 13:
        return 26
    if optpft == 11:
        if gdd0 < 200.0:
            return 25
        elif gdd0 < 500.0:
            return 24
        else:
            return 23
    if optpft == 12:
        return 22

    # Desert
    if optpft == 10:
        if grasslai > 1.0:
            if tmin >= 0.0:
                return 13
            else:
                return 14
        else:
            return 21
    elif optnpp <= 100.0:
        if optpft <= 5 or optpft in [9, 10]:
            return 21
        elif optpft == 8:
            if subpft != 6 or subpft != 7:
                return 21

    # Boreal Biomes
    if optpft == 6:
        if gdd5 > 900.0 and tcm > -19.0:
            if present[3]:
                return 7
            else:
                return 8
        else:
            if present[3]:
                return 9
            else:
                return 10
    if optpft == 7:
        if subpft == 4:
            return 4
        elif subpft == 5:
            return 9
        elif gdd5 > 900.0 and tcm > -19.0:
            return 9
        else:
            return 11

    # Temperate Biomes
    if optpft == 8:
        if gdd0 >= 800.0:
            return 20
        else:
            return 22
    if optpft == 3:
        return 6
    if optpft == 4:
        if present[5]:
            if tcm < -15.0:
                return 9
            else:
                return 7
        elif present[2] or (present[4] and gdd5 > 3000.0 and tcm > 3.0):
            return 6
        else:
            return 4
    if optpft == 5:
        if present[2]:
            return 6
        elif subpft == 4 and nppdif < 50.0:
            return 5
        elif subpft == 7:
            return 9
        else:
            return 5

    # Savanna and Woodland
    if optpft == 14:
        if woodpft <= 2:
            if woodylai > 4.0:
                return 12
            else:
                return 13
        elif woodpft == 3:
            return 15
        elif woodpft == 4:
            return 16
        elif woodpft == 5:
            return 17
        elif woodpft in [6, 7]:
            return 18

    # Tropical Biomes
    if optpft <= 2 or optpft == 9:
        if optpft == 1:
            return 1
        if optpft == 2:
            if greendays > 300:
                return 1
            elif greendays > 250:
                return 2
            else:
                return 3
        if optpft == 9:
            return 19

    # Default to 0 if no conditions are met
    return 0


if __name__ == "__main__":
    newassignbiome()
