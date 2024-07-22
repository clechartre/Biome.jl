"""Competition submodule."""

# Standard library
from typing import List, Tuple

# Third-party
import numpy as np

# First-party
from BIOME4Py.newassignbiome import newassignbiome


def competition2(
    optnpp: np.ndarray,
    optlai: np.ndarray,
    wetness: np.ndarray,
    tmin: float,
    tprec,
    pfts,
    optdata: np.ndarray,
    output: List[float],
    diagmode: bool,
    numofpfts: float,
    gdd0: float,
    gdd5: float,
    tcm: float,
    pftpar: np.ndarray,
    soil: np.ndarray,
) -> Tuple[int, List[float]]:

    # Initialize all of the variables that index an array
    optpft = 0
    subpft = 0
    grasspft = 0
    pftmaxnpp = 0
    pftmaxlai = 0
    dom = 0
    wdom = 0
    wetpft = 0

    maxnpp = 0.0
    maxlai = 0.0
    temperatenpp = 0.0
    maxdiffnpp = 0.0
    grassnpp = 0.0

    grass, present = initialize_presence(numofpfts, optnpp)

    # Choose the dominant woody PFT on the basis of NPP
    for pft in range(numofpfts):
        if grass[pft]:  # grass PFTs
            if optnpp[pft] > grassnpp:
                grassnpp = optnpp[pft]
                grasspft = pft
        else:  # Woody PFTs
            pftmaxnpp, maxnpp, pftmaxlai, maxlai, woodpft = choose_woody_npp_lai(
                pft, optnpp, optlai, pftmaxnpp, maxnpp, pftmaxlai, maxlai
            )

    # Find average annual soil moisture value for all PFTs
    wetlayer, drymonth, wettest, driest = calculate_soil_moisture(numofpfts, optdata)

    # Determine the subdominant woody PFT
    optpft, wdom, subpft, subnpp = determine_subdominant_pft(pftmaxnpp, optnpp)

    # Determine the optimal PFT based on various conditions
    optpft, woodnpp, woodylai, greendays, grasslai = determine_optimal_pft(
        optpft,
        wdom,
        subpft,
        optnpp,
        optlai,
        grasspft,
        tmin,
        gdd5,
        tcm,
        tprec,
        wetness,
        optdata,
        present,
    )

    # Output some diagnostics if diagmode is on
    if diagmode:
        output_diagnostics(
            numofpfts,
            pfts,
            drymonth,
            driest,
            wetness,
            optdata,
            wdom,
            optnpp,
            optlai,
            grasspft,
            grassnpp,
            subpft,
        )

    # Format values for output
    dom, npp, lai, grasslai = format_values_for_output(
        optpft, wdom, grasspft, optnpp, optlai, grassnpp, wetness, optdata
    )

    # Call the newassignbiome function
    biome = newassignbiome(
        optpft,
        woodpft,
        grasspft,
        subpft,
        npp,
        woodnpp,
        grassnpp,
        subnpp,
        greendays,
        gdd0,
        gdd5,
        tcm,
        present,
        woodylai,
        grasslai,
        tmin,
    )

    output = assign_output_values(
        output,
        dom,
        lai,
        npp,
        optlai,
        optnpp,
        grasspft,
        wetness,
        wetlayer,
        optdata,
        optpft,
        tprec,
        pftpar,
        wdom,
        tcm,
        gdd0,
        gdd5,
    )

    return biome, output


def initialize_presence(
    numofpfts: float, optnpp: np.ndarray
) -> tuple[list[bool], list[bool]]:
    present = [False] * (numofpfts)  # Initialize the presence list
    grass = [False] * (numofpfts)  # Initialize the grass list

    for pft in range(numofpfts):
        if pft >= 8:
            grass[pft] = True
        else:
            grass[pft] = False

        grass[10] = False

        if optnpp[pft] > 0.0:
            present[pft] = True
        else:
            present[pft] = False

    present[12] = True
    return grass, present


def choose_woody_npp_lai(
    pft: int,
    optnpp: List[float],
    optlai: List[float],
    pftmaxnpp: int,
    maxnpp: float,
    pftmaxlai: int,
    maxlai: float,
) -> Tuple[int, float, int, float, int]:
    """Determine the dominant woody PFT based on NPP and LAI."""
    if optnpp[pft] > maxnpp:
        maxnpp = optnpp[pft]
        pftmaxnpp = pft

    if optlai[pft] > maxlai:
        maxlai = optlai[pft]
        pftmaxlai = pft

    elif optlai[pft] == maxlai:
        maxlai = optlai[pftmaxnpp]
        pftmaxlai = pftmaxnpp

    # I assume that the pft will correspond to woodpft in the broader function
    return pftmaxnpp, maxnpp, pftmaxlai, maxlai, pft


