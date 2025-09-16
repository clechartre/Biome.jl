module BIOME4
using ..Biome: AbstractPFT, PFTCharacteristics, PFTClassification,
  AbstractBiome, AbstractPFTList, PFTState, Default, None, Desert, get_characteristic

abstract type AbstractBIOME4PFT <: AbstractPFT end

using Distributions
using Parameters: @kwdef

# 1) WoodyDesert
struct WoodyDesert{T<:Real,U<:Int} <: AbstractPFT
    characteristics::PFTCharacteristics{T,U}
end

function WoodyDesert{T,U}() where {T<:Real,U<:Int}
    return WoodyDesert{T,U}(
        PFTCharacteristics{T,U}(
            "C3C4WoodyDesert",
            U(1),
            T(0.1),
            T(1.0),
            T(-99.9),
            T(-99.9),
            T(0.53),
            T(12.0),
            T(-99.9),
            T(-99.9),
            U(1),
            T(0.70),
            T(0.3),
            true,
            T(0.33),
            T(5.0),
            T(1.0),
            T(1.4),
            T(1.0),
            false,
            (
                tcm=[-Inf, +Inf],
                tmin=[T(-45.0), +Inf],
                gdd5=[T(500), +Inf],
                gdd0=[-Inf, +Inf],
                twm=[T(10.0), +Inf],
                maxdepth=[-Inf, +Inf],
                swb=[-Inf,T(500)]
            ),
            (clt=T(9.2), prec=T(2.5), temp=T(23.9)),
            (clt=T(2.2), prec=T(2.8), temp=T(2.7)),
            U(7)
        )
    )
end

WoodyDesert() = WoodyDesert{Float64,Int}()

# 2) TropicalEvergreen
struct TropicalEvergreen{T<:Real,U<:Int} <: AbstractPFT
    characteristics::PFTCharacteristics{T,U}
end

function TropicalEvergreen{T,U}() where {T<:Real,U<:Int}
    return TropicalEvergreen{T,U}(
        PFTCharacteristics{T,U}(
            "TropicalEvergreen",
            U(1),
            T(0.5),
            T(10.0),
            T(-99.9),
            T(-99.9),
            T(0.69),
            T(18.0),
            T(-99.9),
            T(-99.9),
            U(1),
            T(0.95),
            T(0.7),
            false,
            T(0.25),
            T(10.0),
            T(1.0),
            T(0.8),
            T(1.0),
            false,
            (
                tcm=[-Inf, +Inf],
                tmin=[T(0.0), +Inf],
                gdd5=[-Inf, +Inf],
                gdd0=[-Inf, +Inf],
                twm=[T(10.0), +Inf],
                maxdepth=[-Inf, +Inf],
                swb=[T(700),+Inf]
            ),
            (clt=T(50.2), prec=T(169.6), temp=T(24.7)),
            (clt=T(4.9),  prec=T(41.9),  temp=T(1.2)),
            U(1)
        )
    )
end

TropicalEvergreen() = TropicalEvergreen{Float64,Int}()

# 3) TropicalDroughtDeciduous
struct TropicalDroughtDeciduous{T<:Real,U<:Int} <: AbstractPFT
    characteristics::PFTCharacteristics{T,U}
end

function TropicalDroughtDeciduous{T,U}() where {T<:Real,U<:Int}
    return TropicalDroughtDeciduous{T,U}(
        PFTCharacteristics{T,U}(
            "TropicalDroughtDeciduous",
            U(3),
            T(0.5),
            T(10.0),
            T(0.5),
            T(0.6),
            T(0.7),
            T(9.0),
            T(-99.9),
            T(-99.9),
            U(1),
            T(0.9),
            T(0.7),
            false,
            T(0.20),
            T(10.0),
            T(1.0),
            T(0.8),
            T(1.0),
            false,
            (
                tcm=[-Inf, +Inf],
                tmin=[T(0.0), +Inf],
                gdd5=[-Inf, +Inf],
                gdd0=[-Inf, +Inf],
                twm=[T(10.0), +Inf],
                maxdepth=[-Inf, +Inf],
                swb=[T(500),+Inf]
            ),
            (clt=T(44.0), prec=T(163.3), temp=T(23.7)),
            (clt=T(12.9), prec=T(81.5),  temp=T(2.3)),
            U(1)
        )
    )
