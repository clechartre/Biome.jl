"""
    biome4

Main BIOME4 orchestrator module.

This module coordinates the execution of the BIOME4 vegetation model, 
integrating climate data processing, plant functional type evaluation,
and biome classification.
"""

# Third-party imports
using ComponentArrays: ComponentArray
using DimensionalData
using LinearAlgebra
using Printf
using Statistics


# Create global singleton instances at module level
const NONE_INSTANCE = None()
const DEFAULT_INSTANCE = Default()
export NONE_INSTANCE, DEFAULT_INSTANCE

"""
    run(m::BIOME4Model, vars_in::Vector{Union{T,U}}) where {T<:Real,U<:Int}

Execute the complete BIOME4 model simulation for a single grid cell.

This function orchestrates the entire BIOME4 modeling workflow including:
climate data processing, snow dynamics, soil temperature calculation,
potential evapotranspiration, phenology, plant functional type constraints,
NPP optimization, and biome classification.

# Arguments
- `m::BIOME4Model`: Model configuration object
- `vars_in::Vector{Union{T,U}}`: Input vector containing climate and site data
  - Elements 1: latitude (degrees)
  - Elements 2: CO2 concentration (ppm)
  - Elements 3: atmospheric pressure (kPa)
  - Elements 4: minimum temperature (°C)
  - Elements 5-16: monthly temperature (°C, 12 months)
  - Elements 17-28: monthly precipitation (mm, 12 months)
  - Elements 29-40: monthly cloud cover (%, 12 months)
  - Elements 41-44: soil parameters (4 values)
  - Elements 49: longitude (degrees)

# Returns
- `Vector{Any}`: Output vector containing:
  - Element 1: biome classification index
  - Element 2: optimal PFT index
  - Elements 3-16: NPP values for each PFT (gC/m²/year)
  - Element 48: longitude
  - Element 49: latitude

# Notes
- Uses 365-day year assumption
- Handles both C3 and C4 photosynthesis pathways
- Includes iterative optimization for LAI and NPP
- Accounts for environmental constraints on PFT presence
"""
function run(
    m::Union{BIOME4Model, BIOMEDominanceModel}, 
    vars_in::Vector{Union{T,U}},
    BIOME4PFTS::AbstractPFTList
) where {T<:Real,U<:Int}
    # Extract input variables from the input vector
    lat = vars_in[1]
    co2 = vars_in[2]
    p = vars_in[3]
    tminin = vars_in[4]
    temp = @views vars_in[5:16]    # 12 months of temperature
    mtemp = mean(temp)  # mean temperature for the year
    prec = @views vars_in[17:28]   # 12 months of precipitation
    mprec = mean(prec)  # mean precipitation for the year
    clou = @views vars_in[29:40]   # 12 months of cloud cover
    mclou = mean(clou)  # mean cloud cover for the year
    soil = @views vars_in[41:44]   # soil parameters
    lon = vars_in[49]

    numofpfts = length(BIOME4PFTS.pft_list)

    # Create the Dict that holds the PFT dynamic states
    PFTStates = Dict{AbstractPFT,PFTState{Float64,Int}}()
    for pft in BIOME4PFTS.pft_list
        PFTStates[pft] = PFTState{Float64,Int}()
    end
    
    # Add None and Default abstract PFT types
    PFTStates[NONE_INSTANCE] = PFTState{Float64,Int}()
    PFTStates[DEFAULT_INSTANCE] = PFTState{Float64,Int}()
    PFTStates[DEFAULT_INSTANCE].dominance = dominance_environment(DEFAULT_INSTANCE, :clt, mclou) + dominance_environment(DEFAULT_INSTANCE, :temp, mtemp) + dominance_environment(DEFAULT_INSTANCE, :prec, mprec)
    
    # Initialize arrays for calculations
    dphen = ones(T, 365, 2)
    optnpp = zeros(T, numofpfts + 1)  # +1 for 0-indexing compatibility
    optlai = zeros(T, numofpfts + 1)  # +1 for 0-indexing compatibility
    k = zeros(T, 12)
    tsoil = zeros(T, 12)

    # Initialize soil texture specific parameters
    k[1] = soil[1]
    k[2] = soil[2]
    k[5] = soil[3]
    k[6] = soil[4]

    # Interpolate monthly values to daily values
    dtemp = daily_interp(temp)
    dclou = daily_interp(clou)
    dprecin = daily_interp(prec)

    # Calculate climate indices
    cold, gdd5, gdd0, warm = climdata(temp, prec, dtemp)
    tprec = sum(prec)
    tsoil = soiltemp(temp)

    # Calculate potential evapotranspiration and solar radiation
    dpet, dayl, sun, rad0, ddayl = ppeett(lat, dtemp, dclou, temp)

    # Run snow accumulation and melting model
    dprec, dmelt, maxdepth = snow(dtemp, dprecin)

    # Initialize evergreen phenology (all days active)
    # By default, all days are favorable for growth - all activate growth days
    # This will be modified for other phenological types with the phenology function
    dphen .= T(1.0)

    # Apply environmental constraints to determine PFT presence
    tmin, PFTStates = constraints(
        cold, warm, tminin, gdd5, rad0, gdd0, maxdepth, BIOME4PFTS, PFTStates
    )

    # Calculate optimal LAI and NPP for each viable PFT
    for (iv, pft) in enumerate(BIOME4PFTS.pft_list)
        PFTStates[pft].dominance = dominance_environment(pft, :clt, mclou) + dominance_environment(pft, :temp, mtemp) + dominance_environment(pft, :prec, mprec)
        if PFTStates[pft].present == true
            # Calculate phenology for deciduous PFTs
            if get_characteristic(pft, :phenological_type) >= 2
                dphen = phenology(dphen, dtemp, temp, cold, tmin, pft, ddayl)
            end

            # Optimize NPP and LAI for this PFT
            BIOME4PFTS.pft_list[iv], optlai, optnpp, PFTStates[pft] = findnpp(
                pft, tprec, dtemp, sun, temp, dprec, dmelt, dpet, dayl,
                k, dphen, co2, p, tsoil, PFTStates[pft]
            )

            # Store results in PFT characteristics
            st = PFTStates[pft]           # look up this PFT’s state
            st.npp = optnpp            # assign the optimized NPP
            st.lai = optlai            # assign the optimized LAI
        end
    end

# Determine winning biome through PFT competition
    biome, optpft, npp = competition2(
        m, tmin, tprec, numofpfts, gdd0, gdd5, cold, BIOME4PFTS, PFTStates
    )

    # Convert optimal PFT to index
    optindex = if optpft === nothing
        0
    else
        idx = findfirst(pft -> pft == optpft, BIOME4PFTS.pft_list)
        idx === nothing ? 0 : idx
    end

    # Convert biome to integer index
    biomeindex = get_biome_characteristic(biome, :value)

    # Collect NPP values for all PFTs
    nppindex = zeros(T, numofpfts + 1)
    for (i, pft) in enumerate(BIOME4PFTS.pft_list)
        if PFTStates[pft].present == true
            nppindex[i] = PFTStates[pft].npp
        else
            nppindex[i] = T(0.0)
        end
    end

    # Prepare output vector
    output = Vector{Any}(undef, 50)
    fill!(output, T(0.0))
    output[1] = biomeindex
    output[2] = optindex
    output[3:16] = nppindex[1:14]  # Ensure we don't exceed bounds
    output[48] = lon
    output[49] = lat

    return output
end