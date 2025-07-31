"""
    biome4

Main BIOME4 orchestrator module.

This module coordinates the execution of the BIOME4 vegetation model, 
integrating climate data processing, plant functional type evaluation,
and biome classification.
"""

# Third-party imports
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
    m::Union{BIOME4Model, BIOMEDominanceModel, BaseModel}, 
    vars_in::NamedTuple;
    pftlist::AbstractPFTList,
    biome_assignment::Function
)
    if haskey(vars_in, :temp)
        T = nonmissingtype(eltype(vars_in.temp))
    else 
        T = Float64
    end

    # Initialize environmental variables from the input
    temp, clt, prec,
        mclou, mprec, mtemp, tprec, dtemp, dprecin, dclou, 
        tcm, cold, gdd5, gdd0, warm, tminin, tmin, k, tsoil, dphen,
        dpet, dayl, sun, rad0, ddayl, dprec, dmelt, maxdepth = initialize_environmental_variables(vars_in)

    # Unpack the PFT list and initialize PFT states
    pftstates, numofpfts = initialize_pftstates(pftlist, mclou, mprec, mtemp)

    # Apply environmental constraints to determine PFT presence
    pftstates = constraints(
        cold, warm, tmin, gdd5, rad0, gdd0, maxdepth, pftlist, pftstates
    )

    # Calculate optimal LAI and NPP for each viable PFT
    for (iv, pft) in enumerate(pftlist.pft_list)
        pftstates[pft].fitness = dominance_environment_mv(pft, mclou, mprec, mtemp)
        if pftstates[pft].present == true
            # Calculate phenology for deciduous PFTs
            if get_characteristic(pft, :phenological_type) >= 2
                dphen = phenology(dphen, dtemp, temp, cold, tmin, pft, ddayl)
            end

            # Optimize NPP and LAI for this PFT
            pftlist.pft_list[iv], optlai, optnpp, pftstates[pft] = findnpp(
                pft, tprec, dtemp, sun, temp, dprec, dmelt, dpet, dayl,
                k, dphen, co2, p, tsoil, pftstates[pft]
            )

            # Store results in PFT characteristics
            pftstates[pft].npp = optnpp            # assign the optimized NPP
            pftstates[pft].lai = optlai            # assign the optimized LAI
        end
    end

    # Determine winning biome through PFT competition
    biome, optpft, npp = competition(
        m, tmin, tprec, numofpfts, gdd0, gdd5, cold, pftlist, pftstates, biome_assignment
    )

    # Prepare output vector
    output = create_output_vector(
        biome,
        optpft,
        pftstates,
        pftlist,
        numofpfts,
        lat,
        lon
    )

    return output
end


function _unpack_with_defaults(nt::NamedTuple)
    if haskey(nt, :temp)
        T = nonmissingtype(eltype(nt.temp))
    else 
        T = Float64
    end

    # Default values
    # FIXME provide some average values for these
    defaults = Dict(
        :whc  => fill(T(-9999.0), 6),
        :ksat => fill(T(-9999.0), 6),
        :temp => fill(T(-9999.0), 12),
        :prec => fill(T(-9999.0), 12),
        :clt  => fill(T(-9999.0), 12),
        :co2  => T(378.0),
        :lat  => T(0.0),
        :lon  => T(0.0),
        :p   => T(101.3),
        :dz  => fill(T(0.0), 6)
    )

    required_keys = [:whc, :ksat, :temp, :prec, :clt, :co2, 
                     :lat, :lon, :p, :dz]

    # Assign all keys directly from NamedTuple
    for (k, v) in pairs(nt)
        clean_value = (v isa AbstractArray && eltype(v) <: Union{Missing, Real}) ? coalesce.(v, -9999.0) : v
        @eval $(k) = $clean_value
    end

    missval = T(-9999.0)

    # Check required keys and assign defaults if needed
    for k in required_keys
        val_present = haskey(nt, k)
        val = val_present ? nt[k] : nothing

        use_default = false
        if !val_present
            use_default = true
            @warn "Missing key '$k' in NamedTuple. Using default: $(defaults[k])"
        elseif ismissing(val) || val == missval
            use_default = true
            @warn "Key '$k' is missing. Using default: $(defaults[k])"
        elseif val isa AbstractArray && any(ismissing, val)
            use_default = true
            @warn "Key '$k' contains missing values. Using default: $(defaults[k])"
        end

        if use_default
            @eval $(Symbol(k)) = defaults[$(QuoteNode(k))]
        end
    end