end

TropicalDroughtDeciduous() = TropicalDroughtDeciduous{Float64,Int}()

# 4) TemperateBroadleavedEvergreen
struct TemperateBroadleavedEvergreen{T<:Real,U<:Int} <: AbstractPFT
    characteristics::PFTCharacteristics{T,U}
end

function TemperateBroadleavedEvergreen{T,U}() where {T<:Real,U<:Int}
    return TemperateBroadleavedEvergreen{T,U}(
        PFTCharacteristics{T,U}(
            "TemperateBroadleavedEvergreen",
            U(1),
            T(0.2),
            T(4.8),
            T(-99.9),
            T(-99.9),
            T(0.67),
            T(18.0),
            T(-99.9),
            T(-99.9),
            U(1),
            T(0.8),
            T(0.6),
            false,
            T(0.40),
            T(5.0),
            T(1.0),
            T(1.4),
            T(1.2),
            false,
            (
                tcm=[-Inf, +Inf],
                tmin=[T(-8.0), T(5.0)],
                gdd5=[T(1200), +Inf],
                gdd0=[-Inf, +Inf],
                twm=[T(10.0), +Inf],
                maxdepth=[-Inf, +Inf],
                swb=[T(400),+Inf]
            ),
            (clt=T(33.4), prec=T(106.3), temp=T(18.7)),
            (clt=T(13.3), prec=T(83.6),  temp=T(3.2)),
            U(2)
        )
    )
end

TemperateBroadleavedEvergreen() = TemperateBroadleavedEvergreen{Float64,Int}()

# 5) TemperateDeciduous
struct TemperateDeciduous{T<:Real,U<:Int} <: AbstractPFT
    characteristics::PFTCharacteristics{T,U}
end

function TemperateDeciduous{T,U}() where {T<:Real,U<:Int}
    return TemperateDeciduous{T,U}(
        PFTCharacteristics{T,U}(
            "TemperateDeciduous",
            U(2),
            T(0.8),
            T(10.0),
            T(-99.9),
            T(-99.9),
            T(0.65),
            T(7.0),
            T(200.0),
            T(-99.9),
            U(1),
            T(0.8),
            T(0.6),
            false,
            T(0.33),
            T(4.0),
            T(1.0),
            T(1.6),
            T(1.2),
            false,
            (
                tcm=[T(-15.0), +Inf],
                tmin=[-Inf, T(-8.0)],
                gdd5=[T(1200), +Inf],
                gdd0=[-Inf, +Inf],
                twm=[-Inf, +Inf],
                maxdepth=[-Inf, +Inf],
                swb=[T(300),+Inf]
            ),
            (clt=T(40.9), prec=T(70.2), temp=T(8.4)),
            (clt=T(8.6), prec=T(41.9), temp=T(4.7)),
            U(3)
        )
    )
end

TemperateDeciduous() = TemperateDeciduous{Float64,Int}()

# 6) CoolConifer
struct CoolConifer{T<:Real,U<:Int} <: AbstractPFT
    characteristics::PFTCharacteristics{T,U}
end

function CoolConifer{T,U}() where {T<:Real,U<:Int}
    return CoolConifer{T,U}(
        PFTCharacteristics{T,U}(
            "CoolConifer",
            U(1),
            T(0.2),
            T(4.8),
            T(-99.9),
            T(-99.9),
            T(0.52),
            T(30.0),
            T(-99.9),
            T(-99.9),
            U(1),
            T(0.9),
            T(0.5),
            false,
            T(0.40),
            T(3.0),
            T(0.9),
            T(0.8),
            T(1.2),
            false,
            (
                tcm=[T(-2.0), +Inf],
                tmin=[-Inf, T(10.0)],
                gdd5=[T(900), +Inf],
                gdd0=[-Inf, +Inf],
                twm=[T(10.0), +Inf],
                maxdepth=[-Inf, +Inf],
                swb=[T(400),+Inf]
            ),
            (clt=T(28.1), prec=T(54.5), temp=T(13.9)),
            (clt=T(8.6), prec=T(49.9), temp=T(3.4)),
            U(3)
        )
    )
