using Distributions
using Parameters: @kwdef

@kwdef mutable struct PFTCharacteristics{T<:Real,U<:Int} <: AbstractPFTCharacteristics
    name::String = "Default"
    phenological_type::U = U(1)
    max_min_canopy_conductance::T = T(0.0)
    Emax::T = T(0.0)
    sw_drop::T = T(0.0)
    sw_appear::T = T(0.0)
    root_fraction_top_soil::T = T(0.0)
    leaf_longevity::T = T(0.0)
    GDD5_full_leaf_out::T = T(0.0)
    GDD0_full_leaf_out::T = T(0.0)
    sapwood_respiration::U = U(1)
    optratioa::T = T(0.0)
    kk::T = T(0.0)
    c4::Bool = false
    threshold::T = T(0.0)
    t0::T = T(0.0)
    tcurve::T = T(0.0)
    respfact::T = T(0.0)
    allocfact::T = T(0.0)
    grass::Bool = false

    # Corrected NamedTuple defaults using the semicolon syntax
    constraints::NamedTuple{
        (:tcm, :min, :gdd, :gdd0, :twm, :snow, :swb),
        NTuple{7,Vector{T}}
    } = (; 
        tcm   = [-Inf, +Inf],
        min   = [-Inf, +Inf],
        gdd   = [-Inf, +Inf],
        gdd0  = [-Inf, +Inf],
        twm   = [-Inf, +Inf],
        snow  = [-Inf, +Inf],
        swb = [-Inf, +Inf]
    )

    mean_val::NamedTuple{
        (:clt, :prec, :temp),
        NTuple{3,T}
    } = (; 
        clt   = T(0.0),
        prec  = T(0.0),
        temp  = T(0.0)
    )

    sd_val::NamedTuple{
        (:clt, :prec, :temp),
        NTuple{3,T}
    } = (; 
        clt   = T(1.0),
        prec  = T(1.0),
        temp  = T(1.0)
    )
end

# Shorthand: default to Float64 and Int
PFTCharacteristics() = PFTCharacteristics{Float64,Int}()

@kwdef mutable struct PFTState{T<:Real,U<:Int}
    present::Bool = false
    dominance::T = zero(T)
    greendays::U = zero(U)
    firedays::T = zero(T)
    mwet::Vector{T} = zeros(T, 12)
    npp::T = zero(T)
    lai::T = zero(T)