end

macro unpack_namedtuple(arg)
    quote
        _unpack_with_defaults($arg)
    end |> esc
end

function initialize_environmental_variables(input_variables::NamedTuple)

    if haskey(input_variables, :temp)
        T = nonmissingtype(eltype(input_variables.temp))
    else 
        T = Float64
    end

    # Unpack the input variables
    @unpack_namedtuple input_variables # would need to catch the variable names and return all of it

    mtemp = mean(temp)
    dtemp = daily_interp(temp)
    tsoil = soiltemp(temp)

    mprec = mean(prec)
    tprec = sum(prec)
    dprecin = daily_interp(prec)

    mclou = mean(clt)
    dclou = daily_interp(clt)

    missval = T(-9999.0)
    tcm = isempty(temp) ? missval : minimum(temp)

    # Adjust minimum temperature for frost delay
    tminin = tcm != missval ? T(0.006)*tcm^2 + T(1.316)*tcm - T(21.9) : missval
    tmin = tminin <= tcm ? tminin : tcm - T(5.0) # tmin will get passed on to constraints, not tminin

    # Soil data
    k = zeros(T, 12) # hydraulic conductivity
    k[1] = sum(ksat[1:3] .* dz[1:3]) / sum(dz[1:3])
    k[2] = sum(ksat[4:6] .* dz[4:6]) / sum(dz[4:6])
    k[5] = sum(whc[1:3] .* dz[1:3])
    k[6] = sum(whc[4:6] .* dz[4:6])

    # Initialize arrays for calculations
    # Initialize evergreen phenology (all days active)
    # By default, all days are favorable for growth - all activate growth days
    # This will be modified for other phenological types with the phenology function
    dphen = ones(T, 365, 2)
    dphen .= T(1.0)

    # Calculate climate indices
    cold, gdd5, gdd0, warm = climdata(temp, prec, dtemp, input_variables)

    # Calculate potential evapotranspiration and solar radiation
    dpet, dayl, sun, rad0, ddayl = ppeett(lat, dtemp, dclou, temp, input_variables)

    # Run snow accumulation and melting model
    dprec, dmelt, maxdepth = snow(dtemp, dprecin, input_variables)
    
    return (temp, clt, prec,
        mclou, mprec, mtemp, tprec, dtemp, dprecin, dclou, 
        tcm, cold, gdd5, gdd0, warm, tminin, tmin, k, tsoil, dphen,
        dpet, dayl, sun, rad0, ddayl, dprec, dmelt, maxdepth
    )
end


function initialize_pftstates(pftlist::AbstractPFTList, mclou::T, mprec::T, mtemp::T)::Tuple{ Dict{AbstractPFT, PFTState} , Int} where {T<:Real}
    numofpfts = length(pftlist.pft_list)

    # Create the Dict that holds the PFT dynamic states
    PFTStateobj() = PFTState(PFTCharacteristics())
    pftstates = Dict{AbstractPFT,PFTState}()

    for pft in pftlist.pft_list
        pftstates[pft] = PFTState(pft)
    end
    
    # Add None and Default abstract PFT types
    # zero-arg constructor uses default characteristic types
    pftstates[NONE_INSTANCE] = PFTStateobj()
    pftstates[DEFAULT_INSTANCE] = PFTStateobj()
    pftstates[DEFAULT_INSTANCE].fitness = dominance_environment_mv(DEFAULT_INSTANCE, mclou, mprec, mtemp)
    
    return pftstates, numofpfts
end

function create_output_vector(
    biome::AbstractBiome,
    optpft::AbstractPFT,
    pftstates::Dict{AbstractPFT,PFTState},
    pftlist::AbstractPFTList,
    numofpfts::U,
    lat::T,
    lon::T
) where {T<:Real, U<:Int}
    # Convert optimal PFT to index
    optindex = optpft === nothing ? 0 : something(findfirst(pft -> pft == optpft, pftlist.pft_list), 0)

    # Convert biome to integer index
    biomeindex = get_biome_characteristic(biome, :value)

    # Collect NPP values for all PFTs
    nppindex = Vector{T}(undef, numofpfts + 1)
    for (i, pft) in enumerate(pftlist.pft_list)
        nppindex[i] = pftstates[pft].present ? pftstates[pft].npp : T(0.0)
    end
    nppindex[end] = T(0.0)  # Last one as zero if not used (padding)

    return (
        biome = biomeindex,
        optpft = optindex,
        npp = nppindex,
        lat = lat,
        lon = lon
    )
end
