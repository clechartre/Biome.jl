"""Assign biomes as in BIOME3.5 according to a new scheme of biomes.
Jed Kaplan 3/1998"""

function mock_assign_biome(optpft::U,
    woodpft::U,
    subpft::U,
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

    return 1
end

# FIXME it's actually not an AbstractPFT but a specific PFT
# FIXME we need to return BIOMEtypes with Names - and then IDK I guess there is a solution to turn into an Int in the ned
function assign_biome(optpft::LichenForb)::AbstractBiome
    return 26
end

function assign_biome(optpft::TundraShrubs,
    greendays::U,
    gdd0::T,
    gdd5::T)::AbstractBiome
    if gdd0 < T(200.0)
        return 25
    elseif gdd0 < T(500.0)
        return 24
    else
        return 23
    end
end

function assign_biome(optpft::ColdHerbaceous)::AbstractBiome
    return 22
end

# FIXME present is no longer an object 
function assign_biome(optpft::BorealEvergreen,
    gdd5::T,
    tcm::T,
    present::Dict{String, Bool})::AbstractBiome where {T <: Real}
    if gdd5 > T(900.0) && tcm > T(-19.0)
        if present["temperate_deciduous"]
            return 7
        else
            return 8
        end
    else
        if present["temperate_deciduous"]
            return 9
        else
            return 10
        end
    end

end


function assign_biome(optpft::BorealDeciduous,
    subpft::Union{Nothing, AbstractPFT},
    gdd5::T,
    tcm::T,
    present::Dict{String, Bool})::AbstractBiome where {T <: Real}
    if subpft !== nothing && isa(subpft, TemperateDeciduous)
        return 4
    elseif subpft !== nothing && isa(subpft, CoolConifer)
        return 9
    elseif gdd5 > T(900.0) && tcm > T(-19.0)
        return 9
    else
        return 11
    end
end

function assign_biome(optpft::C3C4WoodyDesert,
    grasslai::T,
    tmin::T,
    optnpp::T,
    subpft::Union{Nothing, AbstractPFT})::AbstractBiome where {T <: Real}
    if optnpp > T(100.0)
        if grasslai > T(1.0)
            return tmin >= T(0.0) ? 13 : 14
        else
            return 21
        end
    else
        return 21
    end
end

function assign_biome(optpft::C3C4TemperateGrass,
    optnpp::T,
    subpft::Union{Nothing, AbstractPFT})::Union{Nothing, AbstractBiome} where {T <: Real}
    if optnpp <= T(100.0)
        if subpft !== nothing && !(isa(subpft, BorealEvergreen) || isa(subpft, BorealDeciduous))
            return 21
        end
    end
    return nothing
end


# function assign_biome(pft_vec, biomes::Desert)

#     if pftpar[optpft].name == "C3_C4_woody_desert"
#             if grasslai > T(1.0)
#                 if tmin >= T(0.0)
#                     return 13
#                 else
#                     return 14
#                 end
#             else
#                 return 21
#             end
#         elseif optnpp <= T(100.0)
#             if pftpar[optpft].name in ["tropical_evergreen", 
#                 "tropical_drought_deciduous", "temperate_broadleaved_evergreen",
#                 "temperate_deciduous", "cool_conifer",
#                 "C4_tropical_grass", "C3_C4_woody_desert"]
#                 # What characteristic of the PFT is being used here? 
#                 # TODO find common characteristic of PFT 1 to 5 and 9 and 10
#                 return 21 
                # FIXME we're still missing this part of the implementation
#             elseif optpft != 0 && pftpar[optpft].name == "C3_C4_temperate_grass"
#                 if subpft != 0 && (pftpar[subpft].name != "boreal_evergreen" || pftpar[subpft].name != "boreal_deciduous")
#                     return 21
#                 end
#             end
#         end

# end

function assign_biome(optpft::TemperateGrass, gdd0::T)::AbstractBiome where {T <: Real}
    if gdd0 >= T(800.0)
        return 20
    else
        return 22
    end
end

function assign_biome(optpft::TemperateBroadleavedEvergreen, optnpp)::AbstractBiome
    if optnpp > 100.0
        return 6  # Temperate Broadleaved Evergreen
    else
        return 21  # Barren or low productivity
    end
end

function assign_biome(optpft::TemperateDeciduous,
    gdd5::T,
    tcm::T,
    present::Dict{String, Bool,
    optnpp})::AbstractBiome where {T <: Real}
    if optnpp > T(100.0)
        if present["boreal_evergreen"]
            if tcm < T(-15.0)
                return 9
            else
                return 7
            end
        elseif present["temperate_broadleaved_evergreen"] || (present["cool_conifer"] && gdd5 > T(3000.0) && tcm > T(3.0))
            return 6
        else
            return 4
        end
    else
        return 21
    end
end

function assign_biome(optpft::CoolConifer,
    subpft::Union{Nothing, AbstractPFT},
    nppdif::T,
    gdd5::T,
    tcm::T,
    present::Dict{String, Bool},
    optnpp)::AbstractBiome where {T <: Real}
    if optnpp > T(100.0)
        if present["temperate_broadleaved_evergreen"]
            return 6
        elseif subpft !== nothing && isa(subpft, TemperateDeciduous) && nppdif < T(50.0)
            return 5
        elseif subpft !== nothing && isa(subpft, BorealDeciduous)
            return 9
        else
            return 5
        end
    else
        return 21
    end
end

function assign_biome(optpft::TropicalEvergreen, optnpp)::AbstractBiome
    if optnpp > 100.0
        return 1  # Tropical Evergreen
    else
        return 21
    end
end

function assign_biome(optpft::TropicalDroughtDeciduous, greendays::U, optnpp)::AbstractBiome where {U <: Int}
    if optnpp > 100.0
        if greendays > U(300)
            return 1
        elseif greendays > U(250)
            return 2
        else
            return 3
        end
    else 
        return 21
    end
end

function assign_biome(optpft::C4TropicalGrass, optnpp)::AbstractBiome
    if optnpp > 100.0
        return 19 
    else
        return 21
    end
end

# FIXME this will 100 fail
function assign_biome(optpft::Int,
    woodpft::Union{Nothing, AbstractPFT},
    woodylai::T)::AbstractBiome where {T <: Real}
    if woodpft === nothing || isa(woodpft, TropicalEvergreen) || isa(woodpft, TropicalDroughtDeciduous)
        if woodylai > T(4.0)
            return 12
        else
            return 13
        end
    elseif isa(woodpft, TemperateBroadleavedEvergreen)
        return 15
    elseif isa(woodpft, TemperateDeciduous)
        return 16
    elseif isa(woodpft, CoolConifer)
        return 17
    elseif isa(woodpft, BorealEvergreen) || isa(woodpft, BorealDeciduous)
        return 18
    end
end

function assign_biome(optpft::Nothing)::AbstractBiome
    return 27  # Barren
end