end

CoolConifer() = CoolConifer{Float64,Int}()

# 7) BorealEvergreen
struct BorealEvergreen{T<:Real,U<:Int} <: AbstractPFT
    characteristics::PFTCharacteristics{T,U}
end

function BorealEvergreen{T,U}() where {T<:Real,U<:Int}
    return BorealEvergreen{T,U}(
        PFTCharacteristics{T,U}(
            "BorealEvergreen",
            U(1),
            T(0.5),
            T(4.5),
            T(-99.9),
            T(-99.9),
            T(0.83),
            T(24.0),
            T(-99.9),
            T(-99.9),
            U(1),
            T(0.8),
            T(0.5),
            false,
            T(0.33),
            T(0.0),
            T(0.8),
            T(4.0),
            T(1.2),
            false,
            (
                tcm=[T(-32.5), T(-2.0)],
                tmin=[-Inf, +Inf],
                gdd5=[-Inf, +Inf],
                gdd0=[-Inf, +Inf],
                twm=[-Inf, T(21.0)],
                maxdepth=[-Inf, +Inf],
                swb=[-Inf,+Inf]
            ),
            (clt=T(48.1), prec=T(58.7), temp=T(-2.7)),
            (clt=T(7.6), prec=T(35.7), temp=T(4.0)),
            U(3)
        )
    )
end

BorealEvergreen() = BorealEvergreen{Float64,Int}()

# 8) BorealDeciduous
struct BorealDeciduous{T<:Real,U<:Int} <: AbstractPFT
    characteristics::PFTCharacteristics{T,U}
end

function BorealDeciduous{T,U}() where {T<:Real,U<:Int}
    return BorealDeciduous{T,U}(
        PFTCharacteristics{T,U}(
            "BorealDeciduous",
            U(2),
            T(0.8),
            T(10.0),
            T(-99.9),
            T(-99.9),
            T(0.83),
            T(24.0),
            T(200.0),
            T(-99.9),
            U(1),
            T(0.9),
            T(0.4),
            false,
            T(0.33),
            T(0.0),
            T(0.8),
            T(4.0),
            T(1.2),
            false,
            (
                tcm=[-Inf, T(5.0)],
                tmin=[-Inf, T(-10.0)],
                gdd5=[-Inf, +Inf],
                gdd0=[-Inf, +Inf],
                twm=[-Inf, T(21.0)],
                maxdepth=[-Inf, +Inf],
                swb=[-Inf,+Inf]
            ),
            (clt=T(34.6), prec=T(39.29), temp=T(-0.5)),
            (clt=T(7.4), prec=T(26.9), temp=T(2.6)),
            U(3)
        )
    )
end

BorealDeciduous() = BorealDeciduous{Float64,Int}()

# 9) C3C4TemperateGrass
struct C3C4TemperateGrass{T<:Real,U<:Int} <: AbstractPFT
    characteristics::PFTCharacteristics{T,U}
end

function C3C4TemperateGrass{T,U}() where {T<:Real,U<:Int}
    return C3C4TemperateGrass{T,U}(
        PFTCharacteristics{T,U}(
            "C3C4TemperateGrass",
            U(3),
            T(0.8),
            T(6.5),
            T(0.2),
            T(0.3),
            T(0.83),
            T(8.0),
            T(-99.9),
            T(100.0),
            U(2),
            T(0.65),
            T(0.4),
            false,
            T(0.40),
            T(4.5),
            T(1.0),
            T(1.6),
            T(1.0),
            true,
            (
                tcm=[-Inf, +Inf],
                tmin=[-Inf, T(0.0)],
                gdd5=[T(550), +Inf],
                gdd0=[-Inf, +Inf],
                twm=[-Inf, +Inf],
                maxdepth=[-Inf, +Inf],
                swb=[-Inf,+Inf]
            ),
            (clt=T(16.6), prec=T(12.2), temp=T(21.3)), 
            (clt=T(6.9), prec=T(13.4), temp=T(6.2)),
            U(5)
        )
    )
