"""Calculate NPP of one PFT."""

# Standard library
import math
from typing import List, Tuple

# Third-party
import numpy as np

# First-party
from BIOME4Py.growth_subroutines.c4photo import c4photo
from BIOME4Py.growth_subroutines.calcphi import calcphi
from BIOME4Py.growth_subroutines.daily import daily
from BIOME4Py.growth_subroutines.fire import fire
from BIOME4Py.growth_subroutines.hetresp import hetresp
from BIOME4Py.growth_subroutines.hydrology import hydrology
from BIOME4Py.growth_subroutines.isotope import isotope
from BIOME4Py.growth_subroutines.photosynthesis import photosynthesis
from BIOME4Py.growth_subroutines.respiration import respiration


def growth(
    maxlai: float,
    annp: float,
    sun: List[float],
    temp: List[float],
    dprec: List[float],
    dmelt: List[float],
    dpet: List[float],
    k: List[float],
    pftpar: List[List[float]],
    pft: int,
    dayl: List[float],
    dtemp: List[float],
    outv: List[int],
    dphen: List[List[float]],
    co2: float,
    p: float,
    tsoil: List[float],
    realin: List[float],
) -> Tuple[float, List[int], List[int]]:
    # Initialize the arrays and set values
    midday, days, optratioa, kk = initialize_arrays()
    ca = co2 * 1e-6
    rainscalar = 1000
    wst = annp / rainscalar
    if wst >= 1:
        wst = 1
    phentype = round(pftpar[pft][0])
    mgmin = pftpar[pft][1]
    root = pftpar[pft][5]
    age = pftpar[pft][6]
    c4pot = pftpar[pft][10]
    grass = round(pftpar[pft][9])
    emax = pftpar[pft][2]
    maxfvc = 1 - math.exp(-kk[pft] * maxlai)
    phi = 0
    doptgc = [0.0] * 12

    # Set the value of optratio depending on whether c4 plant or not.
    c4, optratio = determine_c4_and_optratio(pft, optratioa)

    # Calculate monthly values for the optimum non-water-stressed gc (optgc)
    maxgc = 0
    for m in range(12):
        tsecs = 3600 * dayl[m]

    # First find the gc value resulting from the max ci/ca ratio
    # Calculate optgc
    hydrology_results = [None] * 12
    optgc = [0.0] * 12
    maxgc = 0.0
    for m in range(12):  # Assuming m corresponds to months 0-11
        fpar = 1.0 - math.exp(-kk[pft] * maxlai)

        if c4:
            photosynthesis_results = c4photo(
                optratio, sun[m], dayl[m], temp[m], age, fpar, p, ca, pft
            )
        else:
            photosynthesis_results = photosynthesis(
                optratio, sun[m], dayl[m], temp[m], age, fpar, p, ca, pft
            )

        if tsecs > 0 and photosynthesis_results.aday > 0.0:
            gt = (
                mgmin
                + (1.6 * photosynthesis_results.aday) / (ca * (1.0 - optratio)) / tsecs
            )
        else:
            gt = 0.0

        # This gives us the final non-water-stressed gc value
        optgc[m] = gt

        # Store output values:
        if maxgc <= optgc[m]:
            maxgc = optgc[m]

        # Calculate water balance and phenology for this pft/s and fvc/s
        # Subroutine hydrology returns monthly mean gc & summed fvc value
        doptgc = daily(optgc)

    # I subbed gcopt in the original function definition by doptgc
    # outputted from doptgc
    hydrology_results = hydrology(
        dprec,
        dmelt,
        dpet,
        root,
        k,
        maxfvc,
        pft,
        phentype,
        wst,
        doptgc,
        mgmin,
        dphen,
        dtemp,
        grass,
        emax,
        pftpar,
    )

    # Now use the monthly values of fvc & meangc to calculate net & gross
    # photosynthesis for an "average" day in the month and multiply by the
    # number of days in the month to get total monthly photosynthesis.

    # Initialize lists to store monthly values
    mgpp = [0] * 12
    mlresp = [0] * 12
    monthlyfpar = [0] * 12
    monthlyparr = [0] * 12
    monthlyapar = [0] * 12
    CCratio = [0] * 12
    isoresp = [0] * 12

    if c4:
        c4gpp = [0] * 12
        c4fpar = [0] * 12
        c4parr = [0] * 12
        c4apar = [0] * 12
        c4ccratio = [0] * 12
        c4leafresp = [0] * 12

    # Initialize annual variables
    alresp = 0
    gpp = 0
    annualparr = 0
    annualapar = 0

    for month in range(12):
        m = month
        # If meangc is zero then photosynthesis must also be zero
        if hydrology_results.meangc[m] == 0.0:
            gphot = 0.0
            rtbis = 0.0
            # Original code refers to monthly photosynthesis but I am only outputting a float
            # for leafresp
            # I think this is a bug in the original code
            leafresp = photosynthesis_results.leafresp * (
                hydrology_results.meanfvc[m] / maxfvc
            )
        else:
            # Iterate to a solution for gphot given this meangc value using bisection method
            x1 = 0.02
            x2 = optratio + 0.05
            rtbis = x1
            dx = x2 - x1
            for j in range(10):
                dx *= 0.5
                xmid = rtbis + dx

                fpar = hydrology_results.meanfvc[m]

                if c4:
                    c4photo_results = c4photo(
                        xmid, sun[m], dayl[m], temp[m], age, fpar, p, ca, pft
                    )
                    igphot, aday = c4photo_results.grossphot, c4photo_results.aday
                else:
                    photosynthesis_results = photosynthesis(
                        xmid, sun[m], dayl[m], temp[m], age, fpar, p, ca, pft
                    )
                    igphot, aday = (
                        photosynthesis_results.grossphot,
                        photosynthesis_results.aday,
                    )

                gt = 3600 * dayl[m] * hydrology_results.meangc[m]

                if gt == 0.0:
                    ap = 0.0
                else:
                    ap = mgmin + (gt / 1.6) * (ca * (1.0 - xmid))

                fmid = aday - ap

                if fmid <= 0.0:
                    rtbis = xmid
                    gphot = igphot

            leafresp = photosynthesis_results.leafresp * (
                hydrology_results.meanfvc[m] / maxfvc
            )

        # Calculate monthly PAR values
        monthlyfpar[m] = hydrology_results.meanfvc[m]
        monthlyparr[m] = sun[m] * days[m] * 1e-6
        monthlyapar[m] = monthlyparr[m] * monthlyfpar[m]

        # Store monthly results in lists
        mgpp[m] = days[m] * gphot
        mlresp[m] = days[m] * leafresp
        CCratio[m] = rtbis
        isoresp[m] = mlresp[m]

        # Accumulate annual totals
        annualapar += monthlyapar[m]
        annualparr += monthlyparr[m]
        gpp += mgpp[m]
        alresp += mlresp[m]

        # If C4, store monthly C4 values
        if c4:
            c4gpp[m] = mgpp[m]
            c4fpar[m] = monthlyfpar
            c4parr[m] = monthlyparr
            c4apar[m] = monthlyapar
            c4ccratio[m] = rtbis
            c4leafresp[m] = mlresp[m]

    # Calculate monthly LAI
    monthlylai = [0] * 12
    for month in range(12):
        monthlylai[m] = math.log(1 - monthlyfpar[m]) / (-1 * kk[pft])

    # Calculate 10-day LAI
    tendaylai = []
    i = 1
    for day in range(0, 364, 10):
        lai_value = (math.log(1 - hydrology_results.dayfvc[day])) / (-1.0 * kk[pft])
        tendaylai.append(lai_value)
        i += 1

    # Calculate annual FPAR (%) from annual totals of APAR and PAR
    if annualapar == 0:
        annualfpar = 0.0
    else:
        annualfpar = 100 * annualapar / annualparr

    # Calculate annual respiration costs to find annual NPP
    respiration_results = respiration(gpp, alresp, temp, grass, maxlai, fpar, pft)

    # Calculate monthly NPP
    nppsum = 0
    mnpp = [0] * 12
    c4mnpp = [0] * 12
    for m in range(12):
        mnpp[m] = 0

    # Calculate maintenance and growth respiration for months 1 to 11
    # Initialize the stores
    maintresp = [0] * 12
    mgrowresp = [0] * 12
    for m in range(10):
        maintresp[m] = (
            mlresp[m]
            + respiration_results.backleafresp[m]
            + respiration_results.mstemresp[m]
            + respiration_results.mrootresp[m]
        )

        mgrowresp[m] = 0.02 * (mgpp[m + 1] - maintresp[m + 1])

        if mgrowresp[m] < 0.0:
            mgrowresp[m] = 0.0
        mnpp[m] = mgpp[m] - (maintresp[m] + mgrowresp[m])

    # Calculate maintenance and growth respiration for month 12
    maintresp[11] = (
        mlresp[11]
        + respiration_results.backleafresp[11]
        + respiration_results.mstemresp[11]
        + respiration_results.mrootresp[11]
    )

    mgrowresp[11] = 0.02 * (mgpp[0] - maintresp[0])
    if mgrowresp[11] < 0.0:
        mgrowresp[11] = 0.0
    mnpp[11] = mgpp[11] - (maintresp[11] + mgrowresp[11])

    # Sum up NPP and handle c4 case
    for m in range(12):
        if c4:
            c4mnpp[m] = mnpp[m]
        nppsum += mnpp[m]

    # Compare C3 and C4 NPP and choose the more productive one on a monthly basis
    nppsum, c4pct, c4month = compare_c3_c4_npp(
        pft,
        mnpp,
        c4mnpp,
        monthlyfpar,
        monthlyparr,
        monthlyapar,
        CCratio,
        isoresp,
        nppsum,
        c4,
    )

    if respiration_results.npp != nppsum:
        npp = nppsum

    # FIXME I have to figure out how to fix this
    # I have a negtive npp, what do I do with it? Set to 0 and move on?
    # if npp <= 0.0:
    #     return
    # else:

    if gpp > 0.0:
        if pft >= 8:
            phi = calcphi(mgpp)

    # In the original code, this is in the if statement, but I need the results
    # for the next function call so I cannot affor to not run it
    # Calculate carbon isotope fractionation in plants
    isotope_results = isotope(CCratio, ca, temp, isoresp, c4month, mgpp, phi, gpp)

    # Call subroutine to calculate heterotrophic respiration
    # Using a workaround to get unique values for meanwr to pass as moist
    moist = np.mean(hydrology_results.meanwr, axis=1)
    hetresp_results = hetresp(
        pft,
        respiration_results.npp,
        temp,
        tsoil,
        hydrology_results.meanaet,
        moist,
        isotope_results.meanC3,
    )

    # Zero the annual hetresp calculation
    annresp = 0.0

    # Sum up monthlies to get an annual hetresp = npp
    for m in range(12):
        annresp += hetresp_results.Rtot[m]

    # Initialize annual NEP
    annnep = 0.0

    # Calculate monthly ecosystem carbon flux NPP-Hetresp
    cflux = [0.0] * 12  # Assuming cflux is a list of length 12
    for m in range(12):
        cflux[m] = mnpp[m] - hetresp_results.Rtot[m]
        annnep += cflux[m]

    # Call the fire subroutine
    fire_results = fire(hydrology_results.wet, pft, lai_value, respiration_results.npp)

    outv, realin = output_results(
        hydrology_results.meanwr,
        monthlyfpar,
        npp,
        hydrology_results.annaet,
        maxgc,
        respiration_results.stemresp,
        hydrology_results.runnoff,
        annualparr,
        annualfpar,
        respiration_results.percentcost,
        isotope_results.meanC3,
        isotope_results.meanC4,
        phi,
        hetresp_results.Rmean,
        c4pct,
        annresp,
        mnpp,
        isotope_results.C3DA,
        hetresp_results.isoR,
        hetresp_results.Rtot,
        hetresp_results.isoflux,
        cflux,
        hydrology_results.meangc,
        monthlylai,
        hydrology_results.runoffmonth,
        mgpp,
        annnep,
        fire_results.firedays,
        hydrology_results.greendays,
        tendaylai,
        hetresp_results.meanKlit,
        hetresp_results.meanKsoil,
        outv,
        realin,
    )

    return npp, outv, realin


