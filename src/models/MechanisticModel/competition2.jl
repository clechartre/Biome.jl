
include("./newassignbiome.jl")
export mock_assign_biome, newassignbiome

using LinearAlgebra: norm
using Statistics: mean
using Printf: @sprintf

"""
Classic BIOME4 Competition function.
"""

function competition2(
    tmin::T,
    tprec::T,
    numofpfts::U,
    gdd0::T,
    gdd5::T,
    tcm::T,
    BIOME4PFTS::AbstractPFTList,  
)::Tuple{T, AbstractPFT, T} where {T <: Real, U <: Int}

    # Initialize all of the variables that index an array
    optpft   = Default()
    subpft   = Default()
    grasspft = Default()
    pftmaxnpp = Default()
    pftmaxlai = Default()
    dom      = Default()
    wdom     = Default()
    
    maxnpp = T(0.0)
    maxlai = T(0.0)
    grassnpp = T(0.0)

    BIOME4PFTS = initialize_presence(numofpfts, BIOME4PFTS)
    grass = [get_characteristic(BIOME4PFTS.pft_list[pft], :grass) for pft in 1:numofpfts]
    grass = vcat(grass, false)

    # Choose the dominant woody PFT on the basis of NPP - for all PFTs but LichenForbs
    for pft in BIOME4PFTS.pft_list 
        if get_characteristic(pft, :name)== "LichenForb"
            continue  # Skip iteration for LichenForbs
        end
        if get_characteristic(pft, :grass)
            if get_characteristic(pft, :npp) > grassnpp
                grassnpp = get_characteristic(pft, :npp)
                grasspft = pft
            end
        else
            if get_characteristic(pft, :npp) > maxnpp
                maxnpp = get_characteristic(pft, :npp)
                pftmaxnpp = pft
            end
            if get_characteristic(pft, :lai) > maxlai
                maxlai = get_characteristic(pft, :lai)
                pftmaxlai = pft
            elseif get_characteristic(pft, :lai) == maxlai
                maxlai = pftmaxnpp !== Default ? get_characteristic(pftmaxnpp, :lai) : T(0)
                pftmaxlai = pftmaxnpp
            end
        end
    end

    # Find average annual soil moisture value for all PFTs
    # FIXME we need to get an Indexed DimensionalData structure for optdata
    wetness = calculate_soil_moisture(numofpfts, BIOME4PFTS)

    # Determine the subdominant woody PFT
    optpft, wdom, subpft, subnpp = determine_subdominant_pft(pftmaxnpp, BIOME4PFTS)


    # Determine the optimal PFT based on various conditions
    # FIXME, make sure that optpft is of type AbstractPFT - also base this on the BIOME4PFTS.pft_list[pft].dominance
    optpft, woodnpp, woodylai, greendays, grasslai, nppdif, wdom, subpft = determine_optimal_pft_Kaplan(
        optpft,
        wdom,
        subpft,
        grasspft,
        tmin,
        gdd5,
        tcm,
        tprec,
        wetness,
        BIOME4PFTS
    )

    # Format values for output
    dom, npp, lai, grasslai, optpft = calculate_vegetation_dominance(
        optpft, wdom, grasspft, grassnpp, woodnpp, woodylai, grasslai, BIOME4PFTS
    )

    # Call the newassignbiome function
    biome = mock_assign_biome(
        optpft,
        wdom,
        subpft,
        npp,
        subnpp,
        greendays,
        gdd0,
        gdd5,
        tcm,
        woodylai,
        grasslai,
        tmin,
        BIOME4PFTS
    )

    return biome, optpft, npp
end

function initialize_presence(numofpfts::U, BIOME4PFTS::AbstractPFTList)::AbstractPFTList where {T <: Real, U <: Int}
    # Initialize present dynamically based on optnpp
    for pft in 1:numofpfts
        if get_characteristic(BIOME4PFTS.pft_list[pft], :npp) > 0.0
            set_characteristic(BIOME4PFTS.pft_list[pft], :present, true)
        end
    end

    # Find ColdHerbaceous PFT by type checking
    cold_herb_index = findfirst(pft -> isa(pft, ColdHerbaceous), BIOME4PFTS.pft_list)
    if cold_herb_index !== nothing
        set_characteristic(BIOME4PFTS.pft_list[cold_herb_index], :present, true) # Special case
    else
        @warn "ColdHerbaceous not found in pft_list"
    end

    return BIOME4PFTS
end


"""
Compute annual mean soil wetness for each PFT.
Returns a vector `wetness` of length `numofpfts+1` where
`wetness[i+1]` is the mean of the 12 monthly wetness values
for PFT `i`.
"""
function calculate_soil_moisture(
    numofpfts::U,
    BIOME4PFTS::AbstractPFTList
) where {T<:Real, U<:Int}
    # pre‐allocate the output
    wetness = zeros(Float64, numofpfts+1)

    # for each PFT, average its 12 monthly mwet values
    for i in 1:numofpfts
        total = sum(get_characteristic(BIOME4PFTS.pft_list[i], :mwet))
        wetness[i+1] = total / 12.0
    end
    return wetness
