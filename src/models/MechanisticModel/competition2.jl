
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
    PFTStates::Dict{AbstractPFT,PFTState{T,U}}
)::Tuple{AbstractBiome, AbstractPFT, T} where {T <: Real, U <: Int}

    # Initialize all variables using the singleton instances
    optpft   = NONE_INSTANCE
    subpft   = NONE_INSTANCE
    grasspft = NONE_INSTANCE
    pftmaxnpp = NONE_INSTANCE
    pftmaxlai = NONE_INSTANCE
    dom      = NONE_INSTANCE
    wdom     = NONE_INSTANCE
    
    maxnpp = T(0.0)
    maxlai = T(0.0)
    grassnpp = T(0.0)

    PFTStates = initialize_presence(numofpfts, BIOME4PFTS, PFTStates) # FIXME
    grass = [get_characteristic(BIOME4PFTS.pft_list[pft], :grass) for pft in 1:numofpfts]
    grass = vcat(grass, false)

    # Choose the dominant woody PFT on the basis of NPP - for all PFTs but LichenForbs
    for pft in BIOME4PFTS.pft_list 
        if get_characteristic(pft, :name)== "LichenForb"
            continue  # Skip iteration for LichenForbs
        end
        if get_characteristic(pft, :grass)
            if PFTStates[pft].npp > grassnpp
                grassnpp = PFTStates[pft].npp
                grasspft = pft
            end
        else
            if PFTStates[pft].npp > maxnpp
                maxnpp = PFTStates[pft].npp
                pftmaxnpp = pft
            end
            if PFTStates[pft].lai > maxlai
                maxlai = PFTStates[pft].lai
                pftmaxlai = pft
            elseif PFTStates[pft].lai == maxlai
                maxlai = PFTStates[pft].lai
                pftmaxlai = pftmaxnpp
            end
        end
    end

    # Find average annual soil moisture value for all PFTs
    wetness = calculate_soil_moisture(BIOME4PFTS, PFTStates)

    # Determine the subdominant woody PFT
    optpft, wdom, subpft, subnpp = determine_subdominant_pft(pftmaxnpp, BIOME4PFTS, PFTStates)

    # Determine the optimal PFT based on various conditions
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
        BIOME4PFTS,
        PFTStates
    )

    # Format values for output
    dom, npp, lai, grasslai, optpft = calculate_vegetation_dominance(
        optpft, wdom, grasspft, grassnpp, woodnpp, woodylai, grasslai, BIOME4PFTS, PFTStates
    )

    # Call the newassignbiome function
    biome = assign_biome(optpft; subpft=subpft, wdom=wdom, gdd0=gdd0,
     gdd5=gdd5, tcm=tcm, tmin=tmin, BIOME4PFTS=BIOME4PFTS, PFTStates=PFTStates)

    return biome, optpft, npp
end

function initialize_presence(numofpfts::U, BIOME4PFTS::AbstractPFTList, PFTStates::Dict{AbstractPFT,PFTState{T,U}})::Dict{AbstractPFT,PFTState{T,U}}where {T<: Real, U <: Int}
    # Initialize present dynamically based on optnpp
    for pft in BIOME4PFTS.pft_list
        if PFTStates[pft].npp > 0.0
            PFTStates[pft].present = true
        end
    end

    # Find ColdHerbaceous PFT by type checking
    cold_herb_index = findfirst(pft -> isa(pft, ColdHerbaceous), BIOME4PFTS.pft_list)
    if cold_herb_index !== nothing
        # set_characteristic(BIOME4PFTS.pft_list[cold_herb_index], :present, true) # Special case
        cold_herb = BIOME4PFTS.pft_list[cold_herb_index]
        PFTStates[cold_herb].present = true
    else
        @warn "ColdHerbaceous not found in pft_list"
    end

    return PFTStates
end


"""
Compute annual mean soil wetness for each PFT.
Returns a vector `wetness` of length `numofpfts+1` where
`wetness[i+1]` is the mean of the 12 monthly wetness values
for PFT `i`.
"""
function calculate_soil_moisture(
    BIOME4PFTS::AbstractPFTList,
    PFTStates::Dict{AbstractPFT,PFTState{T,U}}
) where {T<:Real, U<:Int}
    # pre‐allocate the output
    wetness = zeros(T, length(BIOME4PFTS.pft_list))

    # for each PFT, average its 12 monthly mwet values
    for (i, pft) in enumerate(BIOME4PFTS.pft_list)
        total = sum(PFTStates[pft].mwet)
        wetness[i] = total / 12.0
    end
    return wetness