def calculate_soil_moisture(
    numofpfts: float, optdata: np.ndarray
) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """Calculate average annual soil moisture value for all PFTs."""
    wetlayer = np.zeros((numofpfts, 2))
    drymonth = np.zeros(numofpfts, dtype=int)
    wettest = np.full(numofpfts, -1.0)
    driest = np.full(numofpfts, 101.0)

    for pft in range(numofpfts):
        wetness_pft = 0.0
        wetlayer[pft, 0] = 0.0
        wetlayer[pft, 1] = 0.0
        drymonth[pft] = 0
        wettest[pft] = -1.0
        driest[pft] = 101.0

        for m in range(12):
            # Original range is 12 but we have to shift
            # indexing because of Python 0-indexing
            mwet = optdata[pft, m + 412]
            wetness_pft += mwet / 12.0
            wetlayer[pft, 0] += optdata[pft, m + 412] / 12.0  # top
            wetlayer[pft, 1] += optdata[pft, m + 424] / 12.0  # bottom
            if mwet > wettest[pft]:
                wettest[pft] = mwet
            if mwet < driest[pft]:
                drymonth[pft] = m + 1  # Adjust for 0-based index
                driest[pft] = mwet

    return wetlayer, drymonth, wettest, driest


def determine_subdominant_pft(pftmaxnpp, optnpp):
    """Determine the subdominant woody PFT (2nd in NPP)."""
    # Those may have to be moved out of the function at some point
    # if they are needed somewhere else later in competition2
    optpft = pftmaxnpp
    wdom = optpft

    subnpp = 0.0
    subpft = 0

    for pft in range(7):  # Loop through woody PFTs only
        if pft != wdom:
            if optnpp[pft] > subnpp:
                subnpp = optnpp[pft]
                subpft = pft

    return optpft, wdom, subpft, subnpp


def determine_optimal_pft(
    optpft: int,
    wdom: int,
    subpft: int,
    optnpp: List[float],
    optlai: List[float],
    grasspft: int,
    tmin: float,
    gdd5: float,
    tcm: float,
    tprec: float,
    wetness: List[float],
    optdata: List[List[float]],
    present: List[bool],
) -> Tuple[int, float, float, float, float]:
    """Determine the optimal PFT based on various conditions."""
    flop = False

    while True:
        woodylai = optlai[wdom]
        woodnpp = optnpp[wdom]
        grasslai = optlai[grasspft]

        if wdom != 0:
            firedays = optdata[wdom, 199]
            subfiredays = optdata[subpft, 199]
            greendays = optdata[wdom, 200]
        else:
            firedays = 0
            subfiredays = 0
            greendays = 0

        nppdif = optnpp[wdom] - optnpp[grasspft]
        ratio = 0.0

        if (wdom == 3 or wdom == 5) and tmin > 0.0:
            if gdd5 > 5000.0:
                wdom = 2
                continue

        if wdom == 1:
            if optnpp[wdom] < 2000.0:
                wdom = 2
                subpft = 1
                continue

        if wdom == 2:
            if woodylai < 2.0:
                optpft = grasspft
            elif grasspft == 9 and woodylai < 3.6:
                optpft = 14
            elif greendays < 270 and tcm > 21.0 and tprec < 1700.0:
                optpft = 14
            else:
                optpft = wdom

        if wdom == 3:
            if optnpp[wdom] < 140.0:
                optpft = grasspft
            elif woodylai < 1.0:
                optpft = grasspft
            elif woodylai < 2.0:
                optpft = 14
            else:
                optpft = wdom

        if wdom == 4:
            if woodylai < 2.0:
                optpft = grasspft
            elif firedays > 210 and nppdif < 0.0:
                if not flop and subpft != 0:
                    wdom = subpft
                    subpft = 4
                    flop = True
                    continue
                else:
                    optpft = grasspft
            elif woodylai < 3.0 or firedays > 180:
                if nppdif < 0.0:
                    optpft = 14
                elif not flop and subpft != 0:
                    wdom = subpft
                    subpft = 4
                    flop = True
                    continue
            else:
                optpft = wdom

        if wdom == 5:
            if present[3]:
                wdom = 3
                subpft = 5
                continue
            elif optnpp[wdom] < 140.0:
                optpft = grasspft
            elif woodylai < 1.2:
                optpft = 14
            else:
                optpft = wdom

        if wdom == 6:
            if optnpp[wdom] < 140.0:
                optpft = grasspft
            elif firedays > 90:
                if not flop and subpft != 0:
                    wdom = subpft
                    subpft = 6
                    flop = True
                    continue
                else:
                    optpft = wdom

        if wdom == 7:
            if optnpp[wdom] < 120.0:
                optpft = grasspft
            elif wetness[wdom] < 30.0 and nppdif < 0.0:
                optpft = grasspft
            else:
                optpft = wdom

        if wdom == 0:
            if grasspft != 0:
                optpft = grasspft
            elif optnpp[13] != 0.0:
                optpft = 13
            else:
                optpft = 0

        if optpft == 0 and present[10]:
            optpft = 10

        if optpft == 10:
            if grasspft != 9 and optnpp[grasspft] > optnpp[10]:
                optpft = grasspft
            else:
                optpft = 10

        if optpft == grasspft:
            if optlai[grasspft] < 1.8 and present[10]:
                optpft = 10
            else:
                optpft = grasspft

        if optpft == 11:
            if wetness[optpft] <= 25.0 and present[12]:
                optpft = 12

        break

    return optpft, woodnpp, woodylai, greendays, grasslai