end


function determine_subdominant_pft(pftmaxnpp::Union{AbstractPFT,Nothing}, BIOME4PFTS::AbstractPFTList)
    optpft = pftmaxnpp === nothing ? Default() : pftmaxnpp
    wdom   = optpft
    subnpp = 0.0
    subpft = Default()

    for pft in BIOME4PFTS.pft_list
        # skip the max‐NPP one by identity
        if pft !== pftmaxnpp && !get_characteristic(pft,:grass) && !get_characteristic(pft,:c4)
            let npp = get_characteristic(pft,:npp)
                if npp > subnpp
                    subnpp = npp
                    subpft  = pft
                end
            end
         end
     end

     return optpft, wdom, subpft, subnpp
 end

# function determine_optimal_pft(BIOME4PFTS::AbstractPFTList)
#     # Take all that are present 

#     # Multiply the NPP by the dominance factor 

#     # Whichever PFT has the most winds up being the optimal PFT optpft, second highest is subpft

#     # Wdom is the non-grass the has the highest value 

#     # gdom is the grass that has the highest value

#     # Woodnpp is the NPP of the woody PFT and woodlai is the LAI of the woody PFT

#     # Nppdif is the difference between woodnpp and grassnpp


#     return optpft, woodnpp, woodylai, greendays, grasslai, nppdif, wdom, subpft

# end

function determine_optimal_pft(optpft::AbstractPFT, subpft::AbstractPFT, BIOME4PFTS::AbstractPFTList)
    # Initialize variables
    wdom = Default()
    gdom = Default()
    woodnpp = 0.0
    woodylai = 0.0
    grasslai = 0.0
    greendays = 0
    nppdif = 0.0
    
    # Calculate weighted NPP (NPP * dominance) for all present PFTs
    weighted_npps = Float64[]
    pfts = AbstractPFT[]
    
    for pft in BIOME4PFTS.pft_list
        if get_characteristic(pft, :present)
            weighted_npp = get_characteristic(pft, :npp) * get_characteristic(pft, :dominance)
            push!(weighted_npps, weighted_npp)
            push!(pfts, pft)
        end
    end
    
    # Find PFT with highest weighted NPP (optpft)
    if !isempty(weighted_npps)
        max_idx = argmax(weighted_npps)
        optpft = pfts[max_idx]
        
        # Find second highest (subpft)
        if length(weighted_npps) > 1
            # Remove the max value and find second max
            remaining_npps = copy(weighted_npps)
            remaining_pfts = copy(pfts)
            deleteat!(remaining_npps, max_idx)
            deleteat!(remaining_pfts, max_idx)
            
            if !isempty(remaining_npps)
                second_max_idx = argmax(remaining_npps)
                subpft = remaining_pfts[second_max_idx]
            end
        end
    end
    
    # Find dominant woody PFT (wdom) - highest weighted NPP among non-grass PFTs
    max_woody_weighted_npp = 0.0
    for pft in BIOME4PFTS.pft_list
        if get_characteristic(pft, :present) && !get_characteristic(pft, :grass)
            weighted_npp = get_characteristic(pft, :npp) * get_characteristic(pft, :dominance)
            if weighted_npp > max_woody_weighted_npp
                max_woody_weighted_npp = weighted_npp
                wdom = pft
            end
        end
    end
    
    # Find dominant grass PFT (gdom) - highest weighted NPP among grass PFTs
    max_grass_weighted_npp = 0.0
    for pft in BIOME4PFTS.pft_list
        if get_characteristic(pft, :present) && get_characteristic(pft, :grass)
            weighted_npp = get_characteristic(pft, :npp) * get_characteristic(pft, :dominance)
            if weighted_npp > max_grass_weighted_npp
                max_grass_weighted_npp = weighted_npp
                gdom = pft
            end
        end
    end
    
    # Get woody PFT values
    if wdom !== Default
        woodnpp = get_characteristic(wdom, :npp)
        woodylai = get_characteristic(wdom, :lai)
        greendays = get_characteristic(wdom, :greendays)
    end
    
    # Get grass LAI
    if gdom !== Default
        grasslai = get_characteristic(gdom, :lai)
        grassnpp = get_characteristic(gdom, :npp)
        nppdif = woodnpp - grassnpp
    end
    
    return optpft, woodnpp, woodylai, greendays, grasslai, nppdif, wdom, subpft
end


