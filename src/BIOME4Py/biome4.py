"""Biome4 orchestrator."""

# Third-party
import numpy as np

# First-party
from BIOME4Py.climdata import climdata
from BIOME4Py.competition2 import competition2
from BIOME4Py.constraints import constraints
from BIOME4Py.findnpp import findnpp
from BIOME4Py.growth_subroutines.daily import daily
from BIOME4Py.pftdata import pftdata
from BIOME4Py.phenology import phenology
from BIOME4Py.ppeett import ppeett
from BIOME4Py.snow import snow
from BIOME4Py.soiltemp import soiltemp


def biome4(vars_in, output):
    numofpfts = 13
    # Initialize variables
    # Reset the output matrix
    optdata = np.zeros((numofpfts + 1, 500), dtype=int)
    pfts = np.zeros(numofpfts, dtype=int)

    temp = np.zeros(12)
    prec = np.zeros(12)
    clou = np.zeros(12)
    soil = np.zeros(5)
    dtemp = np.zeros(365)
    dclou = np.zeros(365)
    dprecin = np.zeros(365)

    dpet = np.zeros(365)
    dphen = np.zeros((365, 2))
    realout = np.zeros((numofpfts + 1, 500))
    optnpp = np.zeros(numofpfts + 1)
    optlai = np.zeros(numofpfts + 1)
    pftpar = np.zeros((25, 25))
    k = np.zeros(12)
    wetness = np.zeros(numofpfts + 1)
    tsoil = np.zeros(12)
    radanom = np.zeros(12)

    biomename = [
        "Tropical evergreen forest",
        "Tropical semi-deciduous forest",
        "Tropical deciduous forest/woodland",
        "Temperate deciduous forest",
        "Temperate conifer forest",
        "Warm mixed forest",
        "Cool mixed forest",
        "Cool conifer forest",
        "Cold mixed forest",
        "Evegreen taiga/montane forest",
        "Deciduous taiga/montane forest",
        "Tropical savanna",
        "Tropical xerophytic shrubland",
        "Temperate xerophytic shrubland",
        "Temperate sclerophyll woodland",
        "Temperate broadleaved savanna",
        "Open conifer woodland",
        "Boreal parkland",
        "Tropical grassland",
        "Temperate grassland",
        "Desert",
        "Steppe tundra",
        "Shrub tundra",
        "Dwarf shrub tundra",
        "Prostrate shrub tundra",
        "Cushion-forbs, lichen and moss",
        "Barren",
        "Land ice",
    ]

    # Assign the variables that arrived in the array vars_in
    lon = vars_in[48]
    lat = vars_in[0]  # vars_in[48] - (vars_in[0] / vars_in[49])
    co2 = vars_in[1]
    p = vars_in[2]
    tminin = vars_in[3]

    for i in range(12):
        temp[i] = vars_in[4 + i]
        prec[i] = vars_in[16 + i]
        clou[i] = vars_in[28 + i]

    for i in range(4):
        soil[i] = vars_in[40 + i]

    iopt = int(round(vars_in[45]))

    if iopt == 1:
        diagmode = True
    else:
        diagmode = False

    # Set a dummy rad anomaly (not used in this version)
    radanom = [1.0] * 12

    # Initialize soil texutre specific parameters
    k[0] = soil[0]
    k[1] = soil[1]
    k[4] = soil[2]
    k[5] = soil[3]

    # Linearly interpolate mid-month values to quasi-daily values:
    dtemp = daily(temp)
    dclou = daily(clou)
    dprecin = daily(prec)

    # Calculate total annual precipitation
    tprec = sum(prec)

    # Initialize parameters derived from climate data:
    climate_results = climdata(temp, prec, dtemp)
    tsoil = soiltemp(temp, soil)

    # Calculate mid-month values for pet,sun & dayl from temp,cloud & lat:
    ppeett_results = ppeett(lat, dtemp, dclou, radanom, temp)

    # Run snow model
    snow_results = snow(dtemp, dprecin)

    # Initialize the evergreen phenology
    dphen = [[1.0, 1.0] for _ in range(365)]

    # Initialize pft specific parameters
    pftpar = pftdata()

    # Rulebase of absolute constraints to select potentially presents pfts:
    # tcm is temperature of the coldest month and twm of warmest month
    tcm = np.min(temp)
    twm = np.max(temp)
    tdif = (
        twm - tcm
    )  # I haven't found any definition in the original code, this is an assumption I made
    tmin, ts, clindex, pfts = constraints(
        tcm,
        twm,
        tminin,
        climate_results.gdd5,
        ppeett_results.rad0,
        climate_results.gdd0,
        snow_results.maxdepth,
    )

    # The tropical evergreen pft is not used in this version
    # of the model.  This is because the tropical deciduous tree
    # will be evergreen if it is not subject to water stress.
    # Otherwise the two pft's are parameterized in the same way,
    # so not using the pft saves computation time.
    pfts[0] = 0

    if diagmode:
        diag_mode(
            lon,
            lat,
            tcm,
            tmin,
            climate_results.gdd5,
            tprec,
            snow_results.maxdepth,
            soil,
            k,
        )

    # Calculate optimal LAI and NPP for the selected PFTs
    for pft in range(numofpfts):
        if pfts[pft] != 0:
            if pftpar[pft][0] >= 2:
                ddayl = daily(ppeett_results.dayl)
                # Initialize the generic summergreen phenology
                dphen = phenology(dtemp, temp, tcm, tdif, tmin, pft, ddayl, pftpar)

            # Assumed that annp = annual precipitation and subbed by tprec (total precipitation)
            optdata, optlai[pft], optnpp[pft], realin = findnpp(
                pfts,
                pft,
                optlai[pft],
                optnpp[pft],
                tprec,
                dtemp,
                ppeett_results.sun,
                temp,
                snow_results.dprec,
                snow_results.dmelt,
                ppeett_results.dpet,
                ppeett_results.dayl,
                k,
                pftpar,
                optdata,
                dphen,
                co2,
                p,
                tsoil,
                realout,
                numofpfts,
            )

    # Select dominant plant type/s on the basis of modelled optimal NPP & LAI:
    biome, optdata = competition2(
        optnpp,
        optlai,
        wetness,
        tmin,
        tprec,
        pfts,
        optdata,
        output,
        diagmode,
        numofpfts,
        climate_results.gdd0,
        climate_results.gdd5,
        tcm,
        pftpar,
        soil,
    )

    # Final output biome is given by the integer biome:
    output[0] = biome
    output[47] = lon
    output[48] = lat

    for pft in range(numofpfts):
        output[300 + pft] = int(round(optnpp[pft]))
        output[300 + numofpfts + pft] = int(round(optlai[pft] * 100.0))
        if pfts[pft] != 0:
            if diagmode:
                # Formatting the diagnostic output
                formatted_output = "{:3d} {:5.2f} {:7.1f} {:6.1f}".format(
                    pft, optlai[pft], optnpp[pft], wetness[pft]
                )
                # Adding optdata(pft, i) from index 37 to 48, divided by 10
                formatted_output += "".join(
                    " {:6.1f}".format(optdata[pft, i] / 10.0) for i in range(37, 49)
                )
                # Printing the formatted output
                print(formatted_output)
    if diagmode:
        diagnostic_output(biome, biomename, optdata)

    return output


