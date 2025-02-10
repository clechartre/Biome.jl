"""Find NPP subroutine."""
module FindNPP

# Third-party
using LinearAlgebra
using ComponentArrays: ComponentArray

# First-party
include("growth.jl")
using .Growth

function findnpp(
    pfts::Vector{U},
    pft::U,
    annp::T,
    dtemp::Array{T,1},
    sun::Array{T,1},
    temp::Array{T,1},
    dprec::Array{T,1},
    dmelt::Array{T,1},
    dpet::Array{T,1},
    dayl::Array{T,1},
    k::AbstractArray,
    pftpar::AbstractArray,
    optdata,
    dphen::AbstractArray{T},
    co2::AbstractFloat,
    p::AbstractFloat,
    tsoil::Array{T,1},
    realout::Array{T,2},
    numofpfts::U,
    pft_dict::ComponentArray
) where {T <: Real, U <: Int}
    """Run NPP optimization model for one pft"""

    # Initialize variables
    realin = zeros(U, 200)
    inv = Union{T, U}[zero(T) for _ in 1:500]
    realin = Union{T, U}[zero(T) for _ in 1:200]
    optnpp = 0
    optlai = 0
    mnpp = zeros(T, 12)
    c4mnpp = zeros(T, 12)

    # If pft is not equal to 1, this is a dummy call of subroutine
    # return zero values
    if pfts[pft] != 1
        return optdata, optlai, optnpp, realout
    end

    # Calculate NPP at a range of different leaf areas by iteration
    lowbound = T(0.01)
    range_val = T(8.0)
    alai = zeros(T, 2)

    for _ in 1:8

        alai[1] = lowbound + (1.0 / 4.0) * range_val
        alai[2] = lowbound + (3.0 / 4.0) * range_val

        # # println("PFT", pft)

        growth_results = Growth.growth(
            alai[1],
            annp,
            sun, # wst in fortran
            temp,
            dprec,
            dmelt,
            dpet,
            k,
            pftpar,
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
            c4mnpp,
            pft_dict
        )
        npp = growth_results.npp
        inv = growth_results.outv
        realin = growth_results.realin
        mnpp = growth_results.mnpp
        c4mnpp = growth_results.c4mnpp

        if npp >= optnpp
            optlai = alai[1]
            optnpp = npp
            optdata[1:500] = inv[1:500]
            # realout[pft+1, 1:200] = realin[1:200]
        end

        growth_results = Growth.growth(
            alai[2],
            annp,
            sun,
            temp,
            dprec,
            dmelt,
            dpet,
            k,
            pftpar,
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
            c4mnpp,
            pft_dict
        )
        npp = growth_results.npp
        inv = growth_results.outv
        realin = growth_results.realin
        mnpp = growth_results.mnpp
        c4mnpp = growth_results.c4mnpp
        
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

end # module