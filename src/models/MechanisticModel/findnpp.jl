"""Find NPP subroutine."""
# Third-party
using LinearAlgebra
using ComponentArrays: ComponentArray

# First-party
include("growth.jl")
export growth

function findnpp(
    pft::U,
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
    optdata,
    dphen::AbstractArray{T},
    co2::AbstractFloat,
    p::AbstractFloat,
    tsoil::AbstractArray{T,1},
    realout::AbstractArray{T,2}
) where {T <: Real, U <: Int}
    """Run NPP optimization model for one pft"""

    # Initialize variables
    realin = zeros(U, 200)
    inv = Union{T, U}[zero(T) for _ in 1:500] # FIXME this is so ugly
    realin = Union{T, U}[zero(T) for _ in 1:200]
    optnpp = 0
    optlai = 0
    mnpp = zeros(T, 12)
    c4mnpp = zeros(T, 12)

    # Calculate NPP at a range of different leaf areas by iteration
    lowbound = T(0.01)
    range_val = T(8.0)
    alai = zeros(T, 2)

    for _ in 1:8

        alai[1] = lowbound + (1.0 / 4.0) * range_val
        alai[2] = lowbound + (3.0 / 4.0) * range_val

        npp, inv, realin, mnpp, c4mnpp = growth(
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
            inv,
            dphen,
            co2,
            p,
            tsoil,
            realin,
            mnpp,
            c4mnpp
        )

        if npp >= optnpp
            optlai = alai[1]
            optnpp = npp
            optdata[1:500] = inv[1:500]
            # realout[pft+1, 1:200] = realin[1:200]
        end

        npp, inv, realin, mnpp, c4mnpp = growth(
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
            inv,
            dphen,
            co2,
            p,
            tsoil,
            realin,
            mnpp,
            c4mnpp
        )

        # Find the leaf area which gives the highest NPP
        if npp >= optnpp
            optlai = alai[2]
            optnpp = npp
            optdata[1:500] = inv[1:500]
            # realout[pft+1, 1:200] = realin[1:200]
        end

        range_val /= T(2.0)
        lowbound = optlai - range_val / T(2.0)
        if lowbound <= 0.0
            lowbound = T(0.01)
        end
    end
    
    return optdata, optlai, optnpp, realout
end
