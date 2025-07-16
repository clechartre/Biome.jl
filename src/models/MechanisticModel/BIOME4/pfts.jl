# Here make a biome module with pfts and biomes

module BIOME4
using ..Biome: AbstractPFT, PFTCharacteristics, PFTClassification,
 base_tropical_pft, base_temperate_pft, base_boreal_pft, base_grass_pft,
  AbstractBiome, AbstractPFTList, PFTState, Default, None, Desert, get_characteristic

abstract type AbstractBIOME4PFT <: AbstractPFT end

# PFT implementations --------------------------------------------------
struct WoodyDesert{T<:Real,U<:Int} <: AbstractBIOME4PFT
    characteristics::PFTCharacteristics{T,U}
end
WoodyDesert{T,U}() where {T<:Real,U<:Int} = WoodyDesert{T,U}(
    PFTCharacteristics{T,U}(
        name = "C3C4WoodyDesert",
        phenological_type = U(1),
        max_min_canopy_conductance = T(0.1),
        Emax = T(1.0),
        sw_drop = T(-99.9),
        sw_appear = T(-99.9),
        root_fraction_top_soil = T(0.53),
        leaf_longevity = T(12.0),
        sapwood_respiration = U(1),
        optratioa = T(0.70),
        kk = T(0.3),
        c4 = true,
        threshold = T(0.33),
        t0 = T(5.0),
        tcurve = T(1.0),
        respfact = T(1.4),
        allocfact = T(1.0),
        grass = false,
        constraints = (
            tcm = [-Inf,+Inf], min = [T(-45.0),+Inf], gdd=[T(500),+Inf], gdd0=[-Inf,+Inf],
            twm=[T(10.0),+Inf], snow=[-Inf,+Inf], swb=[-Inf,T(500)]
        ),
        mean_val = (clt=T(9.2), prec=T(2.5), temp=T(23.9)),
        sd_val   = (clt=T(2.2), prec=T(2.8), temp=T(2.7))
    )
)
WoodyDesert() = WoodyDesert{Float64,Int}()

struct TropicalEvergreen{T<:Real,U<:Int} <: AbstractBIOME4PFT
    characteristics::PFTCharacteristics{T,U}
end
TropicalEvergreen{T,U}() where {T<:Real,U<:Int} = TropicalEvergreen{T,U}(
    base_tropical_pft(T,U;
        name="TropicalEvergreen", phenological_type=U(1),
        sw_drop=T(-99.9), sw_appear=T(-99.9), leaf_longevity=T(18.0),
        GDD5_full_leaf_out=T(-99.9), GDD0_full_leaf_out=T(-99.9), threshold=T(0.25),
        constraints=(tcm=[-Inf,+Inf], min=[T(0.0),+Inf], gdd=[-Inf,+Inf], gdd0=[-Inf,+Inf],
                    twm=[T(10.0),+Inf], snow=[-Inf,+Inf], swb=[T(700),+Inf]),
        mean_val=(clt=T(50.2), prec=T(169.6), temp=T(24.7)),
        sd_val=(clt=T(4.9),  prec=T(41.9),  temp=T(1.2))
    )
)
TropicalEvergreen() = TropicalEvergreen{Float64,Int}()

struct TropicalDroughtDeciduous{T<:Real,U<:Int} <: AbstractBIOME4PFT
    characteristics::PFTCharacteristics{T,U}
end
TropicalDroughtDeciduous{T,U}() where {T<:Real,U<:Int} = TropicalDroughtDeciduous{T,U}(
    base_tropical_pft(T,U;
        name="TropicalDroughtDeciduous",
        phenological_type=U(3),
        sw_drop=T(0.5), sw_appear=T(0.6), root_fraction_top_soil=T(0.7), leaf_longevity=T(9.0),
        optratioa=T(0.9), threshold=T(0.20),
        # here’s the new block:
        constraints = (
        tcm   = [-Inf, +Inf],
        min   = [T(0.0), +Inf],
        gdd   = [-Inf, +Inf],
        gdd0  = [-Inf, +Inf],
        twm   = [T(10.0), +Inf],
        snow  = [-Inf, +Inf],
        swb   = [T(500), +Inf]         # ← override swb
      ),
      mean_val=(clt=T(44.0), prec=T(163.3), temp=T(23.7)),
      sd_val  =(clt=T(12.9), prec=T(81.5),  temp=T(2.3))
  )
)
TropicalDroughtDeciduous() = TropicalDroughtDeciduous{Float64,Int}()