def output_diagnostics(
    numofpfts: float,
    pfts: List[int],
    drymonth: List[int],
    driest: List[float],
    wetness: List[float],
    optdata: np.ndarray,
    wdom: int,
    optnpp: List[float],
    optlai: List[float],
    grasspft: int,
    grassnpp: float,
    subpft: int,
) -> None:
    """Output some diagnostic results."""
    for pft in range(numofpfts):
        if pfts[pft] != 0:
            print(
                f"{pft:5d}{drymonth[pft]:5d}{driest[pft]:6.2f}{wetness[pft]:6.2f}"
                f"{optdata[pft, 199]:5d}{optdata[pft, 200]:5d}"
            )

    woodylai = optlai[wdom]
    woodnpp = optnpp[wdom]

    print(" wpft  woodynpp   woodylai gpft grassnpp subpft phi")
    print(
        f"{wdom:5d}{woodnpp:10.2f}{woodylai:10.2f}{grasspft:5d}{grassnpp:10.2f}"
        f"{subpft:5d}{optdata[8, 52] / 100:8.2f}"
    )


def format_values_for_output(
    optpft: int,
    wdom: int,
    grasspft: int,
    optnpp: List[float],
    optlai: List[float],
    grassnpp: float,
    wetness: List[float],
    optdata: np.ndarray,
) -> Tuple[int, float, float, float]:
    """Format values for output."""
    dom = optpft

    if optpft == 14:
        woodnpp = optnpp[wdom]
        woodylai = optlai[wdom]
        grasslai = optlai[grasspft]

        npprat = woodnpp / grassnpp
        treepct = ((8.0 / 5.0) * npprat) - 0.54

        if treepct < 0.0:
            treepct = 0.0
        if treepct > 1.0:
            treepct = 1.0

        grasspct = 1.0 - treepct
        dom = wdom
        lai = (woodylai + (2.0 * grasslai)) / 3.0
        npp = (woodnpp + (2.0 * grassnpp)) / 3.0

        # NEP
        for pos in range(137, 149):
            optdata[dom, pos] = (
                optdata[wdom, pos] + (2.0 * optdata[grasspft, pos])
            ) / 3.0

        # DeltaA
        for pos in range(80, 92):
            optdata[dom, pos] = (
                optdata[wdom, pos] + (2.0 * optdata[grasspft, pos])
            ) / 3.0

        # NPP
        for pos in range(37, 49):
            optdata[dom, pos] = (
                optdata[wdom, pos] + (2.0 * optdata[grasspft, pos])
            ) / 3.0

        # Rh
        for pos in range(123, 125):
            optdata[dom, pos] = (
                optdata[wdom, pos] + (2.0 * optdata[grasspft, pos])
            ) / 3.0

        # DeltaE
        optdata[dom, 50] = (
            treepct * optdata[wdom, 50] + grasspct * optdata[grasspft, 50]
        )

        # %C4 NPP
        optdata[dom, 98] = (optdata[wdom, 98] + (2.0 * optdata[grasspft, 98])) / 3.0

    if optlai[dom] == 0.0:
        optpft = 0

    npp = optnpp[dom]
    lai = optlai[dom]
    grasslai = optlai[grasspft]

    return dom, npp, lai, grasslai


