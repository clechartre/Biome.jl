"""Find NPP subroutine."""
# Third-party
using LinearAlgebra

# First-party
include("growth.jl")
export growth

function findnpp(
    pft::U, # FIXME this should be an AbstractPFT and then set_characteristic(BIOME4PFTS.pft_list[pft], :lai, alai[1]) can become set_characteristic(pft, :lai, alai[1])
    annp::T,
    dtemp::AbstractArray{T,1},
    sun::AbstractArray{T,1},
    temp::AbstractArray{T,1},
    dprec::AbstractArray{T,1},
    dmelt::AbstractArray{T,1},
    dpet::AbstractArray{T,1},
    dayl::AbstractArray{T,1},
    k::AbstractArray,
    BIOME4PFTS::AbstractPFTList,
    dphen::AbstractArray{T},
    co2::AbstractFloat,
    p::AbstractFloat,
    tsoil::AbstractArray{T,1}
) where {T <: Real, U <: Int}
    """Run NPP optimization model for one pft"""

    # Initialize variables
    mnpp = zeros(T, 12)
    c4mnpp = zeros(T, 12)

    # Calculate NPP at a range of different leaf areas by iteration
    lowbound = T(0.01)
    range_val = T(8.0)
    alai = zeros(T, 2)

    for _ in 1:8

        alai[1] = lowbound + (1.0 / 4.0) * range_val
        alai[2] = lowbound + (3.0 / 4.0) * range_val

        npp, mnpp, c4mnpp = growth(
            alai[1],
            annp,
            sun, # wst in fortran
            temp,
            dprec,
            dmelt,
            dpet,
            k,
            BIOME4PFTS,
            pft,
            dayl,
            dtemp,
            dphen,
            co2,
            p,
            tsoil,
            mnpp,
            c4mnpp
        )

        if npp >= get_characteristic(BIOME4PFTS.pft_list[pft], :npp)
            set_characteristic(BIOME4PFTS.pft_list[pft], :lai, alai[1])
            set_characteristic(BIOME4PFTS.pft_list[pft], :npp, npp)
        end

        npp, mnpp, c4mnpp = growth(
            alai[2],
            annp,
            sun,
            temp,
            dprec,
            dmelt,
            dpet,
            k,
            BIOME4PFTS,
            pft,
            dayl,
            dtemp,
            dphen,
            co2,
            p,
            tsoil,
            mnpp,
            c4mnpp
        )

        if npp >= get_characteristic(BIOME4PFTS.pft_list[pft], :npp)
            set_characteristic(BIOME4PFTS.pft_list[pft], :lai, alai[1])
            set_characteristic(BIOME4PFTS.pft_list[pft], :npp, npp)
        end

        range_val /= T(2.0)
        lowbound = get_characteristic(BIOME4PFTS.pft_list[pft], :lai) - range_val / T(2.0)
        if lowbound <= 0.0
            lowbound = T(0.01)
        end
    end
    
    return BIOME4PFTS
end
