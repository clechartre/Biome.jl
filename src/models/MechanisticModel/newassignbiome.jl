"""Assign biomes as in BIOME3.5 according to a new scheme of biomes.
Jed Kaplan 3/1998"""

include("./pfts.jl")
include("./biomes.jl")
export TropicalEvergreen, TropicalDroughtDeciduous, 
       TemperateBroadleavedEvergreen, TemperateDeciduous, 
       CoolConifer, BorealEvergreen, BorealDeciduous, C4TropicalGrass,
       LichenForb, TundraShrubs, ColdHerbaceous,
       WoodyDesert, C3C4TemperateGrass

function mock_assign_biome(optpft::Union{AbstractPFT, Nothing},
    woodpft::Union{AbstractPFT, Nothing},
    subpft::Union{AbstractPFT, Nothing},
    optnpp::Union{U, T},
    subnpp::Union{U, T},
    greendays::U,
    gdd0::T,
    gdd5::T,
    tcm::T,
    woodylai::T,
    grasslai::T,
    tmin::T,
    BIOME4PFTS::AbstractPFTList)::U where {T <: Real, U <: Int}

    return U(1)
end

#FIXME it's actually not an AbstractPFT but a specific PFT
# FIXME we need to return BIOMEtypes with Names - and then IDK I guess there is a solution to turn into an Int in the ned
function assign_biome(optpft::LichenForb, subpft::AbstractPFT, wdom::AbstractPFT, gdom::AbstractPFT, env_vars::ComponentArray, BIOME4PFTS::AbstractPFTList)::AbstractBiome
    return Barren
end

function assign_biome(optpft::TundraShrubs, subpft::AbstractPFT, wdom::AbstractPFT, gdom::AbstractPFT, env_vars::AbstractVector, BIOME4PFTS::AbstractPFTList)::AbstractBiome where {T <: Real, U <: Int}
    if gdd0 < T(200.0)
        return CushionForbsLichenMoss
    elseif gdd0 < T(500.0)
        return ProstateShrubTundra
    else
        return DwarfShrubTundra
    end
end

function assign_biome(optpft::ColdHerbaceous, subpft::AbstractPFT, wdom::AbstractPFT, gdom::AbstractPFT, env_vars::AbstractVector, BIOME4PFTS::AbstractPFTList)::AbstractBiome
    return SteppeTundra
end

# FIXME present is no longer an object  - need to pass the entire BIOME4PFTS object and check presence for exactly these PFTs
function assign_biome(optpft::BorealEvergreen, subpft::AbstractPFT, wdom::AbstractPFT, gdom::AbstractPFT, env_vars::AbstractVector, BIOME4PFTS::AbstractPFTList)::AbstractBiome where {T <: Real}
    if gdd5 > T(900.0) && tcm > T(-19.0)
        temperate_deciduous_idx = findfirst(pft -> get_characteristic(pft, :name) == "TemperateDeciduous", BIOME4PFTS.pft_list)
        if temperate_deciduous_idx !== nothing && get_characteristic(BIOME4PFTS.pft_list[temperate_deciduous_idx], :present)
            return CoolMixedForest
        else
            return ColdMixedForest
        end
    else
        temperate_deciduous_idx = findfirst(pft -> get_characteristic(pft, :name) == "TemperateDeciduous", BIOME4PFTS.pft_list)
        if temperate_deciduous_idx !== nothing && get_characteristic(BIOME4PFTS.pft_list[temperate_deciduous_idx], :present)
            return ColdMixedForest
        else
            return EvergreenTaigaMontaneForest
        end
    end

end


function assign_biome(optpft::BorealDeciduous, subpft::AbstractPFT, wdom::AbstractPFT, gdom::AbstractPFT, env_vars::AbstractVector, BIOME4PFTS::AbstractPFTList)::AbstractBiome where {T <: Real}
    if subpft !== nothing && isa(subpft, TemperateDeciduous)
        return TemperateDeciduousForest
    elseif subpft !== nothing && isa(subpft, CoolConifer)
        return CoolConiferForest
    elseif gdd5 > T(900.0) && tcm > T(-19.0)
        return CoolConiferForest
    else
        return DeciduousTaigaMontaneForest
    end
end

function assign_biome(optpft::WoodyDesert, subpft::AbstractPFT, wdom::AbstractPFT, gdom::AbstractPFT, env_vars::AbstractVector, BIOME4PFTS::AbstractPFTList)::AbstractBiome where {T <: Real}
    if get_characteristic(optpft, :npp)  > T(100.0)
        if get_characteristic(subpft, :lai) > T(1.0)
            return tmin >= T(0.0) ? TropicalXerophyticShrubland : TemperateXerophyticShrubland
        else
            return Desert
        end
    else
        return Desert
    end
end

function assign_biome(optpft::C3C4TemperateGrass, subpft::AbstractPFT, wdom::AbstractPFT, gdom::AbstractPFT, env_vars::AbstractVector, BIOME4PFTS::AbstractPFTList)::AbstractBiome where {T <: Real}
    if get_characteristic(optpft, :npp) <= T(100.0)
        if subpft !== nothing && !(isa(subpft, BorealEvergreen) || isa(subpft, BorealDeciduous))
            return Desert
        end
    elseif gdd0 >= T(800.0)
        return TemperateGrassland
    else
        return SteppeTundra
    end
end

