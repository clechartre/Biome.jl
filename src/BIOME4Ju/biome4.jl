"""Biome4 orchestrator."""

module BIOME4

# Third-party
using LinearAlgebra
using Printf

# First-party
include("./climdata.jl")
include("./competition2.jl")
include("./constraints.jl")
include("./findnpp.jl")
include("./growth_subroutines/daily.jl")
include("./pftdata.jl")
include("./phenology.jl")
include("./ppeett.jl")
include("./snow.jl")
include("./soiltemp.jl")

using .ClimateData
using .Competition
using .Constraints
using .Daily
using .FindNPP
using .PFTData
using .Phenology
using .Ppeett
using .SoilTemperature
using .Snow

function biome4(vars_in::Vector{Union{T, U}}, output::Vector{T}) where {T <: Real, U <: Int}
    numofpfts = 13

    # Initialize variables
    optdata = zeros(T, numofpfts+1, 500)
    pfts = zeros(Int, numofpfts)

    temp = zeros(T, 12)
    prec = zeros(T, 12)
    clou = zeros(T, 12)
    soil = zeros(T, 5)

    dphen = ones(T, 365, 2)
    realout = zeros(T, numofpfts+1, 500) # original fortran code uses 0-indexing for this one
    optnpp = zeros(T, numofpfts+1) # original fortran code uses 0-indexing for this one
    optlai = zeros(T, numofpfts+1) # original fortran code uses 0-indexing for this one
    pftpar = zeros(T, 25, 25)
    k = zeros(T, 12)
    tsoil = zeros(T, 12)
    radanom = zeros(T, 12)

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
        "Evergreen taiga/montane forest",
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
        "Land ice"
    ]

    # Assign the variables that arrived in the array vars_in
    lon = vars_in[49]
    lat = vars_in[1]  # vars_in[49] - (vars_in[1] / vars_in[50])
    co2 = vars_in[2]
    p = vars_in[3]
    tminin = vars_in[4]

    for i in 1:12
        temp[i] = vars_in[4 + i]
        prec[i] = vars_in[16 + i]
        clou[i] = vars_in[28 + i]
    end

    for i in 1:4
        soil[i] = vars_in[40 + i]
    end

    iopt = round(Int, vars_in[46])

    diagmode = iopt == 1

    # Set a dummy rad anomaly (not used in this version)
    radanom .= T(1.0)

    # Initialize soil texture specific parameters
    k[1] = soil[1]
    k[2] = soil[2]
    k[5] = soil[3]
    k[6] = soil[4]

    # Linearly interpolate mid-month values to quasi-daily values:
    dtemp = Daily.daily(temp)
    dclou = Daily.daily(clou)
    dprecin = Daily.daily(prec)

    # Initialize parameters derived from climate data:
    climate_results = ClimateData.climdata(temp, prec, dtemp)
    tprec = sum(prec)
    tsoil = SoilTemperature.soiltemp(temp)

    # Calculate mid-month values for pet, sun & dayl from temp, cloud & lat:
    ppeett_results = Ppeett.ppeett(lat, dtemp, dclou, radanom, temp)

    # Run snow model
    snow_results = Snow.snow(dtemp, dprecin)

    # Initialize the evergreen phenology
    dphen .= T(1.0)

    # Initialize pft specific parameters
    pftpar = PFTData.pftdata(T)

    # Rulebase of absolute constraints to select potentially present pfts:
    tmin, ts, clindex, pfts = Constraints.constraints(
        climate_results.cold,
        climate_results.warm,
        tminin,
        climate_results.gdd5,
        ppeett_results.rad0,
        climate_results.gdd0,
        snow_results.maxdepth
    )

    #If you want to bypass the environmental constraints for your model
    # set all pfts to present (1). You can turn them off by setting to 0
    # pfts[1] = 0
    # pfts[2] = 0
    # pfts[3] = 0
    # pfts[4] = 0
    # pfts[5] = 0
    # pfts[6] = 0
    # pfts[7] = 0 
    # pfts[8] = 0
    # pfts[9] = 0
    # pfts[10] = 0
    # pfts[11] = 0
    # pfts[12] = 0
    # pfts[13] = 0

    if diagmode
        diag_mode(lon, lat, climate_results.cold, tmin, climate_results.gdd5, tprec, snow_results.maxdepth, soil, k)
    end

    # Calculate optimal LAI and NPP for the selected PFTs
    for pft in 1:numofpfts
        if pfts[pft] != 0
            if pftpar[pft, 1] >= 2
                dphen = Phenology.phenology(dphen, dtemp, temp, climate_results.cold, tmin, pft, ppeett_results.ddayl, pftpar)
            end

            optdata[pft+1, :], optlai[pft+1], optnpp[pft+1], realout = FindNPP.findnpp(
                pfts,
                pft,
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
                optdata[pft+1, :],
                dphen,
                co2,
                p,
                tsoil,
                realout,
                numofpfts
            )
        end
    end

    competition_result = Competition.competition2(
        optnpp,
        optlai,
        tmin,
        tprec,
        pfts,
        optdata,
        realout,
        diagmode,
        numofpfts,
        climate_results.gdd0,
        climate_results.gdd5,
        climate_results.cold,
        pftpar,
        soil
    )
    biome = competition_result.biome
    output = competition_result.output

    # Final output biome is given by the integer biome:
    output[1] = biome
    output[48] = lon
    output[49] = lat

    for pft in 1:numofpfts
        output[300 + pft] = round(Int, optnpp[pft+1])
        output[300 + numofpfts + pft] = round(Int, optlai[pft+1] * 100.0)
        if pfts[pft] != 0 && diagmode
            formatted_output = @sprintf("%3d %5.2f %7.1f %6.1f", pft, optlai[pft+1], optnpp[pft+1], wetness[pft+1])
            formatted_output *= join(@sprintf(" %6.1f", optdata[pft+1, i] / 10.0) for i in 37:48)
            println(formatted_output)
        end
    end

    if diagmode
        diagnostic_output(biome, biomename, optdata)
    end

    return output