struct TemperateBroadleavedEvergreen{T<:Real,U<:Int} <: AbstractBIOME4PFT
    characteristics::PFTCharacteristics{T,U}
end
TemperateBroadleavedEvergreen{T,U}() where {T<:Real,U<:Int} = TemperateBroadleavedEvergreen{T,U}(
    base_temperate_pft(T,U;
        name="TemperateBroadleavedEvergreen", max_min_canopy_conductance=T(0.2), Emax=T(4.8),
        leaf_longevity=T(18.0), respfact=T(1.4), threshold = T(0.4),
        constraints=(tcm=[-Inf,+Inf], min=[T(-8.0),T(5.0)], gdd=[T(1200),+Inf], gdd0=[-Inf,+Inf],
                     twm=[T(10.0),+Inf], snow=[-Inf,+Inf], swb=[T(400),+Inf]),
        mean_val=(clt=T(33.4), prec=T(106.3), temp=T(18.7)),
        sd_val  =(clt=T(13.3), prec=T(83.6),  temp=T(3.2))
    )
)
TemperateBroadleavedEvergreen() = TemperateBroadleavedEvergreen{Float64,Int}()

struct TemperateDeciduous{T<:Real,U<:Int} <: AbstractBIOME4PFT
    characteristics::PFTCharacteristics{T,U}
end
TemperateDeciduous{T,U}() where {T<:Real,U<:Int} = TemperateDeciduous{T,U}(
    base_temperate_pft(T,U;
        name="TemperateDeciduous", phenological_type=U(2), max_min_canopy_conductance=T(0.8), Emax=T(10.0),
        root_fraction_top_soil=T(0.65), leaf_longevity=T(7.0), GDD5_full_leaf_out=T(200.0),
        threshold=T(0.33), t0=T(4.0), respfact=T(1.6),
        constraints=(tcm=[T(-15.0),+Inf], min=[-Inf,T(-8.0)], gdd=[T(1200),+Inf], gdd0=[-Inf,+Inf],
                     twm=[-Inf,+Inf], snow=[-Inf,+Inf], swb=[T(300),+Inf]),
        mean_val=(clt=T(40.9), prec=T(70.2), temp=T(8.4)),
        sd_val  =(clt=T(8.6), prec=T(41.9), temp=T(4.7))
    )
)
TemperateDeciduous() = TemperateDeciduous{Float64,Int}()

struct CoolConifer{T<:Real,U<:Int} <: AbstractBIOME4PFT
    characteristics::PFTCharacteristics{T,U}
end
CoolConifer{T,U}() where {T<:Real,U<:Int} = CoolConifer{T,U}(
    base_temperate_pft(T,U;
        name="CoolConifer", max_min_canopy_conductance=T(0.2), Emax=T(4.8),
        root_fraction_top_soil=T(0.52), leaf_longevity=T(30.0), optratioa=T(0.9), kk=T(0.5),
        t0=T(3.0), tcurve=T(0.9), respfact=T(0.8), threshold = T(0.4),
        constraints=(tcm=[T(-2.0),+Inf], min=[-Inf,T(10.0)], gdd=[T(900),+Inf], gdd0=[-Inf,+Inf],
                     twm=[T(10.0),+Inf], snow=[-Inf,+Inf], swb=[T(500),+Inf]),
        mean_val=(clt=T(28.1), prec=T(54.5), temp=T(13.9)),
        sd_val  =(clt=T(8.6), prec=T(49.9), temp=T(3.4))
    )
)
CoolConifer() = CoolConifer{Float64,Int}()

struct BorealEvergreen{T<:Real,U<:Int} <: AbstractBIOME4PFT
    characteristics::PFTCharacteristics{T,U}