function determine_optimal_pft_Kaplan(
    optpft::Union{AbstractPFT},
    wdom::Union{AbstractPFT},
    subpft::Union{AbstractPFT},
    grasspft::Union{AbstractPFT},
    tmin::T,
    gdd5::T,
    tcm::T,
    tprec::T,
    wetness::AbstractArray{T},
    BIOME4PFTS::AbstractPFTList
) where {T <: Real, U <: Int} # ::Tuple{Union{AbstractPFT, Nothing}, T, T, U, T, T, Union{AbstractPFT, Nothing}, Union{AbstractPFT, Nothing}}
    
    flop = false

    # Helper function to find PFT by type
    function find_pft_by_type(pft_type::Type{<:AbstractPFT})
        return findfirst(pft -> isa(pft, pft_type), BIOME4PFTS.pft_list)
    end

    # Helper function to get PFT by type
    function get_pft_by_type(pft_type::Type{<:AbstractPFT})
        idx = find_pft_by_type(pft_type)
        return idx !== nothing ? BIOME4PFTS.pft_list[idx] : nothing
    end

    # Initialize variables
    woodylai = isa(wdom, Default) ? T(0) : get_characteristic(wdom, :lai)
    woodnpp  = isa(wdom, Default) ? T(0) : get_characteristic(wdom, :npp)
    grasslai = isa(grasspft, Default) ? T(0) : get_characteristic(grasspft, :lai)
    greendays = isa(wdom, Default) ? 0 : get_characteristic(wdom, :greendays)
    nppdif    = woodnpp - (isa(grasspft, Default) ? T(0) : get_characteristic(grasspft, :npp))
    
    while true
        # Update variables dynamically if wdom changes
        woodylai = wdom !== Default ? get_characteristic(wdom, :lai) : T(0.0)
        woodnpp = wdom !== Default ? get_characteristic(wdom, :npp) : T(0.0)
        grasslai = grasspft !== Default ? get_characteristic(grasspft, :lai) : T(0.0)

        if wdom !== Default
            firedays = get_characteristic(wdom, :firedays)
            subfiredays = subpft !== Default ? get_characteristic(subpft, :firedays) : 0
            greendays = get_characteristic(wdom, :greendays)
        else
            firedays = 0
            subfiredays = 0
            greendays = 0
        end

        nppdif = woodnpp - (grasspft !== Default ? get_characteristic(grasspft, :npp) : T(0.0))

        # Temperate broadleaved evergreen or cool conifer with warm conditions
        if wdom !== Default && (isa(wdom, TemperateBroadleavedEvergreen) || isa(wdom, CoolConifer)) && tmin > T(0.0)
            if gdd5 > T(5000.0)
                wdom = get_pft_by_type(TropicalDroughtDeciduous)
                continue
            end
        end

        # Tropical evergreen
        if wdom !== Default && isa(wdom, TropicalEvergreen)
            if get_characteristic(wdom, :npp) < T(2000.0)
                wdom = get_pft_by_type(TropicalDroughtDeciduous)
                subpft = get_pft_by_type(TropicalEvergreen)
                continue
            end
        end

        # Tropical drought deciduous
        if wdom !== Default && isa(wdom, TropicalDroughtDeciduous)
            if woodylai < T(2.0)
                optpft = grasspft
            elseif grasspft !== Default && isa(grasspft, C4TropicalGrass) && woodylai < T(3.6)
                optpft = Default # Mixed woody/grass (equivalent to index 14)
            elseif greendays < (270) && tcm > T(21.0) && tprec < T(1700.0)
                optpft = Default # Mixed woody/grass
            else
                optpft = wdom
            end
        end

        # Temperate broadleaved evergreen
        if wdom !== Default && isa(wdom, TemperateBroadleavedEvergreen)
            if get_characteristic(wdom, :npp) < T(140.0)
                optpft = grasspft
            elseif woodylai < T(1.0)
                optpft = grasspft
            elseif woodylai < T(2.0)
                optpft = Default # Mixed woody/grass
            else
                optpft = wdom
            end
        end

        # Temperate deciduous
        if wdom !== Default && isa(wdom, TemperateDeciduous)
            if woodylai < T(2.0)
                optpft = grasspft
            elseif firedays > 210 && nppdif < 0.0
                if !flop && subpft !== Default
                    wdom = subpft
                    subpft = get_pft_by_type(TemperateDeciduous)
                    flop = true
                    continue
                else
                    optpft = grasspft
                end
            elseif woodylai < T(3.0) || firedays > 180
                if nppdif < 0.0
                    optpft = Default # Mixed woody/grass
                elseif !flop && subpft !== Default
                    wdom = subpft
                    subpft = get_pft_by_type(TemperateDeciduous)
                    flop = true
                    continue
                end
            else
                optpft = wdom
            end
        end

        # Cool conifer
        if wdom !== Default && isa(wdom, CoolConifer)
            temperate_broadleaved = get_pft_by_type(TemperateBroadleavedEvergreen)
            if temperate_broadleaved !== Default && get_characteristic(temperate_broadleaved, :present)
                wdom = temperate_broadleaved
                subpft = get_pft_by_type(CoolConifer)
                continue
            elseif get_characteristic(wdom, :npp) < T(140.0)
                optpft = grasspft
            elseif woodylai < T(1.2)
                optpft = Default # Mixed woody/grass
            else
                optpft = wdom
            end
        end

        # Boreal evergreen
        if wdom !== Default && isa(wdom, BorealEvergreen)
            if get_characteristic(wdom, :npp) < T(140.0)
                optpft = grasspft
            elseif firedays > 90
                if !flop && subpft !== Default
                    wdom = subpft
                    subpft = get_pft_by_type(BorealEvergreen)
                    flop = true
                    continue
                else
                    optpft = wdom
                end
            end
        end

        # Boreal deciduous
        if wdom !== Default && isa(wdom, BorealDeciduous)
            if get_characteristic(wdom, :npp) < T(120.0)
                optpft = grasspft
            elseif wetness[findfirst(pft -> pft === wdom, BIOME4PFTS.pft_list)] < T(30.0) && nppdif < T(0.0)
                optpft = grasspft
            else
                optpft = wdom
            end
        end

        # No woody PFT
        if wdom === Default
            lichen_forb = get_pft_by_type(LichenForb)
            if grasspft !== Default
                optpft = grasspft
            elseif lichen_forb !== Default && get_characteristic(lichen_forb, :npp) != 0.0
                optpft = lichen_forb
            else
                optpft = Default
            end
        end

        # Fallback to woody desert
        if optpft === Default
            woody_desert = get_pft_by_type(WoodyDesert)
            if woody_desert !== Default && get_characteristic(woody_desert, :present)
                optpft = woody_desert
            end
        end

        # Woody desert specific conditions
        if optpft !== Default && isa(optpft, WoodyDesert)
            woody_desert = get_pft_by_type(WoodyDesert)
            if (grasspft === Default || !isa(grasspft, C4TropicalGrass)) && 
               grasspft !== Default && woody_desert !== Default &&
               get_characteristic(grasspft, :npp) > get_characteristic(woody_desert, :npp)
                optpft = grasspft
            else
                optpft = woody_desert
            end
        end

        # Grass conditions
        if optpft === grasspft && grasspft !== Default
            woody_desert = get_pft_by_type(WoodyDesert)
            if get_characteristic(grasspft, :lai) < 1.8 && 
               woody_desert !== Default && get_characteristic(woody_desert, :present)
                optpft = woody_desert
            else
                optpft = grasspft
            end
        end

        # Tundra shrubs conditions
        if optpft !== Default && isa(optpft, TundraShrubs)
            cold_herb = get_pft_by_type(ColdHerbaceous)
            optpft_idx = findfirst(pft -> pft === optpft, BIOME4PFTS.pft_list)
            if optpft_idx !== Default && wetness[optpft_idx] <= 25.0 && 
               cold_herb !== Default && get_characteristic(cold_herb, :present)
                optpft = cold_herb
            end
        end

        break
    end

    return optpft, woodnpp, woodylai, greendays, grasslai, nppdif, wdom, subpft
