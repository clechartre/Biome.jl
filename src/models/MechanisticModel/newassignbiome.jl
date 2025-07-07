"""
    newassignbiome

Assign biomes as in BIOME3.5 according to a new scheme of biomes.

As per the logic of Jed Kaplan 3/1998
"""

include("./pfts.jl")
include("./biomes.jl")
export TropicalEvergreen, TropicalDroughtDeciduous, 
       TemperateBroadleavedEvergreen, TemperateDeciduous, 
       CoolConifer, BorealEvergreen, BorealDeciduous, C4TropicalGrass,
       LichenForb, TundraShrubs, ColdHerbaceous,
       WoodyDesert, C3C4TemperateGrass

"""
    mock_assign_biome(optpft, woodpft, subpft, optnpp, subnpp, greendays, gdd0, gdd5, tcm, woodylai, grasslai, tmin, BIOME4PFTS)

Mock function for biome assignment. Returns a placeholder value.

# Arguments
- `optpft`: Optimal plant functional type
- `woodpft`: Woody plant functional type  
- `subpft`: Subordinate plant functional type
- `optnpp`: Optimal net primary productivity
- `subnpp`: Subordinate net primary productivity
- `greendays`: Number of green days
- `gdd0`: Growing degree days above 0°C
- `gdd5`: Growing degree days above 5°C
- `tcm`: Temperature of coldest month
- `woodylai`: Woody leaf area index
- `grasslai`: Grass leaf area index
- `tmin`: Minimum temperature
- `BIOME4PFTS`: List of plant functional types

# Returns
- `U`: Integer representing biome type (placeholder value 1)
"""
function mock_assign_biome(
    optpft::Union{AbstractPFT,Nothing},
    woodpft::Union{AbstractPFT,Nothing},
    subpft::Union{AbstractPFT,Nothing},
    optnpp::Union{U,T},
    subnpp::Union{U,T},
    greendays::U,
    gdd0::T,
    gdd5::T,
    tcm::T,
    woodylai::T,
    grasslai::T,
    tmin::T,
    BIOME4PFTS::AbstractPFTList
)::U where {T<:Real,U<:Int}
    return U(1)
end

"""
    assign_biome(optpft::LichenForb, subpft, wdom, gdd0, gdd5, tcm, tmin, BIOME4PFTS)

Assign biome for LichenForb plant functional type.

Returns Barren biome as LichenForb typically occurs in harsh environments.
"""
function assign_biome(
    optpft::LichenForb, 
    subpft::AbstractPFT, 
    wdom::AbstractPFT, 
    gdd0::T, 
    gdd5::T, 
    tcm::T, 
    tmin::T, 
    BIOME4PFTS::AbstractPFTList
)::AbstractBiome where {T<:Real}
    return Barren()
end

"""
    assign_biome(optpft::TundraShrubs, subpft, wdom, gdd0, gdd5, tcm, tmin, BIOME4PFTS)

Assign biome for TundraShrubs plant functional type.

Uses growing degree days above 0°C to determine tundra biome type.
"""
function assign_biome(
    optpft::TundraShrubs, 
    subpft::AbstractPFT, 
    wdom::AbstractPFT, 
    gdd0::T, 
    gdd5::T, 
    tcm::T, 
    tmin::T, 
    BIOME4PFTS::AbstractPFTList
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
    optpft::ColdHerbaceous, 
    subpft::AbstractPFT, 
    wdom::AbstractPFT, 
    gdd0::T, 
    gdd5::T, 
    tcm::T, 
    tmin::T, 
    BIOME4PFTS::AbstractPFTList
)::AbstractBiome where {T<:Real}
    return SteppeTundra()
end