end
BorealEvergreen{T,U}() where {T<:Real,U<:Int} = BorealEvergreen{T,U}(
    base_boreal_pft(T,U;
        name="BorealEvergreen", max_min_canopy_conductance=T(0.5), Emax=T(4.5), kk=T(0.5), optratioa= T(0.8),
        constraints=(tcm=[T(-32.5),T(-2.0)], min=[-Inf,+Inf], gdd=[-Inf,+Inf], gdd0=[-Inf,+Inf],
                     twm=[-Inf,T(21.0)], snow=[-Inf,+Inf], swb=[-Inf,+Inf]),
        mean_val=(clt=T(48.1), prec=T(58.7), temp=T(-2.7)),
        sd_val  =(clt=T(7.6), prec=T(35.7), temp=T(4.0))
    )
)
BorealEvergreen() = BorealEvergreen{Float64,Int}()

struct BorealDeciduous{T<:Real,U<:Int} <: AbstractBIOME4PFT
    characteristics::PFTCharacteristics{T,U}
end
BorealDeciduous{T,U}() where {T<:Real,U<:Int} = BorealDeciduous{T,U}(
    base_boreal_pft(T,U;
        name="BorealDeciduous", phenological_type=U(2), max_min_canopy_conductance=T(0.8), Emax=T(10.0),
        GDD5_full_leaf_out=T(200.0), optratioa=T(0.9), kk=T(0.4),
        constraints=(tcm=[-Inf,T(5.0)], min=[-Inf,T(-10.0)], gdd=[-Inf,+Inf], gdd0=[-Inf,+Inf],
                     twm=[-Inf,T(21.0)], snow=[-Inf,+Inf], swb=[T(300),+Inf]),
        mean_val=(clt=T(47.4), prec=T(65.0), temp=T(-6.4)),
        sd_val  =(clt=T(8.3), prec=T(83.6), temp=T(7.7))
    )
)
BorealDeciduous() = BorealDeciduous{Float64,Int}()

struct C3C4TemperateGrass{T<:Real,U<:Int} <: AbstractBIOME4PFT
    characteristics::PFTCharacteristics{T,U}
end
C3C4TemperateGrass{T,U}() where {T<:Real,U<:Int} = C3C4TemperateGrass{T,U}(
    base_grass_pft(T,U;
        name="C3C4TemperateGrass", Emax=T(6.5), root_fraction_top_soil=T(0.83), leaf_longevity=T(8.0),
        GDD0_full_leaf_out=T(100.0), t0=T(4.5), respfact=T(1.6), optratioa = T(0.65), 
        constraints=(tcm=[-Inf,+Inf], min=[-Inf,T(0.0)], gdd=[T(550),+Inf], gdd0=[-Inf,+Inf], twm=[-Inf,+Inf], snow=[-Inf,+Inf], swb=[-Inf,+Inf]),
        mean_val=(clt=T(16.6), prec=T(12.2), temp=T(21.3)), sd_val=(clt=T(6.9), prec=T(13.4), temp=T(6.2))
    )
)
C3C4TemperateGrass() = C3C4TemperateGrass{Float64,Int}()

struct C4TropicalGrass{T<:Real,U<:Int} <: AbstractBIOME4PFT
    characteristics::PFTCharacteristics{T,U}
end
C4TropicalGrass{T,U}() where {T<:Real,U<:Int} = C4TropicalGrass{T,U}(
    base_grass_pft(T,U;
        name="C4TropicalGrass", Emax=T(8.0), root_fraction_top_soil=T(0.57), leaf_longevity=T(10.0), GDD0_full_leaf_out=T(-99.9), c4=true, t0=T(10.0), respfact=T(0.8),
        constraints=(tcm=[-Inf,+Inf], min=[T(-3.0),+Inf], gdd=[-Inf,+Inf], gdd0=[-Inf,+Inf], twm=[T(10.0),+Inf], snow=[-Inf,+Inf], swb=[T(200),+Inf]),
        mean_val=(clt=T(9.4), prec=T(1.7), temp=T(23.2)), sd_val=(clt=T(1.4), prec=T(2.1), temp=T(2.2))
    )
)
C4TropicalGrass() = C4TropicalGrass{Float64,Int}()

struct TundraShrubs{T<:Real,U<:Int} <: AbstractBIOME4PFT
    characteristics::PFTCharacteristics{T,U}
