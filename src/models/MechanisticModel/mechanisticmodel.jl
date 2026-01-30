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
    # Initialize environmental variables from the input
    env_variables = initialize_environmental_variables(vars_in)
    @unpack temp, clt, prec, mclou, mprec, mtemp, tprec, dtemp, 
             dprecin, dclou, tcm, gdd5, gdd0, twm, tminin, tmin, k, 
             tsoil, dphen, dpet, dayl, sun, rad0, ddayl, dprec, 
             dmelt, maxdepth, co2, lat, lon, p = env_variables

    # Unpack the PFT list and initialize PFT states
    pftstates, numofpfts = initialize_pftstates(pftlist, tcm, tmin, gdd5, gdd0, twm, maxdepth)

    # Apply environmental constraints to determine PFT presence
    pftstates = constraints(pftlist, pftstates, env_variables)

    # Calculate optimal LAI and NPP for each viable PFT
    for (iv, pft) in enumerate(pftlist.pft_list)
        pftstates[pft].fitness = dominance_environment_mv(pft; tcm = tcm, 
                                                          tmin = tmin, gdd5 = gdd5, gdd0 = gdd0,
                                                          twm = twm, maxdepth = maxdepth
                                                        )
        if pftstates[pft].present == true
            # Calculate phenology for deciduous PFTs
            if get_characteristic(pft, :phenological_type) >= 2
                dphen = phenology(dphen, dtemp, temp, tcm, tmin, pft, ddayl)
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
        m, tmin, tprec, numofpfts, gdd0, gdd5, tcm, pftlist, pftstates, biome_assignment, env_variables
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