"""
    assign_biome(optpft::BorealEvergreen, subpft, wdom, gdd0, gdd5, tcm, tmin, BIOME4PFTS)

Assign biome for BorealEvergreen plant functional type.

Uses GDD5 and coldest month temperature to determine forest type.
"""
function assign_biome(
    optpft::BorealEvergreen, 
    subpft::AbstractPFT, 
    wdom::AbstractPFT, 
    gdd0::T, 
    gdd5::T, 
    tcm::T, 
    tmin::T, 
    BIOME4PFTS::AbstractPFTList
)::AbstractBiome where {T<:Real}
    if gdd5 > T(900.0) && tcm > T(-19.0)
        temperate_deciduous_idx = findfirst(
            pft -> get_characteristic(pft, :name) == "TemperateDeciduous", 
            BIOME4PFTS.pft_list
        )
        if temperate_deciduous_idx !== nothing && 
           get_characteristic(BIOME4PFTS.pft_list[temperate_deciduous_idx], :present)
            return CoolMixedForest()
        else
            return CoolConiferForest()
        end
    else
        temperate_deciduous_idx = findfirst(
            pft -> get_characteristic(pft, :name) == "TemperateDeciduous", 
            BIOME4PFTS.pft_list
        )
        if temperate_deciduous_idx !== nothing && 
           get_characteristic(BIOME4PFTS.pft_list[temperate_deciduous_idx], :present)
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
    optpft::BorealDeciduous, 
    subpft::AbstractPFT, 
    wdom::AbstractPFT, 
    gdd0::T, 
    gdd5::T, 
    tcm::T, 
    tmin::T, 
    BIOME4PFTS::AbstractPFTList
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
    optpft::WoodyDesert, 
    subpft::AbstractPFT, 
    wdom::AbstractPFT, 
    gdd0::T, 
    gdd5::T, 
    tcm::T, 
    tmin::T, 
    BIOME4PFTS::AbstractPFTList
)::AbstractBiome where {T<:Real}
    if get_characteristic(optpft, :npp) > T(100.0)
        if get_characteristic(subpft, :lai) > T(1.0)
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
    optpft::C3C4TemperateGrass, 
    subpft::AbstractPFT, 
    wdom::AbstractPFT, 
    gdd0::T, 
    gdd5::T, 
    tcm::T, 
    tmin::T, 
    BIOME4PFTS::AbstractPFTList
)::AbstractBiome where {T<:Real}
    if get_characteristic(optpft, :npp) <= T(100.0)
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
    optpft::TemperateBroadleavedEvergreen, 
    subpft::AbstractPFT, 
    wdom::AbstractPFT, 
    gdd0::T, 
    gdd5::T, 
    tcm::T, 
    tmin::T, 
    BIOME4PFTS::AbstractPFTList
)::AbstractBiome where {T<:Real}
    if get_characteristic(optpft, :npp) > T(100.0)
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
    optpft::TemperateDeciduous, 
    subpft::AbstractPFT, 
    wdom::AbstractPFT, 
    gdd0::T, 
    gdd5::T, 
    tcm::T, 
    tmin::T, 
    BIOME4PFTS::AbstractPFTList
)::AbstractBiome where {T<:Real}
    if get_characteristic(optpft, :npp) > T(100.0)
        boreal_evergreen_idx = findfirst(
            pft -> get_characteristic(pft, :name) == "BorealEvergreen", 
            BIOME4PFTS.pft_list
        )
        if boreal_evergreen_idx !== nothing && 
           get_characteristic(BIOME4PFTS.pft_list[boreal_evergreen_idx], :present)
            if tcm < T(-15.0)
                return ColdMixedForest()
            else
                return CoolMixedForest()
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
        
        if (temperate_broadleaved_evergreen_idx !== nothing && 
            get_characteristic(BIOME4PFTS.pft_list[temperate_broadleaved_evergreen_idx], :present)) || 
           (cool_conifer_idx !== nothing && 
            get_characteristic(BIOME4PFTS.pft_list[cool_conifer_idx], :present) && 
            gdd5 > T(3000.0) && tcm > T(3.0))
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
    optpft::CoolConifer, 
    subpft::AbstractPFT, 
    wdom::AbstractPFT, 
    gdd0::T, 
    gdd5::T, 
    tcm::T, 
    tmin::T, 
    BIOME4PFTS::AbstractPFTList
)::AbstractBiome where {T<:Real}
    if get_characteristic(optpft, :npp) > T(100.0)
        temperate_broadleaved_evergreen_idx = findfirst(
            pft -> get_characteristic(pft, :name) == "TemperateBroadleavedEvergreen", 
            BIOME4PFTS.pft_list
        )
        if temperate_broadleaved_evergreen_idx !== nothing && 
           get_characteristic(BIOME4PFTS.pft_list[temperate_broadleaved_evergreen_idx], :present)
            return WarmMixedForest()
        elseif subpft !== nothing && isa(subpft, TemperateDeciduous)
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
    optpft::TropicalEvergreen, 
    subpft::AbstractPFT, 
    wdom::AbstractPFT, 
    gdd0::T, 
    gdd5::T, 
    tcm::T, 
    tmin::T, 
    BIOME4PFTS::AbstractPFTList
)::AbstractBiome where {T<:Real}
    if get_characteristic(optpft, :npp) > T(100.0)
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
    optpft::TropicalDroughtDeciduous, 
    subpft::AbstractPFT, 
    wdom::AbstractPFT, 
    gdd0::T, 
    gdd5::T, 
    tcm::T, 
    tmin::T, 
    BIOME4PFTS::AbstractPFTList
)::AbstractBiome where {T<:Real}
    if get_characteristic(optpft, :npp) > T(100.0)
        if get_characteristic(optpft, :greendays) > 300
            return TropicalEvergreenForest()
        elseif get_characteristic(optpft, :greendays) > 250
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
    optpft::C4TropicalGrass, 
    subpft::AbstractPFT, 
    wdom::AbstractPFT, 
    gdd0::T, 
    gdd5::T, 
    tcm::T, 
    tmin::T, 
    BIOME4PFTS::AbstractPFTList
)::AbstractBiome where {T<:Real}
    if get_characteristic(optpft, :npp) > T(100.0)
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
    optpft::Default, 
    subpft::AbstractPFT, 
    wdom::AbstractPFT, 
    gdd0::T, 
    gdd5::T, 
    tcm::T, 
    tmin::T, 
    BIOME4PFTS::AbstractPFTList
)::AbstractBiome where {T<:Real}
    if wdom === nothing || isa(wdom, TropicalEvergreen) || 
       isa(wdom, TropicalDroughtDeciduous)
        if wdom !== nothing && get_characteristic(wdom, :lai) > T(4.0)
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
    optpft::None, 
    subpft::AbstractPFT, 
    wdom::AbstractPFT, 
    gdd0::T, 
    gdd5::T, 
    tcm::T, 
    tmin::T, 
    BIOME4PFTS::AbstractPFTList
)::AbstractBiome where {T<:Real}
    return Barren()
end