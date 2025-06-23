"""Biome4 orchestrator."""
# Third-party
using LinearAlgebra
using Printf
using ComponentArrays: ComponentArray
using DimensionalData

# First-party
include("./climdata.jl")
export climdata
include("./constraints.jl")
export constraints
include("./findnpp.jl")
export findnpp
include("./growth_subroutines/daily.jl")
export daily
include("./phenology.jl")
export phenology
include("./ppeett.jl")
export ppeett
include("./snow.jl")
export snow
include("./soiltemp.jl")
export soiltemp
include("./pfts.jl")
export BiomeClassification, get_name, get_phenological_type, 
        get_max_min_canopy_conductance, get_Emax, get_sw_drop, 
        get_sw_appear, get_root_fraction_top_soil, get_leaf_longevity,
        get_GDD5_full_leaf_out, get_GDD0_full_leaf_out, get_sapwood_respiration,
        get_optratioa, get_kk, get_c4, get_threshold, get_t0, get_tcurve,
        get_respfact, get_allocfact, get_grass, get_constraints,
        edit_presence, get_presence

"""
Put Doc

args in: 
- pfts: Vec{AbstractPFT{len}}- replaces pft_dict
- vars_in::DimensionalData (Vector)
- NO OUTPUTS

args out:
- dominance: vector of length pfts
- npp: vector of length pfts
"""
function run(m::BIOME4Model, vars_in::Vector{Union{T, U}}) where {T <: Real, U <: Int}
    # Whatever biomeclassification that will be called will depend on the model. Then we will jump into a folder
    BIOME4PFTS = BiomeClassification()
    numofpfts = length(BIOME4PFTS.pft_list)

    # Initialize variables
    optdata = zeros(T, numofpfts+1, 500) # FIXME: dimension should be decided upon the dim of the PFTTypes

    # FIXME this will change and will not be based on indices but names in the Raster object
    temp = @views vars_in[5:16] # 12 months of temperature
    prec = @views vars_in[17:28] # 12 months of precipitation
    clou = @views vars_in[29:40] # 12 months of cloud cover
    soil = @views vars_in[41:44] # soil parameters
    tminin = vars_in[45] # minimum temperature

    lon = vars_in[49]
    lat = vars_in[1]  # vars_in[49] - (vars_in[1] / vars_in[50])
    co2 = vars_in[2]
    p = vars_in[3]


    dphen = ones(T, 365, 2)
    realout = zeros(T, numofpfts+1, 500) # original fortran code uses 0-indexing for this one
    optnpp = zeros(T, numofpfts+1) # original fortran code uses 0-indexing for this one
    optlai = zeros(T, numofpfts+1) # original fortran code uses 0-indexing for this one
    pftpar = zeros(T, 25, 25)
    k = zeros(T, 12)
    tsoil = zeros(T, 12)
    radanom = zeros(T, 12)

    # Assign the variables that arrived in the array vars_in
    # FIXME: you need to use views, from DimensionalData

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
    # FIXME: dimensionaldata can interpolate for you
    dtemp = daily(temp)
    dclou = daily(clou)
    dprecin = daily(prec)

    # Initialize parameters derived from climate data:
    # FIXME: not needed
    cold, gdd5, gdd0, warm = climdata(temp, prec, dtemp)
    tprec = sum(prec)
    tsoil = soiltemp(temp)

    # Calculate mid-month values for pet, sun & dayl from temp, cloud & lat:
    dpet, dayl, sun, rad0, ddayl = ppeett(lat, dtemp, dclou, radanom, temp)

    # Run snow model
    dprec, dmelt, maxdepth = snow(dtemp, dprecin)

    # Initialize the evergreen phenology
    # FIXME To document
    dphen .= T(1.0)

    # Rulebase of absolute constraints to select potentially present pfts:
    tmin, BIOME4PFTS = constraints(
        cold,
        warm,
        tminin,
        gdd5,
        rad0,
        gdd0,
        maxdepth,
        BIOME4PFTS
    )

    #If you want to bypass the environmental constraints for your model
    # set all pfts to present(true). You can turn them off by setting to false
    # edit_presence(BIOME4PFTS.pft_list[1], true)

    if diagmode
        diag_mode(lon, lat, cold, tmin, gdd5, tprec, maxdepth, soil, k)
    end

    # Calculate optimal LAI and NPP for the selected PFTs
    for pft in 1:numofpfts
        if get_presence(BIOME4PFTS.pft_list[pft]) == true
            if get_phenological_type(BIOME4PFTS.pft_list[pft]) >= 2
                dphen = phenology(dphen, dtemp, temp, cold, tmin, pft, ddayl, pftpar)
            end

            optdata[pft+1, :], optlai[pft+1], optnpp[pft+1], realout = findnpp(
                pft,
                tprec,
                dtemp,
                sun,
                temp,
                dprec,
                dmelt,
                dpet,
                dayl,
                k,
                BIOME4PFTS,
                optdata[pft+1, :],
                dphen,
                co2,
                p,
                tsoil,
                realout,
            )
        end
    end

    biome, output = competition2(
        optnpp,
        optlai,
        tmin,
        tprec,
        pfts,
        optdata,
        realout,
        diagmode,
        numofpfts,
        gdd0,
        gdd5,
        cold,
        BIOME4PFTS
    )

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
