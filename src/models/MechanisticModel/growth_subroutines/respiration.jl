"""
    respiration(gpp, alresp, temp, sapwood, lai, monthlyfpar, pft)

Calculate plant respiration components and net primary productivity (NPP) from 
gross primary productivity (GPP).

This function computes various respiration costs including stem maintenance, 
belowground maintenance, leaf respiration, and growth respiration to determine 
the net primary productivity of a plant functional type.

# Arguments
- `gpp`: Gross primary productivity (carbon gained through photosynthesis)
- `alresp`: Autotrophic leaf respiration
- `temp`: Monthly temperature array (12 elements)
- `sapwood`: sapwood indicator (2 = sapwood, other = woody)
- `lai`: Leaf area index
- `monthlyfpar`: Monthly fraction of photosynthetically active radiation 
  (12 elements)
- `pft`: Plant functional type identifier

# Returns
A tuple containing:
- `npp`: Net primary productivity (-9999.0 if below minimum allocation 
  requirement)
- `stemresp`: Total annual stem maintenance respiration
- `percentcost`: Respiration costs as percentage of GPP
- `mstemresp`: Monthly stem maintenance respiration (12 elements)
- `mrootresp`: Monthly root maintenance respiration (12 elements)
- `backleafresp`: Monthly leaf maintenance respiration (12 elements)

# Notes
- For sapwood PFTs (sapwood == 2), stem respiration is set to zero
- Temperature-dependent respiration follows exponential relationship with 
  reference temperature of 10°C
- NPP is set to -9999.0 if it falls below the minimum allocation requirement
- Function uses multiple hardcoded constants that should ideally be moved to a 
  constants module
"""
function respiration(
    gpp::T,
    alresp::T,
    temp::AbstractArray{T},
    sapwood::Int,
    lai::T,
    monthlyfpar::AbstractArray{T},
    pft::AbstractPFT
)::Tuple{T,T,T,Vector{T},Vector{T},Vector{T}} where {T<:Real,U<:Int}
    allocfact = get_characteristic(pft, :allocfact)
    respfact = get_characteristic(pft, :respfact)

    # Calculate leafmass and litterfall
    litterfall = lai * LN * allocfact

    # Calculate stem maintenance respiration costs
    stemresp = T(0.0)
    mstemresp = zeros(T, 12)
    for m in 1:12
        if temp[m] <= -46.02
            mstemresp[m] = T(0.0)
        else
            temp_factor = exp(
                E0 * (
                    T(1.0) / (TREF + TEMP0) - T(1.0) / (temp[m] + TEMP0)
                )
            )
            mstemresp[m] = lai * STEMCARBON * respfact * temp_factor
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