end

C3C4TemperateGrass() = C3C4TemperateGrass{Float64,Int}()

# 10) C4TropicalGrass
struct C4TropicalGrass{T<:Real,U<:Int} <: AbstractPFT
    characteristics::PFTCharacteristics{T,U}
end

function C4TropicalGrass{T,U}() where {T<:Real,U<:Int}
    return C4TropicalGrass{T,U}(
        PFTCharacteristics{T,U}(
            "C4TropicalGrass",
            U(3),
            T(0.8),
            T(8.0),
            T(0.2),
            T(0.3),
            T(0.57),
            T(10.0),
            T(-99.9),
            T(-99.9),
            U(2),
            T(0.65),
            T(0.4),
            true,
            T(0.40),
            T(10.0), # t0
            T(1.0), # tcurve
            T(0.8), # respfact
            T(1.0), # allocfact
            true,
            (
                tcm=[-Inf, +Inf],
                tmin=[T(-3.0), +Inf],
                gdd5=[-Inf, +Inf],
                gdd0=[-Inf, +Inf],
                twm=[T(10.0), +Inf],
                maxdepth=[-Inf, +Inf],
                swb=[T(200),+Inf]
            ),
            (clt=T(16.6), prec=T(12.2), temp=T(21.3)),
            (clt=T(6.9), prec=T(13.4), temp=T(6.2)),
            U(5)
        )
    )
end

C4TropicalGrass() = C4TropicalGrass{Float64,Int}()

# 11) TundraShrubs
struct TundraShrubs{T<:Real,U<:Int} <: AbstractPFT
    characteristics::PFTCharacteristics{T,U}
end

function TundraShrubs{T,U}() where {T<:Real,U<:Int}
    return TundraShrubs{T,U}(
        PFTCharacteristics{T,U}(
            "TundraShrubs",
            U(1),
            T(0.8),
            T(1.0),
            T(-99.9),
            T(-99.9),
            T(0.93),
            T(8.0),
            T(-99.9),
            T(-99.9),
            U(1),
            T(0.9),
            T(0.5),
            false,
            T(0.33),
            T(-7.0),
            T(0.6),
            T(4.0),
            T(1.0),
            true,
            (
                tcm=[-Inf, +Inf],
                tmin=[-Inf, +Inf],
                gdd5=[-Inf, +Inf],
                gdd0=[T(50.0), +Inf],
                twm=[-Inf, T(15.0)],
                maxdepth=[T(15.0), +Inf],
                swb=[T(150),+Inf]
            ),
            (clt=T(51.4), prec=T(50.0), temp=T(-10.8)), 
            (clt=T(9.0), prec=T(43.3), temp=T(5.1)),
            U(6)
        )
    )
end

TundraShrubs() = TundraShrubs{Float64,Int}()

# 12) ColdHerbaceous
struct ColdHerbaceous{T<:Real,U<:Int} <: AbstractPFT
    characteristics::PFTCharacteristics{T,U}
end

function ColdHerbaceous{T,U}() where {T<:Real,U<:Int}
    return ColdHerbaceous{T,U}(
        PFTCharacteristics{T,U}(
            "ColdHerbaceous",
            U(2),
            T(0.8),
            T(1.0),
            T(-99.9),
            T(-99.9),
            T(0.93),
            T(8.0),
            T(-99.9),
            T(25.0),
            U(2),
            T(0.75),
            T(0.3),
            false,
            T(0.33),
            T(-7.0),
            T(0.6),
            T(4.0),
            T(1.0),
            true,
            (
                tcm=[-Inf, +Inf],
                tmin=[-Inf, +Inf],
                gdd5=[-Inf, +Inf],
                gdd0=[T(50.0), +Inf],
                twm=[-Inf, T(15.0)],
                maxdepth=[-Inf, +Inf],
                swb=[T(150),+Inf]
            ),
            (clt=T(10.4), prec=T(2.0), temp=T(23.5)), 
            (clt=T(2.5), prec=T(1.6), temp=T(2.3)),
            U(8)
        )
    )