def initialize_arrays() -> Tuple[List[int], List[int], List[float], List[float]]:
    midday = [16, 44, 75, 105, 136, 166, 197, 228, 258, 289, 319, 350]
    days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    optratioa = [0.95, 0.9, 0.8, 0.8, 0.9, 0.8, 0.9, 0.65, 0.65, 0.70, 0.90, 0.75, 0.80]
    kk = [0.7, 0.7, 0.6, 0.6, 0.5, 0.5, 0.4, 0.4, 0.4, 0.3, 0.5, 0.3, 0.6]
    return midday, days, optratioa, kk


def determine_c4_and_optratio(pft: int, optratioa: List[float]) -> Tuple[bool, float]:
    if pft in [8, 9, 10]:
        c4 = True
    else:
        c4 = False

    if c4:
        optratio = 0.4
    else:
        optratio = optratioa[pft]

    return c4, optratio


def compare_c3_c4_npp(
    pft: int,
    mnpp: List[float],
    c4mnpp: List[float],
    monthlyfpar: List[float],
    monthlyparr: List[float],
    monthlyapar: List[float],
    CCratio: List[float],
    isoresp: List[float],
    nppsum: float,
    c4: bool,
) -> float:
    if pft == 10:
        if c4:
            c4 = False
            # Compute everything again, with C3 pathway
            nppsum, c4pct, c4month = compare_c3_c4_npp(
                pft,
                mnpp,
                c4mnpp,
                monthlyfpar,
                monthlyparr,
                monthlyapar,
                CCratio,
                isoresp,
                nppsum,
                c4,
            )

    c4months = 0
    annc4npp = 0.0

    c4month = [False] * 12
    for m in range(12):
        if pft == 9:
            c4month[m] = [True] * 12

    if pft == 10:
        for m in range(12):
            if c4mnpp[m] > mnpp[m]:
                c4months += 1

        if c4months >= 3:
            for m in range(12):
                if c4mnpp[m] > mnpp[m]:
                    c4month[m] = True

    totnpp = 0.0

    for m in range(12):
        if c4month[m]:
            mnpp[m] = c4mnpp[m]
            annc4npp += c4mnpp[m]
            totnpp += mnpp[m]

            # I honestly do not think I need to do this, it would just be circular from within
            # the main function
            # monthlyfpar[m] = c4fpar[m]
            # monthlyparr[m] = c4parr[m]
            # monthlyapar[m] = c4apar[m]
            # CCratio[m] = c4ccratio[m]
            # isoresp[m] = c4leafresp[m]
        else:
            totnpp += mnpp[m]

    if c4months >= 2:
        nppsum = totnpp

    # Calculate % of annual npp that is C4
    c4pct = annc4npp / nppsum if nppsum > 0 else 0.0

    return nppsum, c4pct, c4month


