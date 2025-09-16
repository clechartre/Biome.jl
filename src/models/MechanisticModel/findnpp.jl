"""
Net Primary Productivity (NPP) optimization subroutine.

This module contains functions for finding optimal NPP values for plant 
functional types through iterative optimization of leaf area index.
"""

# Third-party
using LinearAlgebra

# First-party
include("growth.jl")
export growth

"""
    findnpp(pft, annp, dtemp, sun, temp, dprec, dmelt, dpet, dayl, k, dphen, co2, p, tsoil)

Find optimal Net Primary Productivity (NPP) for a plant functional type.

This function runs an NPP optimization model for one PFT by iteratively testing
different leaf area index (LAI) values to find the combination that maximizes
NPP. Uses a binary search approach to converge on the optimal LAI.

# Arguments
- `pft`: Plant Functional Type to optimize
- `annp`: Annual precipitation (mm)
- `dtemp`: Daily temperature array (365 elements, °C)
- `sun`: Monthly solar radiation array (12 elements, MJ/m²/day)
- `temp`: Monthly temperature array (12 elements, °C)
- `dprec`: Daily precipitation array (365 elements, mm)
- `dmelt`: Daily snowmelt array (365 elements, mm)
- `dpet`: Daily potential evapotranspiration array (365 elements, mm)
- `dayl`: Monthly day length array (12 elements, hours)
- `k`: Soil and canopy parameter array
- `dphen`: Daily phenology array (365x2 matrix)
- `co2`: Atmospheric CO2 concentration (ppm)
- `p`: Atmospheric pressure (kPa)
- `tsoil`: Monthly soil temperature array (12 elements, °C)

# Returns
A tuple containing:
- `pft`: The input plant functional type (potentially modified)
- `optlai`: Optimal leaf area index that maximizes NPP
- `optnpp`: Maximum net primary productivity achieved (gC/m²/year)

# Notes
- Returns (pft, 0.0, 0.0) if the PFT is not present in the current conditions
- Uses 8 iterations of binary search to converge on optimal LAI
- Tests LAI values between 0.01 and 8.0
- Calls the growth() function to calculate NPP for each LAI value
"""
function findnpp(
    pft::AbstractPFT,
    annp::T,
    dtemp::AbstractVector{T},
    sun::AbstractVector{T},
    temp::AbstractVector{T},
    dprec::AbstractVector{T},
    dmelt::AbstractVector{T},
    dpet::AbstractVector{T},
    dayl::AbstractVector{T},
    k::AbstractArray{T},
    dphen::AbstractArray{T},
    co2::T,
    p::T,
    tsoil::AbstractVector{T},
    pftstates::PFTState
)::Tuple{AbstractPFT,T,T,PFTState} where {T<:Real}
    # Initialize variables
    optnpp = T(0.0)
    optlai = T(0.0)
    mnpp = zeros(T, 12)
    c4mnpp = zeros(T, 12)

    # Calculate NPP at a range of different leaf areas by iteration
    lowbound = T(0.01)
    range_val = T(8.0)
    alai = zeros(T, 2)

    if pftstates.present == false
        return pft, T(0.0), T(0.0)
    end

    # Binary search optimization over 8 iterations
    for _ in 1:8
        # Test two LAI values in the current range
        alai[1] = lowbound + T(0.25) * range_val
        alai[2] = lowbound + T(0.75) * range_val

        # Test first LAI value
        npp, mnpp, c4mnpp, pftstates = growth(
            alai[1],
            annp,
            sun,
            temp,
            dprec,
            dmelt,
            dpet,
            k,
            pft,
            dayl,
            dtemp,
            dphen,
            co2,
            p,
            tsoil,
            mnpp,
            c4mnpp,
            pftstates
        )

        if npp >= optnpp
            optlai = alai[1]
            optnpp = npp
        end

        # Test second LAI value
        npp, mnpp, c4mnpp, pftstates = growth(
            alai[2],
            annp,
            sun,
            temp,
            dprec,
            dmelt,
            dpet,
            k,
            pft,
            dayl,
            dtemp,
            dphen,
            co2,
            p,
            tsoil,
            mnpp,
            c4mnpp,
            pftstates
        )

        if npp >= optnpp
            optlai = alai[2]
            optnpp = npp
        end

        # Narrow the search range for next iteration
        range_val /= T(2.0)
        lowbound = optlai - range_val / T(2.0)
        if lowbound <= T(0.0)
            lowbound = T(0.01)
        end
    end
    
    return pft, optlai, optnpp, pftstates
end