end

function diag_mode(lon, lat, tcm, tmin, gdd5, tprec, maxdepth, soil, k)
    println("Longitude: $(round(lon, digits=2)) Latitude: $(round(lat, digits=2))")
    println("Tcm and Tmin are: $(round(tcm, digits=1)) and $(round(tmin, digits=1)) degrees C respectively.")
    println("GDD5 is: $(round(gdd5, digits=1)) and total annual precip is: $(round(tprec, digits=1)) mm.")
    println("Maximum snowdepth is: $(round(maxdepth * 10, digits=1)) mm.")
    println("The current soil parameters are: $soil")
    print("Enter new soil parameters? (y/n): ")
    yorn = readline()

    if yorn == "y"
        print("Percolation index ~(0-7): ")
        soil[1] = parse(T, readline())
        soil[2] = soil[1]
        print("Top layer whc ~(0-999): ")
        soil[3] = parse(T, readline())
        print("Bottom layer whc ~(0-999): ")
        soil[4] = parse(T, readline())

        # Reinitialize soil texture specific parameters
        k[1] = soil[1]
        k[2] = soil[2]
        k[5] = soil[3]
        k[6] = soil[4]
    end

    println("The following PFTs will be computed:")
end

function diagnostic_output(biome, biomename, optdata)
    println("Biome $biome $(biomename[biome])")

    sumagnpp = T(0.0)
    delag = T(0.0)

    # First loop: Calculate sumagnpp
    for i in 2:7
        if optdata[9+1, 36 + i] > 0
            sumagnpp += optdata[9+1, 36 + i] / 10.0
        end
    end

    # Second loop: Calculate delag
    for i in 2:7
        if optdata[9+1, 36 + i] > 0
            wtagnpp = optdata[9+1, 36 + i] / (sumagnpp * 10.0)
            delag += (optdata[9+1, 79 + i] * wtagnpp) / 100.0
        end
    end

    println("The deltaA of C3 grass is $(round(delag, digits=2)) per mil.")
    print("Press return to continue")
    readline()
end

end # Module