end

ColdHerbaceous() = ColdHerbaceous{Float64,Int}()

# 13) LichenForb
struct LichenForb{T<:Real,U<:Int} <: AbstractPFT
    characteristics::PFTCharacteristics{T,U}
end

function LichenForb{T,U}() where {T<:Real,U<:Int}
    return LichenForb{T,U}(
        PFTCharacteristics{T,U}(
            "LichenForb",
            U(1),
            T(0.8),
            T(1.0),
            T(-99.9),
            T(-99.9),
            T(0.93),
            T(8.0),
            T(-99.9),
            T(-99.9),
            U(1),
            T(0.8),
            T(0.6),
            false,
            T(0.33),
            T(-12.0),
            T(0.5),
            T(4.0),
            T(1.5),
            false,
            (
                tcm=[-Inf, +Inf],
                tmin=[-Inf, +Inf],
                gdd5=[-Inf, +Inf],
                gdd0=[-Inf, +Inf],
                twm=[-Inf, T(15.0)],
                maxdepth=[-Inf, +Inf],
                swb= [-Inf,+Inf]
            ),
            (clt=T(10.4), prec=T(2.7), temp=T(23.6)),
            (clt=T(3.1), prec=T(3.1), temp=T(3.1)),
            U(8)
        )
    )
end

LichenForb() = LichenForb{Float64,Int}()

# 14) Default

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

struct CoolMixedForest <: AbstractBiome
    value::Int
    CoolMixedForest() = new(7)
end

struct CoolConiferForest <: AbstractBiome
    value::Int
    CoolConiferForest() = new(8)
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
    assign_biome

Assign biomes as in BIOME3.5 according to a new scheme of biomes.

As per the logic of Jed Kaplan 3/1998
"""

"""
    assign_biome(optpft::LichenForb, subpft, wdom, gdd0, gdd5, tcm, tmin, pftlist)

Assign biome for LichenForb plant functional type.

Returns Barren biome as LichenForb typically occurs in harsh environments.
"""
function assign_biome(
    optpft::LichenForb;
    kwargs...
)::AbstractBiome
    return CushionForbsLichenMoss()
end

"""
    assign_biome(optpft::TundraShrubs, subpft, wdom, gdd0, gdd5, tcm, tmin, pftlist)

Assign biome for TundraShrubs plant functional type.

Uses growing degree days above 0°C to determine tundra biome type.
"""
function assign_biome(
    optpft::TundraShrubs;
    gdd0::T,
    kwargs... 
)::AbstractBiome where {T<:Real}
    if gdd0 < 200.0
        return ProstateShrubTundra()
    elseif gdd0 < 500.0
        return DwarfShrubTundra()
    else
        return ShrubTundra()
    end
end

"""
    assign_biome(optpft::ColdHerbaceous, subpft, wdom, gdd0, gdd5, tcm, tmin, pftlist)

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
    assign_biome(optpft::BorealEvergreen, subpft, wdom, gdd0, gdd5, tcm, tmin, pftlist)

Assign biome for BorealEvergreen plant functional type.

Uses GDD5 and coldest month temperature to determine forest type.
"""
function assign_biome(
    optpft::BorealEvergreen;
    gdd5::T, 
    tcm::T,  
    pftlist::AbstractPFTList,
    pftstates::Dict{AbstractPFT,PFTState},
    kwargs... 
)::AbstractBiome where {T<:Real}
    temperate_deciduous_idx = findfirst(
        pft -> get_characteristic(pft, :name) == "TemperateDeciduous", 
        pftlist.pft_list
    )
    temp_dec_pft = pftlist.pft_list[temperate_deciduous_idx]
    if gdd5 > 900.0 && tcm > -19.0
        if temperate_deciduous_idx !== nothing && 
           pftstates[temp_dec_pft].present
            return CoolMixedForest()
        else
            return CoolConiferForest()
        end
    else
        if temperate_deciduous_idx !== nothing &&  pftstates[temp_dec_pft].present
            return ColdMixedForest()
        else
            return EvergreenTaigaMontaneForest()
        end
    end
end

"""
    assign_biome(optpft::BorealDeciduous, subpft, wdom, gdd0, gdd5, tcm, tmin, pftlist)

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
        return ColdMixedForest()
    elseif gdd5 > 900.0 && tcm > -19.0
        return ColdMixedForest()
    else
        return DeciduousTaigaMontaneForest()
    end