end

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
                tcm   = [ -Inf, +Inf ],
                min   = [ T(-45.0), +Inf ],
                gdd   = [ T(500), +Inf ],
                gdd0  = [ -Inf, +Inf ],
                twm   = [ T(10.0), +Inf ],
                snow  = [ -Inf, +Inf ],
                swb   = [ -Inf, 500 ]
            ),
            (
                clt   = T(9.2),
                prec  = T(2.5),
                temp  = T(23.9)
            ),
            (
                clt   = T(2.2),
                prec  = T(2.8),
                temp  = T(2.7)
            )
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
                tcm   = [ -Inf, +Inf ],
                min   = [ T(0.0), +Inf ],
                gdd   = [ -Inf, +Inf ],
                gdd0  = [ -Inf, +Inf ],
                twm   = [ T(10.0), +Inf ],
                snow  = [ -Inf, +Inf ],
                swb   = [ 700, +Inf ]
            ),
            (
                clt   = T(50.2),
                prec  = T(169.6),
                temp  = T(24.7)
            ),
            (
                clt   = T(4.9),
                prec  = T(41.9),
                temp  = T(1.2)
            )
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
                tcm   = [ -Inf, +Inf ],
                min   = [ T(0.0), +Inf ],
                gdd   = [ -Inf, +Inf ],
                gdd0  = [ -Inf, +Inf ],
                twm   = [ T(10.0), +Inf ],
                snow  = [ -Inf, +Inf ],
                swb   = [ 500, +Inf ]
            ),
            (
                clt   = T(44.0),
                prec  = T(163.3),
                temp  = T(23.7)
            ),
            (
                clt   = T(12.9),
                prec  = T(81.5),
                temp  = T(2.3)
            )
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
                tcm   = [ -Inf, +Inf ],
                min   = [ T(-8.0), T(5.0) ],
                gdd   = [ T(1200), +Inf ],
                gdd0  = [ -Inf, +Inf ],
                twm   = [ T(10.0), +Inf ],
                snow  = [ -Inf, +Inf ],
                swb   = [ 400, +Inf ]
            ),
            (
                clt   = T(33.4),
                prec  = T(106.3),
                temp  = T(18.7)
            ),
            (
                clt   = T(13.3),
                prec  = T(83.6),
                temp  = T(3.2)
            )
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
                tcm   = [ T(-15.0), +Inf ],
                min   = [ -Inf, T(-8.0) ],
                gdd   = [ T(1200), +Inf ],
                gdd0  = [ -Inf, +Inf ],
                twm   = [ -Inf, +Inf ],
                snow  = [ -Inf, +Inf ],
                swb   = [ 200, +Inf ]
            ),
            (
                clt   = T(40.9),
                prec  = T(70.2),
                temp  = T(8.4)
            ),
            (
                clt   = T(8.6),
                prec  = T(41.9),
                temp  = T(4.7)
            )
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
                tcm   = [ T(-2.0), +Inf ],
                min   = [ -Inf, T(10.0) ],
                gdd   = [ T(900), +Inf ],
                gdd0  = [ -Inf, +Inf ],
                twm   = [ T(10.0), +Inf ],
                snow  = [ -Inf, +Inf ],
                swb   = [ 500, +Inf ]
            ),
            (
                clt   = T(28.1),
                prec  = T(54.5),
                temp  = T(13.9)
            ),
            (
                clt   = T(8.6),
                prec  = T(49.9),
                temp  = T(3.4)
            )
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
                tcm   = [ T(-32.5), T(-2.0) ],
                min   = [ -Inf, +Inf ],
                gdd   = [ -Inf, +Inf ],
                gdd0  = [ -Inf, +Inf ],
                twm   = [ -Inf, T(21.0) ],
                snow  = [ -Inf, +Inf ],
                swb   = [ -Inf, +Inf ]
            ),
            (
                clt   = T(48.1),
                prec  = T(58.7),
                temp  = T(-2.7)
            ),
            (
                clt   = T(7.6),
                prec  = T(35.7),
                temp  = T(4.0)
            )
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
                tcm   = [ -Inf, T(5.0) ],
                min   = [ -Inf, T(-10.0) ],
                gdd   = [ -Inf, +Inf ],
                gdd0  = [ -Inf, +Inf ],
                twm   = [ -Inf, T(21.0) ],
                snow  = [ -Inf, +Inf ],
                swb   = [ 300, +Inf ]
            ),
            (
                clt   = T(47.4),
                prec  = T(65.0),
                temp  = T(-6.4)
            ),
            (
                clt   = T(8.3),
                prec  = T(83.6),
                temp  = T(7.7)
            )
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
                tcm   = [ -Inf, +Inf ],
                min   = [ -Inf, T(0.0) ],
                gdd   = [ T(550), +Inf ],
                gdd0  = [ -Inf, +Inf ],
                twm   = [ -Inf, +Inf ],
                snow  = [ -Inf, +Inf ],
                swb   = [ -Inf, +Inf ]
            ),
            (
                clt   = T(16.6),
                prec  = T(12.2),
                temp  = T(21.3)
            ),
            (
                clt   = T(6.9),
                prec  = T(13.4),
                temp  = T(6.2)
            )
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
            T(10.0),
            T(1.0),
            T(0.8),
            T(1.0),
            true,
            (
                tcm   = [ -Inf, +Inf ],
                min   = [ T(-3.0), +Inf ],
                gdd   = [ -Inf, +Inf ],
                gdd0  = [ -Inf, +Inf ],
                twm   = [ T(10.0), +Inf ],
                snow  = [ -Inf, +Inf ],
                swb   = [ T(200), +Inf ]
            ),
            (
                clt   = T(9.4),
                prec  = T(1.7),
                temp  = T(23.2)
            ),
            (
                clt   = T(1.4),
                prec  = T(2.1),
                temp  = T(2.2)
            )
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
                tcm   = [ -Inf, +Inf ],
                min   = [ -Inf, +Inf ],
                gdd   = [ -Inf, +Inf ],
                gdd0  = [ T(50.0), +Inf ],
                twm   = [ -Inf, T(15.0) ],
                snow  = [ T(15.0), +Inf ],
                swb   = [ T(250),  +Inf ]
            ),
            (
                clt   = T(9.2),
                prec  = T(2.5),
                temp  = T(23.9)
            ),
            (
                clt   = T(2.2),
                prec  = T(2.8),
                temp  = T(2.7)
            )
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
                tcm   = [ -Inf, +Inf ],
                min   = [ -Inf, +Inf ],
                gdd   = [ -Inf, +Inf ],
                gdd0  = [ T(50.0), +Inf ],
                twm   = [ -Inf, T(15.0) ],
                snow  = [ -Inf, +Inf ],
                swb   = [ T(300),  +Inf ]
            ),
            (
                clt   = T(10.4),
                prec  = T(2.0),
                temp  = T(23.5)
            ),
            (
                clt   = T(2.5),
                prec  = T(1.6),
                temp  = T(2.3)
            )
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
                tcm   = [ -Inf, +Inf ],
                min   = [ -Inf, +Inf ],
                gdd   = [ -Inf, +Inf ],
                gdd0  = [ -Inf, +Inf ],
                twm   = [ -Inf, T(15.0) ],
                snow  = [ -Inf, +Inf ], 
                swb   = [ -Inf, +Inf ]
            ),
            (
                clt   = T(43.9),
                prec  = T(53.3),
                temp  = T(-18.4)
            ),
            (
                clt   = T(9.0),
                prec  = T(52.1),
                temp  = T(4.1)
            )
        )
    )