end
TundraShrubs{T,U}() where {T<:Real,U<:Int} = TundraShrubs{T,U}(
    base_grass_pft(T,U;
        name="TundraShrubs", max_min_canopy_conductance=T(0.8), Emax=T(1.0), root_fraction_top_soil=T(0.93), leaf_longevity=T(8.0),
        sw_drop=T(-99.9), sw_appear=T(-99.9), t0=T(-7.0), tcurve=T(0.6), respfact=T(4.0),
        constraints=(tcm=[-Inf,+Inf], min=[-Inf,+Inf], gdd=[-Inf,+Inf], gdd0=[T(50.0),+Inf], twm=[-Inf,T(15.0)], snow=[T(15.0),+Inf], swb=[T(150),+Inf]),
        mean_val=(clt=T(9.2), prec=T(2.5), temp=T(23.9)), sd_val=(clt=T(2.2), prec=T(2.8), temp=T(2.7))
    )
)
TundraShrubs() = TundraShrubs{Float64,Int}()

struct ColdHerbaceous{T<:Real,U<:Int} <: AbstractBIOME4PFT
    characteristics::PFTCharacteristics{T,U}
end
ColdHerbaceous{T,U}() where {T<:Real,U<:Int} = ColdHerbaceous{T,U}(
    base_grass_pft(T,U;
        name="ColdHerbaceous", phenological_type=U(2), max_min_canopy_conductance=T(0.8), Emax=T(1.0),
         root_fraction_top_soil=T(0.93), leaf_longevity=T(8.0),
        GDD0_full_leaf_out=T(25.0), t0=T(-7.0), tcurve=T(0.6), respfact=T(4.0), optratioa = T(0.75), kk = T(0.30), 
        constraints=(tcm=[-Inf,+Inf], min=[-Inf,+Inf], gdd=[-Inf,+Inf], gdd0=[T(50.0),+Inf], twm=[-Inf,T(15.0)], snow=[-Inf,+Inf], swb=[T(150),+Inf]),
        mean_val=(clt=T(10.4), prec=T(2.0), temp=T(23.5)), sd_val=(clt=T(2.5), prec=T(1.6), temp=T(2.3))
    )
)
ColdHerbaceous() = ColdHerbaceous{Float64,Int}()

struct LichenForb{T<:Real,U<:Int} <: AbstractBIOME4PFT
    characteristics::PFTCharacteristics{T,U}
end
LichenForb{T,U}() where {T<:Real,U<:Int} = LichenForb{T,U}(
    base_boreal_pft(T,U;
        name="LichenForb", phenological_type=U(1), max_min_canopy_conductance=T(0.8), Emax=T(1.0),
        sw_drop=T(-99.9), sw_appear=T(-99.9),
        root_fraction_top_soil=T(0.93), leaf_longevity=T(8.0),
        GDD5_full_leaf_out=T(-99.9), GDD0_full_leaf_out=T(-99.9),
        sapwood_respiration=U(1), optratioa=T(0.8), kk=T(0.6), c4=false,
        threshold=T(0.33), t0=T(-12.0), tcurve=T(0.5), respfact=T(4.0), allocfact=T(1.5), grass=false,
        constraints=(
            tcm   = [-Inf,+Inf],
            min   = [-Inf,+Inf],
            gdd   = [-Inf,+Inf],
            gdd0  = [-Inf,+Inf],
            twm   = [-Inf,T(15.0)],
            snow  = [-Inf,+Inf],
            swb   = [-Inf,+Inf]
        ),
        mean_val=(clt=T(43.9), prec=T(53.3), temp=T(-18.4)),
        sd_val  =(clt=T(9.0), prec=T(52.1), temp=T(4.1))
    )
)
LichenForb() = LichenForb{Float64,Int}()


function PFTClassification{T,U}() where {T<:Real,U<:Int}
    return PFTClassification{T,U}([
        TropicalEvergreen{T,U}(),
        TropicalDroughtDeciduous{T,U}(),
        TemperateBroadleavedEvergreen{T,U}(),
        TemperateDeciduous{T,U}(),
        CoolConifer{T,U}(),
        BorealEvergreen{T,U}(),
        BorealDeciduous{T,U}(),
        C3C4TemperateGrass{T,U}(),
        C4TropicalGrass{T,U}(),
        WoodyDesert{T,U}(),
        TundraShrubs{T,U}(),
        ColdHerbaceous{T,U}(),
        LichenForb{T,U}()
    ])
end
PFTClassification() = PFTClassification{Float64,Int}()

