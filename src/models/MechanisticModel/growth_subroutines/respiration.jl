
"""
respiration(gpp, alresp, temp, sapwood, lai, monthlyfpar, pft, pftdict) -> Tuple{T, T, T, Vector{T}, Vector{T}}

Calculate plant respiration components and net primary productivity (NPP) from gross primary productivity (GPP).

This function computes various respiration costs including stem maintenance, belowground maintenance,
leaf respiration, and growth respiration to determine the net primary productivity of a plant functional type.

# Arguments
- `gpp::T`: Gross primary productivity (carbon gained through photosynthesis)
- `alresp::T`: Autotrophic leaf respiration
- `temp::AbstractArray{T}`: Monthly temperature array (12 elements)
- `sapwood::Int`: sapwood indicator (2 = sapwood, other = woody)
- `lai::T`: Leaf area index
- `monthlyfpar::AbstractArray{T}`: Monthly fraction of photosynthetically active radiation (12 elements)
- `pft::U`: Plant functional type identifier
- `pftdict`: Dictionary containing PFT-specific parameters (allocfact, respfact)

# Returns
A tuple containing:
- `npp::T`: Net primary productivity (-9999.0 if below minimum allocation requirement)
- `stemresp::T`: Total annual stem maintenance respiration
- `percentcost::T`: Respiration costs as percentage of GPP
- `mstemresp::Vector{T}`: Monthly stem maintenance respiration (12 elements)
- `mrootresp::Vector{T}`: Monthly root maintenance respiration (12 elements)
- `backleafresp::Vector{T}`: Monthly leaf maintenance respiration (12 elements, not returned in current implementation)

# Notes
- For sapwood PFTs (sapwood == 2), stem respiration is set to zero
- Temperature-dependent respiration follows exponential relationship with reference temperature of 10°C
- NPP is set to -9999.0 if it falls below the minimum allocation requirement
- Function uses multiple hardcoded constants that should ideally be moved to a constants module
"""
function respiration(
    gpp::T,
    alresp::T,
    temp::AbstractArray{T},
    sapwood::Int,
    lai::T,
    monthlyfpar::AbstractArray{T},
    pft::U,
    pftdict
    )::Tuple{T, T, T, Vector{T}, Vector{T}} where {T <: Real, U <: Int}

    allocfact = pftdict[pft].additional_params.allocfact
    respfact = pftdict[pft].additional_params.respfact

    # Calculate leafmass and litterfall
    litterfall = lai * LN * allocfact

    # Calculate stem maintenance respiration costs
    stemresp = T(0.0)
    mstemresp = zeros(T, 12)
    for m in 1:12
        if temp[m] <= -46.02
            mstemresp[m] = T(0.0)
        else
            mstemresp[m] = lai * STEMCARBON * respfact * exp(E0 * (T(1.0) / (TREF + TEMP0) - T(1.0) / (temp[m] + TEMP0)))
        end
        stemresp += mstemresp[m]
    end

    # Calculate belowground maintenance respiration costs
    leafmaint = T(0.0)
    finerootresp = P1 * litterfall
    backleafresp = zeros(T, 12)
    mrootresp = zeros(T, 12)

    for m in 1:12
        mrootresp[m] = (mstemresp[m] / stemresp) * finerootresp
        backleafresp[m] = mrootresp[m] * monthlyfpar[m] * T(4.0)
        leafmaint += backleafresp[m]
    end

    # Leaf respiration costs
    leafresp = alresp + leafmaint

    # Clear out the stem respiration if grass
    if sapwood == 2
        stemresp = T(0.0)
        mstemresp = zeros(T, 12)
    end

    # Growth respiration and annual NPP
    growthresp = (T(1.0) - Y) * (gpp - stemresp - leafresp - finerootresp)
    npp = gpp - stemresp - leafresp - finerootresp - growthresp

    # Minimum allocation requirement
    minallocation = T(1.0) * litterfall
    if npp < minallocation
        npp = T(-9999.0)
    end

    # Respiration costs as a percentage of GPP
    percentcost = if gpp > T(0.0) && npp != T(-9999.0)
        T(100.0) * (gpp - npp) / gpp
    else
        T(0.0)
    end

    return npp, stemresp, percentcost, mstemresp, mrootresp, backleafresp
end
