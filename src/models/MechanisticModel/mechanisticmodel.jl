"""
    mechanisticmodel

Main Mechanistic model orchestrator module.

This module coordinates the execution of the BIOME4 vegetation model, 
integrating climate data processing, plant functional type evaluation,
and biome classification.
"""

# Third-party imports
using DimensionalData
using LinearAlgebra
using Printf
using Statistics
using Parameters


# Create global singleton instances at module level
const NONE_INSTANCE = None()
const DEFAULT_INSTANCE = Default()
export NONE_INSTANCE, DEFAULT_INSTANCE

"""
    run(m::Union{BIOME4Model, BIOMEDominanceModel, BaseModel}, vars_in::NamedTuple; 
    pftlist, biome_assignment) where {T<:Real,U<:Int}

Execute the complete mechanistic model simulation for a single grid cell.

This function orchestrates the entire modeling workflow including:
climate data processing, snow dynamics, soil temperature calculation,
potential evapotranspiration, phenology, plant functional type constraints,
NPP optimization, and biome classification.
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
    env_variables = initialize_environmental_variables(vars_in)
    @unpack temp, clt, prec, mclou, mprec, mtemp, tprec, dtemp, 
             dprecin, dclou, tcm, gdd5, gdd0, twm, tminin, tmin, k, 
             tsoil, dphen, dpet, dayl, sun, rad0, ddayl, dprec, 
             dmelt, maxdepth, co2, lat, lon, p = env_variables

    # Unpack the PFT list and initialize PFT states
    pftstates, numofpfts = initialize_pftstates(pftlist, mclou, mprec, mtemp)

    # Apply environmental constraints to determine PFT presence
    pftstates = constraints(pftlist, pftstates, env_variables)

    # # Calculate optimal LAI and NPP for each viable PFT
    # for (iv, pft) in enumerate(pftlist.pft_list)
    #     pftstates[pft].fitness = dominance_environment_mv(pft, mclou, mprec, mtemp)
    #     if pftstates[pft].present == true
    #         # Calculate phenology for deciduous PFTs
    #         if get_characteristic(pft, :phenological_type) >= 2
    #             dphen = phenology(dphen, dtemp, temp, tcm, tmin, pft, ddayl)
    #         end

    #         # Optimize NPP and LAI for this PFT
    #         pftlist.pft_list[iv], optlai, optnpp, pftstates[pft] = findnpp(
    #             pft, tprec, dtemp, sun, temp, dprec, dmelt, dpet, dayl,
    #             k, dphen, co2, p, tsoil, pftstates[pft]
    #         )

    #         # Store results in PFT characteristics
    #         pftstates[pft].npp = optnpp            # assign the optimized NPP
    #         pftstates[pft].lai = optlai            # assign the optimized LAI
    #     end
    # end

    # # Determine winning biome through PFT competition
    # biome, optpft, npp = competition(
    #     m, tmin, tprec, numofpfts, gdd0, gdd5, tcm, pftlist, pftstates, biome_assignment
    # )

    pft_key = first(p for p in keys(pftstates) if get_characteristic(p, :name) == "BorealEvergreen")
    output = (biome = pftstates[pft_key].present,)


    # # Prepare output vector
    # output = create_output_vector(
    #     biome,
    #     optpft,
    #     pftstates,
    #     pftlist,
    #     numofpfts,
    #     lat,
    #     lon
    # )

    return output
end

"""
    unpack_namedtuple_with_defaults(nt::NamedTuple)

