"""
    newassignbiome

Assign biomes as in BIOME3.5 according to a new scheme of biomes.

As per the logic of Jed Kaplan 3/1998
"""

"""
    assign_biome(optpft::LichenForb, subpft, wdom, gdd0, gdd5, tcm, tmin, BIOME4PFTS)

Assign biome for LichenForb plant functional type.

Returns Barren biome as LichenForb typically occurs in harsh environments.
"""
function assign_biome(
    optpft::LichenForb;
    kwargs...
)::AbstractBiome
    return Barren()
end

"""
    assign_biome(optpft::TundraShrubs, subpft, wdom, gdd0, gdd5, tcm, tmin, BIOME4PFTS)

Assign biome for TundraShrubs plant functional type.

Uses growing degree days above 0°C to determine tundra biome type.
"""
function assign_biome(
    optpft::TundraShrubs;
    gdd0::T,
    kwargs... 
)::AbstractBiome where {T<:Real}
    if gdd0 < T(200.0)
        return CushionForbsLichenMoss()
    elseif gdd0 < T(500.0)
        return ProstateShrubTundra()
    else
        return DwarfShrubTundra()
    end
end

"""
    assign_biome(optpft::ColdHerbaceous, subpft, wdom, gdd0, gdd5, tcm, tmin, BIOME4PFTS)

Assign biome for ColdHerbaceous plant functional type.

Returns SteppeTundra biome for cold herbaceous vegetation.
"""
function assign_biome(
    optpft::ColdHerbaceous;
    kwargs...
)::AbstractBiome
    return SteppeTundra()
end

"""
    assign_biome(optpft::BorealEvergreen, subpft, wdom, gdd0, gdd5, tcm, tmin, BIOME4PFTS)

Assign biome for BorealEvergreen plant functional type.

Uses GDD5 and coldest month temperature to determine forest type.
"""
function assign_biome(
    optpft::BorealEvergreen;
    gdd5::T, 
    tcm::T,  
    BIOME4PFTS::AbstractPFTList,
    PFTStates::Dict{AbstractPFT,PFTState{T,U}},
    kwargs... 
)::AbstractBiome where {T<:Real, U<:Int}
    if gdd5 > T(900.0) && tcm > T(-19.0)
        temperate_deciduous_idx = findfirst(
            pft -> get_characteristic(pft, :name) == "TemperateDeciduous", 
            BIOME4PFTS.pft_list
        )
        temp_dec_pft = BIOME4PFTS.pft_list[temperate_deciduous_idx]
        if temperate_deciduous_idx !== nothing && 
           PFTStates[temp_dec_pft].present
            return CoolMixedForest()
        else
            return CoolConiferForest()
        end
    else
        temperate_deciduous_idx = findfirst(
            pft -> get_characteristic(pft, :name) == "TemperateDeciduous", 
            BIOME4PFTS.pft_list
        )
        temp_dec_pft = BIOME4PFTS.pft_list[temperate_deciduous_idx]
        if temperate_deciduous_idx !== nothing && 
            PFTStates[temp_dec_pft].present
            return ColdMixedForest()
        else
            return EvergreenTaigaMontaneForest()
        end
    end
end

"""
    assign_biome(optpft::BorealDeciduous, subpft, wdom, gdd0, gdd5, tcm, tmin, BIOME4PFTS)

Assign biome for BorealDeciduous plant functional type.

Determines forest type based on subordinate PFT and climate conditions.
"""
function assign_biome(
    optpft::BorealDeciduous;
    subpft::AbstractPFT, 
    gdd5::T, 
    tcm::T,
    kwargs... 
)::AbstractBiome where {T<:Real}
    if subpft !== nothing && isa(subpft, TemperateDeciduous)
        return TemperateDeciduousForest()
    elseif subpft !== nothing && isa(subpft, CoolConifer)
        return CoolConiferForest()
    elseif gdd5 > T(900.0) && tcm > T(-19.0)
        return CoolConiferForest()
    else
        return DeciduousTaigaMontaneForest()
    end
end

"""
    assign_biome(optpft::WoodyDesert, subpft, wdom, gdd0, gdd5, tcm, tmin, BIOME4PFTS)

Assign biome for WoodyDesert plant functional type.

Uses NPP and LAI to determine desert or shrubland biome type.
"""
function assign_biome(
    optpft::WoodyDesert;
    subpft::AbstractPFT,
    tmin::T,
    PFTStates::Dict{AbstractPFT,PFTState{T,U}},
    kwargs... 
)::AbstractBiome where {T<:Real, U<:Int}
    if PFTStates[optpft].npp > T(100.0) 
        if PFTStates[subpft].lai > T(1.0) 
            return tmin >= T(0.0) ? TropicalXerophyticShrubland() : 
                   TemperateXerophyticShrubland()
        else
            return Desert()
        end
    else
        return Desert()
    end