function assign_biome(optpft::TemperateBroadleavedEvergreen, subpft::AbstractPFT, wdom::AbstractPFT, gdom::AbstractPFT, env_vars::AbstractVector, BIOME4PFTS::AbstractPFTList)::AbstractBiome
    if get_characteristic(optpft, :npp) > T(100.0)
        return WarmMixedForest
    else
        return Desert
    end
end

# FIXME, how do we handle the presence?
function assign_biome(optpft::TemperateDeciduous, subpft::AbstractPFT, wdom::AbstractPFT, gdom::AbstractPFT, env_vars::AbstractVector, BIOME4PFTS::AbstractPFTList)::AbstractBiome where {T <: Real}
    if get_characteristic(optpft, :npp) > T(100.0)
        boreal_evergreen_idx = findfirst(pft -> get_characteristic(pft, :name) == "BorealEvergreen", BIOME4PFTS.pft_list)
        if boreal_evergreen_idx !== nothing && get_characteristic(BIOME4PFTS.pft_list[boreal_evergreen_idx], :present)
            if tcm < T(-15.0)
                return ColdMixedForest
            else
                return CoolMixedForest
            end
        temperate_broadleaved_evergreen_idx = findfirst(pft -> get_characteristic(pft, :name) == "TemperateBroadleavedEvergreen", BIOME4PFTS.pft_list)
        cool_conifer_idx = findfirst(pft -> get_characteristic(pft, :name) == "CoolConifer", BIOME4PFTS.pft_list)
        elseif get_characteristic(BIOME4PFTS.pft_list[temperate_broadleaved_evergreen_idx], :present) || (get_characteristic(BIOME4PFTS.pft_list[cool_conifer_idx], :present) && gdd5 > T(3000.0) && tcm > T(3.0))
            return WarmMixedForest
        else
            return TemperateDeciduousForest
        end
    else
        return Desert
    end
end

function assign_biome(optpft::CoolConifer, subpft::AbstractPFT, wdom::AbstractPFT, gdom::AbstractPFT, env_vars::AbstractVector, BIOME4PFTS::AbstractPFTList)::AbstractBiome where {T <: Real}
    if get_characteristic(optpft, :npp) > T(100.0)
        temperate_broadleaved_evergreen_idx = findfirst(pft -> get_characteristic(pft, :name) == "TemperateBroadleavedEvergreen", BIOME4PFTS.pft_list)
        if get_characteristic(BIOME4PFTS.pft_list[temperate_broadleaved_evergreen_idx], :present)
            return WarmMixedForest
        elseif subpft !== nothing && isa(subpft, TemperateDeciduous) && nppdif < T(50.0)
            return TemperateConiferForest
        elseif subpft !== nothing && isa(subpft, BorealDeciduous)
            return ColdMixedForest
        else
            return TemperateConiferForest
        end
    else
        return Desert
    end
end

function assign_biome(optpft::TropicalEvergreen, subpft::AbstractPFT, wdom::AbstractPFT, gdom::AbstractPFT, env_vars::AbstractVector, BIOME4PFTS::AbstractPFTList)::AbstractBiome
    if get_characteristic(optpft, :npp) > T(100.0)
        return TropicalEvergreenForest
    else
        return Desert
    end
end

function assign_biome(optpft::TropicalDroughtDeciduous, subpft::AbstractPFT, wdom::AbstractPFT, gdom::AbstractPFT, env_vars::AbstractVector, BIOME4PFTS::AbstractPFTList)::AbstractBiome where {U <: Int}
    if get_characteristic(optpft, :npp) > T(100.0)
        if get_characteristic(optpft, :greendays)  > U(300)
            return TropicalEvergreenForest
        elseif get_characteristic(optpft, :greendays) > U(250)
            return TropicalSemiDeciduousForest
        else
            return TropicalDeciduousForestWoodland
        end
    else 
        return Desert
    end
end

function assign_biome(optpft::C4TropicalGrass, subpft::AbstractPFT, wdom::AbstractPFT, gdom::AbstractPFT, env_vars::AbstractVector, BIOME4PFTS::AbstractPFTList)::AbstractBiome
    if get_characteristic(optpft, :npp)  > 100.0
        return TropicalGrassland
    else
        return Desert
    end
end

# FIXME this will 100 fail
function assign_biome(optpft::AbstractPFT, subpft::AbstractPFT, wdom::AbstractPFT, gdom::AbstractPFT, env_vars::AbstractVector, BIOME4PFTS::AbstractPFTList)::AbstractBiome where {T <: Real}
    if wdom === nothing || isa(wdom, TropicalEvergreen) || isa(wdom, TropicalDroughtDeciduous)
        if get_characteristic(wdom, :lai) > T(4.0)
            return TropicalSavanna
        else
            return TropicalXerophyticShrubland
        end
    elseif isa(wdom, TemperateBroadleavedEvergreen)
        return TemperateSclerophyllWoodland
    elseif isa(wdom, TemperateDeciduous)
        return TemperateBroadleavedSavanna
    elseif isa(wdom, CoolConifer)
        return OpenConiferWoodland
    elseif isa(wdom, BorealEvergreen) || isa(wdom, BorealDeciduous)
        return BorealParkland
    end
end

function assign_biome(optpft::Nothing, subpft::AbstractPFT, wdom::AbstractPFT, gdom::AbstractPFT, env_vars::AbstractVector, BIOME4PFTS::AbstractPFTList)::AbstractBiome
    return Barren  # Barren
end