"""
    unpack_namedtuple_with_defaults(nt::NamedTuple)

Clean and complete a NamedTuple of input variables, replacing missing or invalid values,
and filling in defaults for essential variables if they are missing.
"""
function unpack_namedtuple_with_defaults(nt::NamedTuple)
    # Determine numeric type based on temp if present
    if haskey(nt, :temp)
        T = nonmissingtype(eltype(nt.temp))
    else 
        T = Float64
    end

    missval = T(-9999.0)

    # Clean all existing entries from nt into `cleaned`
    cleaned = Dict{Symbol, Any}()
    sizehint!(cleaned, length(nt) + 4)

    for (k, v) in pairs(nt)
        if v isa AbstractArray
            # Clean array elementwise without using coalesce/broadcast (avoids extra temporaries)
            arr = v
            out = Vector{T}(undef, length(arr))
            @inbounds @simd for i in eachindex(arr)
                x = arr[i]
                if ismissing(x)
                    out[i] = missval
                else
                    out[i] = T(x)
                end
            end
            cleaned[k] = out
        elseif ismissing(v)
            cleaned[k] = missval
        else
            cleaned[k] = T(v)
        end
    end

    @inline _default_array(::Type{T}, len::Int, value::T) where {T} = fill(value, len)

    # Apply defaults for essential fields if missing or invalid
    # :whc  => length 6, default missval
    if !haskey(cleaned, :whc)
        @warn "Missing key 'whc'. Using default."
        cleaned[:whc] = _default_array(T, 6, missval)

    elseif cleaned[:whc] isa AbstractArray && any(ismissing, cleaned[:whc])
        @warn "Key 'whc' contains missing values. Using default."
        cleaned[:whc] = _default_array(T, 6, missval)

    elseif cleaned[:whc] === missval
        @warn "Key 'whc' has missing scalar. Using default."
        cleaned[:whc] = _default_array(T, 6, missval)

    end

    # :ksat => length 6, default missval
    if !haskey(cleaned, :ksat)
        @warn "Missing key 'ksat'. Using default."
        cleaned[:ksat] = _default_array(T, 6, missval)

    elseif cleaned[:ksat] isa AbstractArray && any(ismissing, cleaned[:ksat])
        @warn "Key 'ksat' contains missing values. Using default."
        cleaned[:ksat] = _default_array(T, 6, missval)

    elseif cleaned[:ksat] === missval
        @warn "Key 'ksat' has missing scalar. Using default."
        cleaned[:ksat] = _default_array(T, 6, missval)

    end

    # :temp => length 12, default missval
    if !haskey(cleaned, :temp)
        @warn "Missing key 'temp'. Using default."
        cleaned[:temp] = _default_array(T, 12, missval)
    elseif cleaned[:temp] isa AbstractArray && any(ismissing, cleaned[:temp])
        @warn "Key 'temp' contains missing values. Using default."
        cleaned[:temp] = _default_array(T, 12, missval)
    elseif cleaned[:temp] === missval
        @warn "Key 'temp' has missing scalar. Using default."
        cleaned[:temp] = _default_array(T, 12, missval)
    end

    # :prec => length 12, default missval
    if !haskey(cleaned, :prec)
        @warn "Missing key 'prec'. Using default."
        cleaned[:prec] = _default_array(T, 12, missval)
    elseif cleaned[:prec] isa AbstractArray && any(ismissing, cleaned[:prec])
        @warn "Key 'prec' contains missing values. Using default."
        cleaned[:prec] = _default_array(T, 12, missval)
    elseif cleaned[:prec] === missval
        @warn "Key 'prec' has missing scalar. Using default."
        cleaned[:prec] = _default_array(T, 12, missval)
    end

    # :clt => length 12, default missval
    if !haskey(cleaned, :clt)
        @warn "Missing key 'clt'. Using default."
        cleaned[:clt] = _default_array(T, 12, missval)
    elseif cleaned[:clt] isa AbstractArray && any(ismissing, cleaned[:clt])
        @warn "Key 'clt' contains missing values. Using default."
        cleaned[:clt] = _default_array(T, 12, missval)
    elseif cleaned[:clt] === missval
        @warn "Key 'clt' has missing scalar. Using default."
        cleaned[:clt] = _default_array(T, 12, missval)
    end

    # Scalar defaults: co2, lat, lon, p
    if !haskey(cleaned, :co2) || cleaned[:co2] === missval
        @warn "Missing or invalid key 'co2'. Using default 378.0."
        cleaned[:co2] = T(378.0)
    end

    if !haskey(cleaned, :lat) || cleaned[:lat] === missval
        @warn "Missing or invalid key 'lat'. Using default 0.0."
        cleaned[:lat] = T(0.0)
    end

    if !haskey(cleaned, :lon) || cleaned[:lon] === missval
        @warn "Missing or invalid key 'lon'. Using default 0.0."
        cleaned[:lon] = T(0.0)
    end

    if !haskey(cleaned, :p) || cleaned[:p] === missval
        @warn "Missing or invalid key 'p'. Using default 101.3."
        cleaned[:p] = T(101.3)
    end

    # :dz => length 6, default 0.0
    if !haskey(cleaned, :dz)
        @warn "Missing key 'dz'. Using default 0.0."
        cleaned[:dz] = _default_array(T, 6, T(0.0))
    elseif cleaned[:dz] isa AbstractArray && any(ismissing, cleaned[:dz])
        @warn "Key 'dz' contains missing values. Using default 0.0."
        cleaned[:dz] = _default_array(T, 6, T(0.0))
    elseif cleaned[:dz] === missval
        @warn "Key 'dz' has missing scalar. Using default 0.0."
        cleaned[:dz] = _default_array(T, 6, T(0.0))
    end

    # Return as NamedTuple with all keys from `cleaned`
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
    tsoil = soiltemp(temp)
    mprec   = mean(prec)
    tprec   = sum(prec)
    mclou = mean(clt)

    dtemp   = similar(temp, T, 365)
    dprecin = similar(temp, T, 365)
    dclou   = similar(temp, T, 365)

    daily_interp!(dtemp, temp)
    daily_interp!(dprecin, prec)
    daily_interp!(dclou, clt)


    missval = T(-9999.0)
    tcm = isempty(temp) ? missval : minimum(temp)

    # Frost delay adjustment
    tminin = tcm != missval ? T(0.006)*tcm^2 + T(1.316)*tcm - T(21.9) : missval
    if haskey(cleaned, :tmin) && !isempty(cleaned.tmin)
        tmin = cleaned.tmin[1]
    else
        tmin = tminin <= tcm ? tminin : (tcm - T(5.0))
    end

    # Soil calculations
    k = zeros(T, 12)
    @inbounds begin
        k[1] = sum(ksat[1:3] .* dz[1:3]) / sum(dz[1:3])
        k[2] = sum(ksat[4:6] .* dz[4:6]) / sum(dz[4:6])
        k[5] = sum(whc[1:3] .* dz[1:3])
        k[6] = sum(whc[4:6] .* dz[4:6])
    end

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
function initialize_pftstates(
    pftlist::AbstractPFTList, tcm::T, tmin::T, gdd5::T, gdd0::T, twm::T, maxdepth::T
)::Tuple{Dict{AbstractPFT, PFTState}, Int} where {T<:Real}

    numofpfts = length(pftlist.pft_list)

    # Create the Dict that holds the PFT dynamic states
    # Specify the abstract types so that we match the rest of the data
    PFTStateobj() = PFTState(PFTCharacteristics{T, Int}())
    pftstates = Dict{AbstractPFT,PFTState}()
    sizehint!(pftstates, numofpfts + 2)

    for pft in pftlist.pft_list
        pftstates[pft] = PFTState(pft)
    end

    # Add None and Default abstract PFT types
    # zero-arg constructor uses default characteristic types
    pftstates[NONE_INSTANCE] = PFTStateobj()
    pftstates[DEFAULT_INSTANCE] = PFTStateobj()
    pftstates[DEFAULT_INSTANCE].fitness = dominance_environment_mv(DEFAULT_INSTANCE,tcm = tcm, 
                                                          tmin = tmin, gdd5 = gdd5, gdd0 = gdd0,
                                                          twm = twm, maxdepth = maxdepth
                                                        )

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
    zeroT = zero(T)
    @inbounds for (i, pft) in enumerate(pftlist.pft_list)
        state = pftstates[pft]
        nppindex[i] = state.present ? state.npp : zeroT
    end
    nppindex[end] = zeroT  # Last one as zero if not used (padding)

    return (
        biome = biomeindex,
        optpft = optindex,
        npp = nppindex,
        lat = lat,
        lon = lon
    )
end