end

"""
    assign_biome(optpft::C3C4TemperateGrass, subpft, wdom, gdd0, gdd5, tcm, tmin, BIOME4PFTS)

Assign biome for C3C4TemperateGrass plant functional type.

Uses NPP and GDD0 to determine grassland or tundra biome type.
"""
function assign_biome(
    optpft::C3C4TemperateGrass;
    subpft::AbstractPFT, 
    gdd0::T,
    PFTStates::Dict{AbstractPFT,PFTState{T,U}},
    kwargs... 
)::AbstractBiome where {T<:Real, U<:Int}
    if PFTStates[optpft].npp <= T(100.0)
        if subpft !== Default && 
           !(isa(subpft, BorealEvergreen) || isa(subpft, BorealDeciduous))
            return Desert()
        else
            return SteppeTundra()
        end
    elseif gdd0 >= T(800.0)
        return TemperateGrassland()
    else
        return SteppeTundra()
    end
end

"""
    assign_biome(optpft::TemperateBroadleavedEvergreen, subpft, wdom, gdd0, gdd5, tcm, tmin, BIOME4PFTS)

Assign biome for TemperateBroadleavedEvergreen plant functional type.

Uses NPP to determine if mixed forest or desert biome is appropriate.
"""
function assign_biome(
    optpft::TemperateBroadleavedEvergreen;
    PFTStates::Dict{AbstractPFT,PFTState{T,U}},
    kwargs... 
)::AbstractBiome where {T<:Real, U<:Int}
    if PFTStates[optpft].npp > T(100.0)
        return WarmMixedForest()
    else
        return Desert()
    end
end

"""
    assign_biome(optpft::TemperateDeciduous, subpft, wdom, gdd0, gdd5, tcm, tmin, BIOME4PFTS)

Assign biome for TemperateDeciduous plant functional type.

Complex logic considering co-occurring PFTs and climate conditions.
"""
function assign_biome(
    optpft::TemperateDeciduous;
    gdd5::T, 
    tcm::T, 
    BIOME4PFTS::AbstractPFTList,
    PFTStates::Dict{AbstractPFT,PFTState{T,U}},
    kwargs... 
)::AbstractBiome where {T<:Real, U<:Int}
    if PFTStates[optpft].npp > T(100.0)
        boreal_evergreen_idx = findfirst(
            pft -> get_characteristic(pft, :name) == "BorealEvergreen", 
            BIOME4PFTS.pft_list
        )
        if boreal_evergreen_idx !== nothing
            boreal_evergreen_pft = BIOME4PFTS.pft_list[boreal_evergreen_idx]
            if PFTStates[boreal_evergreen_pft].present
                if tcm < T(-15.0)
                    return ColdMixedForest()
                else
                    return CoolMixedForest()
                end
            end
        end
        
        temperate_broadleaved_evergreen_idx = findfirst(
            pft -> get_characteristic(pft, :name) == "TemperateBroadleavedEvergreen", 
            BIOME4PFTS.pft_list
        )
        cool_conifer_idx = findfirst(
            pft -> get_characteristic(pft, :name) == "CoolConifer", 
            BIOME4PFTS.pft_list
        )
        
        temperate_broadleaved_present = false
        if temperate_broadleaved_evergreen_idx !== nothing
            temperate_broadleaved_evergreen_pft = BIOME4PFTS.pft_list[temperate_broadleaved_evergreen_idx]
            temperate_broadleaved_present = PFTStates[temperate_broadleaved_evergreen_pft].present
        end
        
        cool_conifer_conditions = false
        if cool_conifer_idx !== nothing
            cool_conifer_pft = BIOME4PFTS.pft_list[cool_conifer_idx]
            cool_conifer_conditions = PFTStates[cool_conifer_pft].present && 
                                     gdd5 > T(3000.0) && tcm > T(3.0)
        end
        
        if temperate_broadleaved_present || cool_conifer_conditions
            return WarmMixedForest()
        else
            return TemperateDeciduousForest()
        end
    else
        return Desert()
    end
end

