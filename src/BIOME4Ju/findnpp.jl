"""Find NPP subroutine."""
module FindNPP

# Third-party
using LinearAlgebra

# First-party
include("growth.jl")
using .Growth

function findnpp(
    pfts::Vector{Int},
    pft::Int,
    optlai::Float64,
    optnpp::Float64,
    annp::Float64,
    dtemp::Array{Float64,1},
    sun::Array{Float64,1},
    temp::Array{Float64,1},
    dprec::Array{Float64,1},
    dmelt::Array{Float64,1},
    dpet::Array{Float64,1},
    dayl::Array{Float64,1},
    k::AbstractArray,
    pftpar::AbstractArray{Float64, 2},
    optdata::AbstractArray{},
    dphen::AbstractArray{Float64},
    co2::AbstractFloat,
    p::AbstractFloat,
    tsoil::Array{Float64,1},
    realout::Array{Float64,2},
    numofpfts::Real,
) :: Tuple{Array{Float64,2}, Float64, Float64, Array{Float64,2}}
    """Run NPP optimization model for one pft"""

    # Initialize variables
    inv = zeros(Int, 500)
    realin = zeros(Int, 500)

    # If pft is not equal to 1, this is a dummy call of subroutine
    # return zero values
    if pfts[pft] != 1
        return optdata, optlai, optnpp, realout
    end

    # Calculate NPP at a range of different leaf areas by iteration
    lowbound = 0.01
    range_val = 8.0

    for iterate in 1:8
        alai = zeros(Float64, 2)
        alai[1] = lowbound + (1.0 / 4.0) * range_val
        alai[2] = lowbound + (3.0 / 4.0) * range_val

        growth_results = Growth.growth(
            alai[1],
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
        )
        npp, inv, realin = growth_results.npp, growth_results.outv, growth_results.realin

        if npp >= optnpp
            optlai = alai[1]
            optnpp = npp
            optdata[pft+1, 1:500] = inv[1:500]
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
        )
        npp, inv, realin = growth_results.npp, growth_results.outv, growth_results.realin

        # Find the leaf area which gives the highest NPP
        if npp >= optnpp
            optlai = alai[2]
            optnpp = npp
            optdata[pft+1, 1:500] = inv[1:500]
            realout[pft+1, 1:500] = realin[1:500]
        end

        range_val /= 2.0
        lowbound = optlai - range_val / 2.0
        if lowbound <= 0.0
            lowbound = 0.01
        end
    end
    return optdata, optlai, optnpp, realout
end

end # module