# Biome implementations --------------------------------------------------
# Define the Biome structures
struct TropicalEvergreenForest <: AbstractBiome
    value::Int
    TropicalEvergreenForest() = new(1)
end

struct TropicalSemiDeciduousForest <: AbstractBiome
    value::Int
    TropicalSemiDeciduousForest() = new(2)
end

struct TropicalDeciduousForestWoodland <: AbstractBiome
    value::Int
    TropicalDeciduousForestWoodland() = new(3)
end

struct TemperateDeciduousForest <: AbstractBiome
    value::Int
    TemperateDeciduousForest() = new(4)
end

struct TemperateConiferForest <: AbstractBiome
    value::Int
    TemperateConiferForest() = new(5)
end

struct WarmMixedForest <: AbstractBiome
    value::Int
    WarmMixedForest() = new(6)
end

struct CoolConiferForest <: AbstractBiome
    value::Int
    CoolConiferForest() = new(7)
end

struct CoolMixedForest <: AbstractBiome
    value::Int
    CoolMixedForest() = new(8)
end

struct ColdMixedForest <: AbstractBiome
    value::Int
    ColdMixedForest() = new(9)
end

struct EvergreenTaigaMontaneForest <: AbstractBiome
    value::Int
    EvergreenTaigaMontaneForest() = new(10)
end

struct DeciduousTaigaMontaneForest <: AbstractBiome
    value::Int
    DeciduousTaigaMontaneForest() = new(11)
end

struct TropicalSavanna <: AbstractBiome
    value::Int
    TropicalSavanna() = new(12)
end

struct TropicalXerophyticShrubland <: AbstractBiome
    value::Int
    TropicalXerophyticShrubland() = new(13)
end

struct TemperateXerophyticShrubland <: AbstractBiome
    value::Int
    TemperateXerophyticShrubland() = new(14)
end

struct TemperateSclerophyllWoodland <: AbstractBiome
    value::Int
    TemperateSclerophyllWoodland() = new(15)
end

struct TemperateBroadleavedSavanna <: AbstractBiome
    value::Int
    TemperateBroadleavedSavanna() = new(16)
end

struct OpenConiferWoodland <: AbstractBiome
    value::Int
    OpenConiferWoodland() = new(17)
end

struct BorealParkland <: AbstractBiome
    value::Int
    BorealParkland() = new(18)
end

struct TropicalGrassland <: AbstractBiome
    value::Int
    TropicalGrassland() = new(19)
end

struct TemperateGrassland <: AbstractBiome
    value::Int
    TemperateGrassland() = new(20)
end

# struct Desert <: AbstractBiome
#     value::Int
#     Desert() = new(21)
# end

struct SteppeTundra <: AbstractBiome
    value::Int
    SteppeTundra() = new(22)
end

struct ShrubTundra <: AbstractBiome
    value::Int
    ShrubTundra() = new(23)
end

struct DwarfShrubTundra <: AbstractBiome
    value::Int
    DwarfShrubTundra() = new(24)
end

struct ProstateShrubTundra <: AbstractBiome
    value::Int
    ProstateShrubTundra() = new(25)
end

struct CushionForbsLichenMoss <: AbstractBiome
    value::Int
    CushionForbsLichenMoss() = new(26)
end

struct Barren <: AbstractBiome
    value::Int
    Barren() = new(27)
end

struct LandIce <: AbstractBiome
    value::Int
    LandIce() = new(28)
end

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

export 
    TropicalEvergreenForest, TropicalSemiDeciduousForest, TropicalDeciduousForestWoodland,
    TemperateDeciduousForest, TemperateConiferForest, WarmMixedForest, CoolConiferForest,
    CoolMixedForest, ColdMixedForest, EvergreenTaigaMontaneForest, DeciduousTaigaMontaneForest,
    TropicalSavanna, TropicalXerophyticShrubland, TemperateXerophyticShrubland,
    TemperateSclerophyllWoodland, TemperateBroadleavedSavanna, OpenConiferWoodland,
    BorealParkland, TropicalGrassland, TemperateGrassland, SteppeTundra, ShrubTundra,
    DwarfShrubTundra, ProstateShrubTundra, CushionForbsLichenMoss, Barren, LandIce,
    assign_biome

end # module BIOME4