Clean and complete a NamedTuple of input variables, replacing missing or invalid values,
and filling in defaults for essential variables if they are missing.
"""
function unpack_namedtuple_with_defaults(nt::NamedTuple)
    if haskey(nt, :temp)
        T = nonmissingtype(eltype(nt.temp))
    else 
        T = Float64
    end

    missval = T(-9999.0)

    defaults = Dict(
        :whc  => fill(T(-9999.0), 6),
        :ksat => fill(T(-9999.0), 6),
        :temp => fill(T(-9999.0), 12),
        :prec => fill(T(-9999.0), 12),
        :clt  => fill(T(-9999.0), 12),
        :co2  => T(378.0),
        :lat  => T(0.0),
        :lon  => T(0.0),
        :p    => T(101.3),
        :dz   => fill(T(0.0), 6)
    )

    cleaned = Dict{Symbol, Any}()

    for (k, v) in pairs(nt)
        cleaned[k] = if v isa AbstractArray
            Array{T}(coalesce.(v, missval))
        elseif ismissing(v)
            missval
        else
            T(v)
        end
    end

    for (k, default) in defaults
        if !haskey(cleaned, k)
            @warn "Missing key '$k'. Using default: $default"
            cleaned[k] = default
        elseif cleaned[k] isa AbstractArray && any(ismissing, cleaned[k])
            @warn "Key '$k' contains missing values. Using default: $default"
            cleaned[k] = default
        elseif cleaned[k] === missval
            @warn "Key '$k' has missing scalar. Using default: $default"
            cleaned[k] = default
        end
    end

    return (; cleaned...)
end

"""
    initialize_environmental_variables(input_variables::NamedTuple)

Prepare all environmental variables (monthly, derived, soil, radiation, snow, etc.)
from the input NamedTuple, cleaning missing values and adding climate indices.
"""
function initialize_environmental_variables(input_variables::NamedTuple)
    cleaned = unpack_namedtuple_with_defaults(input_variables)

    temp = cleaned.temp
    prec = cleaned.prec
    clt  = cleaned.clt
    co2  = cleaned.co2
    lat  = cleaned.lat
    lon  = cleaned.lon
    p    = cleaned.p
    dz   = cleaned.dz
    whc  = cleaned.whc
    ksat = cleaned.ksat

    if haskey(input_variables, :temp)
        T = nonmissingtype(eltype(input_variables.temp))
    else
        T = Float64
    end

    # Derived climate means and interpolations
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

    # Frost delay adjustment
    tminin = tcm != missval ? T(0.006)*tcm^2 + T(1.316)*tcm - T(21.9) : missval
    tmin = tminin <= tcm ? tminin : tcm - T(5.0)

    # Soil calculations
    k = zeros(T, 12)
    k[1] = sum(ksat[1:3] .* dz[1:3]) / sum(dz[1:3])
    k[2] = sum(ksat[4:6] .* dz[4:6]) / sum(dz[4:6])
    k[5] = sum(whc[1:3] .* dz[1:3])
    k[6] = sum(whc[4:6] .* dz[4:6])

    # Evergreen phenology by default
    dphen = ones(T, 365, 2)
    dphen .= T(1.0)

    # Derived indices
    tcm, gdd5, gdd0, twm = climdata(temp, prec, dtemp, cleaned)
    dpet, dayl, sun, rad0, ddayl = ppeett(lat, dtemp, dclou, temp, cleaned)
    dprec, dmelt, maxdepth = snow(dtemp, dprecin, cleaned)

    # Return merged NamedTuple: all cleaned input + derived fields
    return merge(cleaned, (; mclou, mprec, mtemp, tprec, dtemp, 
                            dprecin, dclou, tcm, gdd5, gdd0, twm, tminin, tmin, k, 
                            tsoil, dphen, dpet, dayl, sun, rad0, ddayl, dprec, 
                            dmelt, maxdepth))
end


"""
    initialize_pftstates(pftlist::AbstractPFTList, mclou::Real, mprec::Real, mtemp::Real)

Create and initialize the state for each Plant Functional Type (PFT), 
including default and placeholder types.

Returns a dictionary of PFT states and the number of PFTs.
"""
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

"""
    create_output_vector(biome, optpft, pftstates, pftlist, numofpfts, lat, lon)

Construct the model output as a `NamedTuple` for a single grid cell.

Includes biome index, optimal PFT index, per-PFT NPP values, 
and geographic coordinates.
"""
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