end


function determine_subdominant_pft(pftmaxnpp::Union{AbstractPFT,Nothing}, BIOME4PFTS::AbstractPFTList, PFTStates::Dict{AbstractPFT,PFTState{T,U}}) where {T <: Real, U <: Int}
    optpft = pftmaxnpp
    wdom   = optpft
    subnpp = 0.0
    subpft = NONE_INSTANCE

    for pft in BIOME4PFTS.pft_list
        # skip the max‐NPP one by identity
        if pft !== pftmaxnpp && !get_characteristic(pft,:grass) && !get_characteristic(pft,:c4)
            let npp = PFTStates[pft].npp
                if npp > subnpp
                    subnpp = npp
                    subpft  = pft
                end
            end
         end
     end

     return optpft, wdom, subpft, subnpp
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
    BIOME4PFTS::AbstractPFTList,
    PFTStates::Dict{AbstractPFT,PFTState{T,U}}
) where {T <: Real, U<:Int} # ::Tuple{Union{AbstractPFT, Nothing}, T, T, U, T, T, Union{AbstractPFT, Nothing}, Union{AbstractPFT, Nothing}}
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
    woodylai = isa(wdom, None) ? T(0) : PFTStates[wdom].lai
    woodnpp  = isa(wdom, None) ? T(0) : PFTStates[wdom].npp
    grasslai = isa(grasspft, None) ? T(0) : PFTStates[grasspft].lai
    greendays = isa(wdom, None) ? 0 : PFTStates[wdom].greendays
    nppdif    = woodnpp - (isa(grasspft, None) ? T(0) : PFTStates[grasspft].npp)
    
    while true
        # Update variables dynamically if wdom changes
        if !isa(wdom, None)
            woodylai = PFTStates[wdom].lai
            woodnpp = PFTStates[wdom].npp
            firedays = PFTStates[wdom].firedays
            greendays = PFTStates[wdom].greendays
        else
            woodylai = T(0.0)
            woodnpp = T(0.0)
            firedays = 0
            greendays = 0
        end
        
        if !isa(grasspft, None)
            grasslai = PFTStates[grasspft].lai
            nppdif = woodnpp - PFTStates[grasspft].npp
        else
            grasslai = T(0.0)
            nppdif = woodnpp
        end

        if !isa(subpft, None)
            subfiredays = PFTStates[subpft].firedays
        else
            subfiredays = 0
        end

        nppdif = woodnpp - (isa(grasspft, None) ? T(0) : PFTStates[grasspft].npp)

        # Temperate broadleaved evergreen or cool conifer with warm conditions
        if (isa(wdom, TemperateBroadleavedEvergreen) || isa(wdom, CoolConifer)) && tmin > T(0.0)
            if gdd5 > T(5000.0)
                wdom = get_pft_by_type(TropicalDroughtDeciduous)
                continue
            end
        end

        # Tropical evergreen
        if isa(wdom, TropicalEvergreen)
            if  PFTStates[wdom].npp < T(2000.0)
                wdom = get_pft_by_type(TropicalDroughtDeciduous)
                subpft = get_pft_by_type(TropicalEvergreen)
                continue
            end
        end

        # Tropical drought deciduous
        if isa(wdom, TropicalDroughtDeciduous)
            if woodylai < T(2.0)
                optpft = grasspft
            elseif isa(grasspft, C4TropicalGrass) && woodylai < T(3.6)
                optpft = DEFAULT_INSTANCE # Mixed woody/grass (equivalent to index 14)
            elseif greendays < (270) && tcm > T(21.0) && tprec < T(1700.0)
                optpft = DEFAULT_INSTANCE # Mixed woody/grass
            else
                optpft = wdom
            end
        end

        # Temperate broadleaved evergreen
        if isa(wdom, TemperateBroadleavedEvergreen)
            if  PFTStates[wdom].npp < T(140.0)
                optpft = grasspft
            elseif woodylai < T(1.0)
                optpft = grasspft
            elseif woodylai < T(2.0)
                optpft = DEFAULT_INSTANCE # Mixed woody/grass
            else
                optpft = wdom
            end
        end

        # Temperate deciduous
        if isa(wdom, TemperateDeciduous)
            if woodylai < T(2.0)
                optpft = grasspft
            elseif firedays > 210 && nppdif < 0.0
                if !flop && subpft !== None
                    wdom = subpft
                    subpft = get_pft_by_type(TemperateDeciduous)
                    flop = true
                    continue
                else
                    optpft = grasspft
                end
            elseif woodylai < T(3.0) || firedays > 180
                if nppdif < 0.0
                    optpft = DEFAULT_INSTANCE # Mixed woody/grass - PFT 14
                elseif !flop && subpft !== None
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
        if isa(wdom, CoolConifer)
            temperate_evergreen = get_pft_by_type(TemperateBroadleavedEvergreen)
            if temperate_evergreen !== nothing && PFTStates[temperate_evergreen].present
                wdom = temperate_evergreen
                subpft = get_pft_by_type(CoolConifer)
                continue
            elseif  PFTStates[wdom].npp < T(140.0)
                optpft = grasspft
            elseif woodylai < T(1.2)
                optpft = DEFAULT_INSTANCE # Mixed woody/grass
            else
                optpft = wdom
            end
        end

        # Boreal evergreen
        if isa(wdom, BorealEvergreen)
            if PFTStates[wdom].npp < T(140.0)
                optpft = grasspft
            elseif firedays > 90
                if !flop && subpft !== None
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
        if isa(wdom, BorealDeciduous)
            if PFTStates[wdom].npp< T(120.0)
                optpft = grasspft
            elseif wetness[findfirst(pft -> pft === wdom, BIOME4PFTS.pft_list)] < T(30.0) && nppdif < T(0.0)
                optpft = grasspft
            else
                optpft = wdom
            end
        end

        # No woody PFT
        if isa(wdom, None)
            if !isa(grasspft, None)
                optpft = grasspft
            else
                lichen_forb = get_pft_by_type(LichenForb)
                if lichen_forb !== nothing &&  PFTStates[lichen_forb].npp != 0.0
                    optpft = lichen_forb
                else
                    optpft = NONE_INSTANCE
                end
            end
        end

        # Fallback to woody desert
        if isa(wdom, None)
            woody_desert = get_pft_by_type(WoodyDesert)
            if woody_desert !== nothing && PFTStates[woody_desert].present
                optpft = woody_desert
            end
        end

        # Woody desert specific conditions
        if isa(optpft, WoodyDesert)
            if !isa(grasspft, C4TropicalGrass) && PFTStates[grasspft].npp > PFTStates[optpft].npp
                optpft = grasspft
            else
                optpft = get_pft_by_type(WoodyDesert)
            end
        end

        # Grass conditions
        if optpft === grasspft
            woody_desert = get_pft_by_type(WoodyDesert)

            if PFTStates[grasspft].lai < 1.8 && woody_desert !== nothing && PFTStates[woody_desert].present
                optpft = woody_desert
            else
                optpft = grasspft
            end
        end

        # Tundra shrubs conditions
        if isa(optpft, TundraShrubs)
            cold_herb = get_pft_by_type(ColdHerbaceous)
            optpft_idx = findfirst(pft -> pft === optpft, BIOME4PFTS.pft_list)
            if optpft_idx !== nothing && wetness[optpft_idx] <= 25.0 && 
               cold_herb !== nothing && PFTStates[cold_herb].present
                optpft = cold_herb
            end
        end

        break
    end

    return optpft, woodnpp, woodylai, greendays, grasslai, nppdif, wdom, subpft
end

# FIXME what does this function do and can we detangle the output stuff from the calculations
function calculate_vegetation_dominance(
    optpft::AbstractPFT,
    wdom::AbstractPFT,
    grasspft::AbstractPFT,
    grassnpp::T,
    woodnpp::T,
    woodylai::T,
    grasslai::T,
    BIOME4PFTS::AbstractPFTList,
    PFTStates::Dict{AbstractPFT,PFTState{T,U}}
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
            npp = PFTStates[dom].npp
            lai = PFTStates[dom].npp
        else
            npp = T(0.0)
            lai = T(0.0)
        end
        
        if !isa(grasspft, Default)
            grasslai = PFTStates[grasspft].lai
        else
            grasslai = T(0.0)
        end
    end


    npp = PFTStates[optpft].npp
    lai = PFTStates[optpft].lai
    grasslai = PFTStates[grasspft].lai

    return dom, npp, lai, grasslai, optpft
end

