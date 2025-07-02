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
include("./competition2.jl")
export competition2
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
export BiomeClassification, get_characteristic, set_characteristic

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

    BIOME4PFTS = BiomeClassification(mean(clou), mean(temp), mean(prec))
    numofpfts = length(BIOME4PFTS.pft_list)

    # FIXME it's those that don't need to be instantiated
    dphen = ones(T, 365, 2)
    optnpp = zeros(T, numofpfts+1) # original fortran code uses 0-indexing for this one
    optlai = zeros(T, numofpfts+1) # original fortran code uses 0-indexing for this one
    k = zeros(T, 12)
    tsoil = zeros(T, 12)

    # Assign the variables that arrived in the array vars_in
    # FIXME: you need to use views, from DimensionalData

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
    dpet, dayl, sun, rad0, ddayl = ppeett(lat, dtemp, dclou, temp)

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
    # set_characteristic(BIOME4PFTS.pft_list[1], :presence, true)

    # Calculate optimal LAI and NPP for the selected PFTs
    for (iv, pft) in enumerate(BIOME4PFTS.pft_list)
        if get_characteristic(pft, :present) == true
            if get_characteristic(pft, :phenological_type) >= 2
                dphen = phenology(dphen, dtemp, temp, cold, tmin, pft, ddayl)
            end

            # FIXME instead return BIOME4PFTs with firedays, greendays, mwet, wetlayer in it
            # Find the index 
            BIOME4PFTS.pft_list[iv] = findnpp(
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
                dphen,
                co2,
                p,
                tsoil,
            )
        end
    end

    biome, optpft, npp = competition2(
        tmin,
        tprec,
        numofpfts,
        gdd0,
        gdd5,
        cold,
        BIOME4PFTS
    )

    # Transform optpft into a number that corresponds to its index in the PFT list
    optindex = optpft === nothing ? 0 : (findfirst(pft -> pft == optpft, BIOME4PFTS.pft_list) === nothing ? 0 : findfirst(pft -> pft == optpft, BIOME4PFTS.pft_list))

    # Save all NPP for each AbstractPFT in order into a vector 
    nppindex = zeros(T, numofpfts + 1)  # +1 for the case of no PFTs present
    for pft in 1:numofpfts
        if get_characteristic(BIOME4PFTS.pft_list[pft], :present) == true
            nppindex[pft] = get_characteristic(BIOME4PFTS.pft_list[pft], :npp)
        else
            nppindex[pft] = 0.0
        end
    end

    # Final output biome is given by the integer biome:
    output = Vector{Any}(undef, 50)
    fill!(output, 0.0)
    output[1] = biome
    output[2] = optindex  # Now can store AbstractPFT
    output[3:17] = nppindex
    output[48] = lon
    output[49] = lat


    return output
end