end

"""
    assign_biome(optpft::WoodyDesert, subpft, wdom, gdd0, gdd5, tcm, tmin, pftlist)

Assign biome for WoodyDesert plant functional type.

Uses NPP and LAI to determine desert or shrubland biome type.
"""
function assign_biome(
    optpft::WoodyDesert;
    subpft::AbstractPFT,
    tmin::T,
    pftstates::Dict{AbstractPFT,PFTState},
    gdom::AbstractPFT,
    kwargs... 
)::AbstractBiome where {T<:Real}
    if pftstates[optpft].npp > 100.0
        if pftstates[gdom].lai > 1.0
            return tmin >= 0.0 ? TropicalXerophyticShrubland() : 
                   TemperateXerophyticShrubland()
        else
            return Desert()
        end
    else
        return Desert()
    end
end

"""
    assign_biome(optpft::C3C4TemperateGrass, subpft, wdom, gdd0, gdd5, tcm, tmin, pftlist)

Assign biome for C3C4TemperateGrass plant functional type.

Uses NPP and GDD0 to determine grassland or tundra biome type.
"""
function assign_biome(
    optpft::C3C4TemperateGrass;
    subpft::AbstractPFT, 
    gdd0::T,
    pftstates::Dict{AbstractPFT,PFTState},
    kwargs... 
)::AbstractBiome where {T<:Real}
    if pftstates[optpft].npp <= 100.0
        if subpft !== Default && 
           !(isa(subpft, BorealEvergreen) || !isa(subpft, BorealDeciduous))
            return Desert()
        else
            return SteppeTundra()
        end
    elseif gdd0 >= 800.0
        return TemperateGrassland()
    else
        return SteppeTundra()
    end
end

"""
    assign_biome(optpft::TemperateBroadleavedEvergreen, subpft, wdom, gdd0, gdd5, tcm, tmin, pftlist)

Assign biome for TemperateBroadleavedEvergreen plant functional type.

Uses NPP to determine if mixed forest or desert biome is appropriate.
"""
function assign_biome(
    optpft::TemperateBroadleavedEvergreen;
    pftstates::Dict{AbstractPFT,PFTState},
    kwargs... 
)::AbstractBiome
    if pftstates[optpft].npp > 100.0
        return WarmMixedForest()
    else
        return Desert()
    end
end

"""
    assign_biome(optpft::TemperateDeciduous, subpft, wdom, gdd0, gdd5, tcm, tmin, pftlist)

Assign biome for TemperateDeciduous plant functional type.

Complex logic considering co-occurring PFTs and climate conditions.
"""
function assign_biome(
    optpft::TemperateDeciduous;
    gdd5::T, 
    tcm::T, 
    pftlist::AbstractPFTList,
    pftstates::Dict{AbstractPFT,PFTState},
    kwargs... 
)::AbstractBiome where {T<:Real}
    if pftstates[optpft].npp > 100.0
        boreal_evergreen_idx = findfirst(
            pft -> get_characteristic(pft, :name) == "BorealEvergreen", 
            pftlist.pft_list
        )
        boreal_evergreen_pft = pftlist.pft_list[boreal_evergreen_idx]

        temperate_broadleaved_evergreen_idx = findfirst(
            pft -> get_characteristic(pft, :name) == "TemperateBroadleavedEvergreen", 
            pftlist.pft_list
        )
        temperate_broadleaved_evergreen_pft = pftlist.pft_list[temperate_broadleaved_evergreen_idx]
        cool_conifer_idx = findfirst(
            pft -> get_characteristic(pft, :name) == "CoolConifer", 
            pftlist.pft_list
        )
        cool_conifer_pft = pftlist.pft_list[cool_conifer_idx]

        if pftstates[boreal_evergreen_pft].present
            if tcm < -15.0
                return ColdMixedForest()
            else
                return CoolMixedForest()
            end
        elseif pftstates[temperate_broadleaved_evergreen_pft].present || (pftstates[cool_conifer_pft].present && gdd5 > 3000.0 && tcm > 3.0)
            return WarmMixedForest()
        else
            return TemperateDeciduousForest()
        end
    else
        return Desert()
    end