"""
    assign_biome(optpft::CoolConifer, subpft, wdom, gdd0, gdd5, tcm, tmin, BIOME4PFTS)

Assign biome for CoolConifer plant functional type.

Determines conifer forest type based on co-occurring PFTs.
"""
function assign_biome(
    optpft::CoolConifer; 
    subpft::AbstractPFT,
    BIOME4PFTS::AbstractPFTList,
    PFTStates::Dict{AbstractPFT,PFTState{T,U}},
    kwargs... 
)::AbstractBiome where {T<:Real, U<:Int}
    if PFTStates[optpft].npp > T(100.0)
        temperate_broadleaved_evergreen_idx = findfirst(
            pft -> get_characteristic(pft, :name) == "TemperateBroadleavedEvergreen", 
            BIOME4PFTS.pft_list
        )
        if temperate_broadleaved_evergreen_idx !== nothing
            temperate_broadleaved_evergreen_pft = BIOME4PFTS.pft_list[temperate_broadleaved_evergreen_idx]
            if PFTStates[temperate_broadleaved_evergreen_pft].present
                return WarmMixedForest()
            end
        end
        
        if subpft !== nothing && isa(subpft, TemperateDeciduous)
            return TemperateConiferForest()
        elseif subpft !== nothing && isa(subpft, BorealDeciduous)
            return ColdMixedForest()
        else
            return TemperateConiferForest()
        end
    else
        return Desert()
    end
end

"""
    assign_biome(optpft::TropicalEvergreen, subpft, wdom, gdd0, gdd5, tcm, tmin, BIOME4PFTS)

Assign biome for TropicalEvergreen plant functional type.

Returns tropical evergreen forest if NPP is sufficient, otherwise desert.
"""
function assign_biome(
    optpft::TropicalEvergreen;
    PFTStates::Dict{AbstractPFT,PFTState{T,U}},
    kwargs... 
)::AbstractBiome where {T<:Real, U<:Int}
    if PFTStates[optpft].npp > T(100.0)
        return TropicalEvergreenForest()
    else
        return Desert()
    end
end

"""
    assign_biome(optpft::TropicalDroughtDeciduous, subpft, wdom, gdd0, gdd5, tcm, tmin, BIOME4PFTS)

Assign biome for TropicalDroughtDeciduous plant functional type.

Uses NPP and green days to determine tropical forest type.
"""
function assign_biome(
    optpft::TropicalDroughtDeciduous;
    PFTStates::Dict{AbstractPFT,PFTState{T,U}},
    kwargs... 
)::AbstractBiome where {T<:Real, U<:Int}
    if PFTStates[optpft].npp > T(100.0)
        if PFTStates[optpft].greendays > 300
            return TropicalEvergreenForest()
        elseif PFTStates[optpft].greendays > 250
            return TropicalSemiDeciduousForest()
        else
            return TropicalDeciduousForestWoodland()
        end
    else 
        return Desert()
    end
end

"""
    assign_biome(optpft::C4TropicalGrass, subpft, wdom, gdd0, gdd5, tcm, tmin, BIOME4PFTS)

Assign biome for C4TropicalGrass plant functional type.

Returns tropical grassland if NPP is sufficient, otherwise desert.
"""
function assign_biome(
    optpft::C4TropicalGrass;
    PFTStates::Dict{AbstractPFT,PFTState{T,U}},
    kwargs... 
)::AbstractBiome where {T<:Real, U<:Int}
    if PFTStates[optpft].npp > T(100.0)
        return TropicalGrassland()
    else
        return Desert()
    end
end

"""
    assign_biome(optpft::Default, subpft, wdom, gdd0, gdd5, tcm, tmin, BIOME4PFTS)

Assign biome for Default plant functional type.

Uses woody dominant PFT to determine appropriate biome type.
"""
function assign_biome(
    optpft::Default;
    wdom::AbstractPFT, 
    PFTStates::Dict{AbstractPFT,PFTState{T,U}},
    kwargs... 
)::AbstractBiome where {T<:Real, U<:Int}
    if wdom === nothing || isa(wdom, TropicalEvergreen) || 
       isa(wdom, TropicalDroughtDeciduous)
        if wdom !== nothing && PFTStates[wdom].lai > T(4.0)
            return TropicalSavanna()
        else
            return TropicalXerophyticShrubland()
        end
    elseif isa(wdom, TemperateBroadleavedEvergreen)
        return TemperateSclerophyllWoodland()
    elseif isa(wdom, TemperateDeciduous)
        return TemperateBroadleavedSavanna()
    elseif isa(wdom, CoolConifer)
        return OpenConiferWoodland()
    elseif isa(wdom, BorealEvergreen) || isa(wdom, BorealDeciduous)
        return BorealParkland()
    else
        return Barren()
    end
end

"""
    assign_biome(optpft::None, subpft, wdom, gdd0, gdd5, tcm, tmin, BIOME4PFTS)

Assign biome for None plant functional type.

Returns Barren biome when no vegetation is present.
"""
function assign_biome(
    optpft::None;
    kwargs...
)::AbstractBiome
    return Barren()
end