def assign_output_values(
    output: np.ndarray,
    dom: int,
    lai: float,
    npp: float,
    optlai: List[float],
    optnpp: List[float],
    grasspft: int,
    wetness: List[float],
    wetlayer: np.ndarray,
    optdata: np.ndarray,
    optpft: int,
    tprec: float,
    pftpar: List[List[float]],
    wdom: int,
    tcm: float,
    gdd0: float,
    gdd5: float,
) -> np.ndarray:
    """Assign values to the output array."""
    output[1] = np.rint(lai * 100.0).astype(int)
    output[2] = np.rint(npp).astype(int)
    output[3] = np.rint(optlai[dom] * 100.0).astype(int)
    output[4] = np.rint(optnpp[dom]).astype(int)
    output[5] = np.rint(optlai[grasspft] * 100.0).astype(int)
    output[6] = np.rint(optnpp[grasspft]).astype(int)

    # Annual APAR / annual PAR expressed as a percentage:
    output[7] = optdata[dom, 7]

    # Respiration costs (for dom plant type, wood or grass):
    output[8] = optdata[dom, 8]

    # Soil moisture for dominant pft:
    output[9] = np.rint(wetness[dom] * 10.0).astype(int)

    # Predicted runoff (for dom plant type, wood or grass):
    output[10] = optdata[dom, 5]

    # Number of the dominant (woody) pft:
    output[11] = optpft

    # Total annual precipitation (hopefully < 9999mm):
    output[12] = min(np.rint(tprec).astype(int), 9999)

    # Total annual PAR MJ.m-2.yr-1
    output[13] = optdata[dom, 6]

    output[14] = (
        np.rint(100.0 * (lai / optlai[dom])).astype(int) if optlai[dom] != 0 else 0
    )

    output[15] = np.rint(npp - optnpp[dom]).astype(int)

    if lai < 2.0:  # FVC
        output[16] = np.rint((lai / 2.0) * 100.0).astype(int)
    else:
        output[16] = 100

    if dom == 0:
        output[17] = 0.0
    else:
        output[17] = np.rint(pftpar[dom][5] * 100.0).astype(int)

    # Store monthly fpar values in positions 25-36:
    for month in range(12):
        output[24 + month + 1] = optdata[dom, 24 + month + 1]

    # Annual mean delta 13C stored in position 50-51
    output[49] = optdata[dom, 49] / 10.0  # total deltaA
    output[50] = optdata[dom, 50]  # average deltaA for mixed ecosystems
    output[51] = optdata[7, 51]  # phi value

    # Optimized NPP for all PFTs
    for i in range(1, 12):
        output[59 + i] = optnpp[i]

    # Monthly discrimination for one PFT
    for pos in range(80, 92):
        output[pos - 1] = optdata[dom, pos]

    # Monthly NPP for one PFT
    for pos in range(37, 49):
        output[pos - 1] = optdata[dom, pos]

    # Monthly delta E for dominant PFT
    for pos in range(101, 113):
        output[pos - 1] = optdata[dom, pos]

    # Monthly heterotrophic respiration for dominant PFT
    for pos in range(123, 125):
        output[pos - 1] = optdata[dom, pos]

    # Monthly isoresp (product)
    for pos in range(125, 137):
        output[pos - 1] = optdata[dom, pos]

    # Monthly net C flux (NPP - respiration)
    for pos in range(137, 149):
        output[pos - 1] = optdata[dom, pos]

    # Monthly mean gc
    for pos in range(160, 173):
        output[pos - 1] = optdata[dom, pos]

    # Monthly LAI
    for pos in range(173, 185):
        output[pos - 1] = optdata[dom, pos]

    # Monthly runoff
    for pos in range(185, 197):
        output[pos - 1] = optdata[dom, pos]

    output[148] = optdata[dom, 148]  # annual NEP
    output[149] = optdata[dom, 149]  # annual mean A/g

    output[96] = optdata[dom, 96]  # Mean annual heterotrophic respiration scalar
    output[97] = optdata[dom, 97]  # % of NPP that is C4
    output[98] = optdata[dom, 98]  # annual heterotrophic respiration

    output[198] = optdata[wdom, 198]  # firedays
    output[199] = optdata[dom, 199]  # greendays

    # Ten-day LAI * 100
    for pos in range(201, 242):
        output[pos - 1] = optdata[dom, pos]

    # Monthly soil moisture, mean, top, and bottom layers * 100
    for pos in range(388, 400):
        output[pos - 1] = optdata[dom, pos - 375]  # mean

    for pos in range(412, 424):
        output[pos - 1] = optdata[dom, pos]  # top

    for pos in range(424, 436):
        output[pos - 1] = optdata[dom, pos]  # bottom

    output[424] = np.rint(wetlayer[dom, 0])
    output[425] = np.rint(wetlayer[dom, 1])
    output[426] = (
        np.rint((wetlayer[dom, 0] / wetlayer[dom, 1]) * 100.0)
        if wetlayer[dom, 1] != 0
        else 0
    )

    output[449] = optdata[dom, 449]  # mean Klit
    output[450] = optdata[dom, 450]  # mean Ksoil
    output[451] = tcm  # coldest month temperature
    output[452] = gdd0  # gdd0
    output[453] = gdd5  # gdd5

    return output


if __name__ == "__main__":
    competition2()