end

"""
    assign_biome(optpft::CoolConifer, subpft, wdom, gdd0, gdd5, tcm, tmin, pftlist)

Assign biome for CoolConifer plant functional type.

Determines conifer forest type based on co-occurring PFTs.
"""
function assign_biome(
    optpft::CoolConifer; 
    subpft::AbstractPFT,
    pftlist::AbstractPFTList,
    pftstates::Dict{AbstractPFT,PFTState},
    kwargs... 
)::AbstractBiome
    if pftstates[optpft].npp > 100.0
        temperate_broadleaved_evergreen_idx = findfirst(
            pft -> get_characteristic(pft, :name) == "TemperateBroadleavedEvergreen", 
            pftlist.pft_list
        )
        temperate_broadleaved_evergreen_idx !== nothing
        temperate_broadleaved_evergreen_pft = pftlist.pft_list[temperate_broadleaved_evergreen_idx]
        if pftstates[temperate_broadleaved_evergreen_pft].present
            return WarmMixedForest()
        elseif subpft !== nothing && isa(subpft, TemperateDeciduous) && (pftstates[optpft].npp - pftstates[subpft].npp) < 50.0
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
    assign_biome(optpft::TropicalEvergreen, subpft, wdom, gdd0, gdd5, tcm, tmin, pftlist)

Assign biome for TropicalEvergreen plant functional type.

Returns tropical evergreen forest if NPP is sufficient, otherwise desert.
"""
function assign_biome(
    optpft::TropicalEvergreen;
    pftstates::Dict{AbstractPFT,PFTState},
    kwargs... 
)::AbstractBiome
    if pftstates[optpft].npp > 100.0
        return TropicalEvergreenForest()
    else
        return Desert()
    end
end

"""
    assign_biome(optpft::TropicalDroughtDeciduous, subpft, wdom, gdd0, gdd5, tcm, tmin, pftlist)

Assign biome for TropicalDroughtDeciduous plant functional type.

Uses NPP and green days to determine tropical forest type.
"""
function assign_biome(
    optpft::TropicalDroughtDeciduous;
    pftstates::Dict{AbstractPFT,PFTState},
    kwargs... 
)::AbstractBiome
    if pftstates[optpft].npp > 100.0
        if pftstates[optpft].greendays > 300
            return TropicalEvergreenForest()
        elseif pftstates[optpft].greendays > 250
            return TropicalSemiDeciduousForest()
        else
            return TropicalDeciduousForestWoodland()
        end
    else 
        return Desert()
    end
end

"""
    assign_biome(optpft::C4TropicalGrass, subpft, wdom, gdd0, gdd5, tcm, tmin, pftlist)

Assign biome for C4TropicalGrass plant functional type.

Returns tropical grassland if NPP is sufficient, otherwise desert.
"""
function assign_biome(
    optpft::C4TropicalGrass;
    pftstates::Dict{AbstractPFT,PFTState},
    kwargs... 
)::AbstractBiome
    if pftstates[optpft].npp > 100.0
        return TropicalGrassland()
    else
        return Desert()
    end
end

"""
    assign_biome(optpft::Default, subpft, wdom, gdd0, gdd5, tcm, tmin, pftlist)

Assign biome for Default plant functional type.

Uses woody dominant PFT to determine appropriate biome type.
"""
function assign_biome(
    optpft::Default;
    wdom::AbstractPFT, 
    pftstates::Dict{AbstractPFT,PFTState},
    kwargs... 
)::AbstractBiome
    if wdom === nothing || isa(wdom, TropicalEvergreen) || isa(wdom, TropicalDroughtDeciduous)
        if wdom !== nothing && pftstates[wdom].lai > 4.0
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
    assign_biome(optpft::None, subpft, wdom, gdd0, gdd5, tcm, tmin, pftlist)

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