def diag_mode(lon, lat, tcm, tmin, gdd5, tprec, maxdepth, soil, k):
    print(f"Longitude: {lon:.2f} Latitude: {lat:.2f}")
    print(f"Tcm and Tmin are: {tcm:.1f} and {tmin:.1f} degrees C respectively.")
    print(f"GDD5 is: {gdd5:.1f} and total annual precip is: {tprec:.1f} mm.")
    print(f"Maximum snowdepth is: {maxdepth * 10:.1f} mm.")
    print(f"The current soil parameters are: {soil}")

    yorn = input("Enter new soil parameters? (y/n): ").strip().lower()

    if yorn == "y":
        soil[0] = float(input("Percolation index ~(0-7): ").strip())
        soil[1] = soil[0]
        soil[2] = float(input("Top layer whc ~(0-999): ").strip())
        soil[3] = float(input("Bottom layer whc ~(0-999): ").strip())

        # Reinitialize soil texture specific parameters
        k[0] = soil[0]
        k[1] = soil[1]
        k[4] = soil[2]
        k[5] = soil[3]

    print("The following PFTs will be computed:")


def diagnostic_output(biome, biomename, optdata):

    # Print biome information
    print(f"Biome {biome} {biomename[biome]}")

    sumagnpp = 0.0
    delag = 0.0

    # First loop: Calculate sumagnpp
    for i in range(1, 7):
        if optdata[8, 36 + i] > 0:
            sumagnpp += optdata[8, 36 + i] / 10.0

    # Second loop: Calculate delag
    for i in range(1, 7):
        if optdata[8, 36 + i] > 0:
            wtagnpp = optdata[8, 36 + i] / (sumagnpp * 10.0)
            delag += (optdata[8, 79 + i] * wtagnpp) / 100.0

    # Print the calculated delag
    print(f"The deltaA of C3 grass is {delag:.2f} per mil.")

    # Pause for user input (simulating 'press return to continue')
    input("Press return to continue")