end

# FIXME what does this function do and can we detangle the output stuff from the calculations
function calculate_vegetation_dominance(
    optpft::Union{AbstractPFT},
    wdom::Union{AbstractPFT},
    grasspft::Union{AbstractPFT},
    grassnpp::T,
    woodnpp::T,
    woodylai::T,
    grasslai::T,
    BIOME4PFTS::AbstractPFTList
) where {T <: Real, U <: Int} # ::Tuple{AbstractPFT, T, T, T, U} 

    dom = optpft

    if isa(optpft, Default)

        npprat = woodnpp / grassnpp
        treepct = ((8.0 / 5.0) * npprat) - 0.54

        if treepct < 0.0
            treepct = 0.0
        end
        if treepct >= 1.0
            treepct = 1.0
        end

        grasspct = 1.0 - treepct
        dom = wdom

        lai = (woodylai + (2.0 * grasslai)) / 3.0
        npp = (woodnpp + (2.0 * grassnpp)) / 3.0

        if !isa(dom, Default)
            npp = get_characteristic(dom, :npp)
            lai = get_characteristic(dom, :lai)
        else
            npp = T(0.0)
            lai = T(0.0)
        end
        
        if !isa(grasspft, Default)
            grasslai = get_characteristic(grasspft, :lai)
        else
            grasslai = T(0.0)
        end
    end


    npp = get_characteristic(optpft, :npp)
    lai = get_characteristic(optpft, :lai)
    grasslai = get_characteristic(grasspft, :lai)

    return dom, npp, lai, grasslai, optpft
end