def output_results(
    meanwr: List[List[float]],
    monthlyfpar: List[float],
    npp: float,
    annaet: float,
    maxgc: float,
    stemresp: float,
    runoff: float,
    annualparr: float,
    annualfpar: float,
    fr: float,
    isoC3: float,
    isoC4: float,
    phi: float,
    Rmean: float,
    c4pct: float,
    annresp: float,
    mnpp: List[float],
    C3DA: List[float],
    riso: List[float],
    rtot: List[float],
    riflux: List[float],
    cflux: List[float],
    meangc: List[float],
    monthlylai: List[float],
    runoffmo: List[float],
    mgpp: List[float],
    annnep: float,
    firedays: float,
    greendays: int,
    tendaylai: List[float],
    meanKlit: float,
    meanKsoil: float,
    outv: List[float],
    realin: List[float],
) -> Tuple[List[float], List[float]]:
    anngasum = 0.0
    mcount = 0

    for m in range(12):
        outv[11 + m] = round(100 * meanwr[m][0])
        outv[411 + m] = round(100 * meanwr[m][1])
        outv[423 + m] = round(100 * meanwr[m][2])
        outv[23 + m] = round(100 * monthlyfpar[m])

    outv[0] = round(npp)
    outv[2] = round(annaet)
    outv[3] = round(maxgc)
    outv[4] = round(stemresp)
    outv[5] = round(runoff)
    outv[6] = round(annualparr)
    outv[7] = round(annualfpar)
    outv[8] = round(fr)
    outv[49] = round(isoC3 * 10)
    outv[50] = round(isoC4 * 10)
    outv[51] = round(phi * 100)
    outv[96] = round(Rmean * 100)
    outv[97] = round(c4pct * 100)
    outv[98] = round(annresp * 10)

    for m in range(12):
        realin[35 + m] = mnpp[m]
        outv[78 + m] = round(C3DA[m] * 100)
        outv[35 + m] = round(mnpp[m] * 10)
        outv[99 + m] = round(riso[m] * 10)
        outv[111 + m] = round(rtot[m] * 10)
        outv[123 + m] = round(riflux[m] * 10)
        outv[135 + m] = round(cflux[m] * 10)
        outv[159 + m] = round(meangc[m])
        outv[171 + m] = round(monthlylai[m] * 100)
        outv[183 + m] = round(runoffmo[m])

        if meangc[m] != 0:
            mcount += 1
            anngasum += mgpp[m] / meangc[m]

    outv[149] = round((anngasum / mcount) * 100) if mcount != 0 else 0
    outv[148] = round(annnep * 10)
    outv[198] = round(firedays)
    outv[199] = greendays

    for i in range(37):
        outv[199 + i + 1] = round(tendaylai[i] * 100)

    outv[449] = round(meanKlit * 100)
    outv[450] = round(meanKsoil * 100)

    return outv, realin


if __name__ == "__main__":
    growth()