end

LichenForb() = LichenForb{Float64,Int}()

# 14) Default
struct Default{T<:Real,U<:Int} <: AbstractPFT
    characteristics::PFTCharacteristics{T,U}
end
Default{T,U}() where {T<:Real,U<:Int} = Default{T,U}(PFTCharacteristics{T,U}())
Default() = Default{Float64,Int}()

# 15) NonePFT
struct None{T<:Real,U<:Int} <: AbstractPFT
    characteristics::PFTCharacteristics{T,U}
end
None{T,U}() where {T<:Real,U<:Int} = None{T,U}(PFTCharacteristics{T,U}())
None() = None{Float64,Int}()

struct PFTClassification{T<:Real,U<:Int} <: AbstractPFTList
    pft_list::Vector{AbstractPFT}
end

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

function get_characteristic(pft::AbstractPFT, prop::Symbol)
    if hasproperty(pft.characteristics, prop)
        return getproperty(pft.characteristics, prop)
    else
        throw(ArgumentError("`$(prop)` is not a field of PFTCharacteristics"))
    end
end

"""
    dominance_environment(pft, variable, clt)

Calculate the normalized environmental dominance value for a given climate trait.

Returns a value in [0,1], where 1 is at the species' optimal mean and values fall off according to its tolerance.
"""
function dominance_environment(pft::AbstractPFT, variable::Symbol, clt)
    mean_val = get_characteristic(pft, :mean_val)[variable]
    std_val  = get_characteristic(pft, :sd_val)[variable]
    dist     = Normal(mean_val, std_val)
    pdf_clt  = pdf(dist, clt)
    pdf_mean = pdf(dist, mean_val)
    return pdf_clt / pdf_mean
end
