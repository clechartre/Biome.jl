module Respiration
using ComponentArrays: ComponentArray

struct RespirationResults{T <: Real}
    npp::T
    stemresp::T
    percentcost::T
    mstemresp::Vector{T}
    mrootresp::Vector{T}
    backleafresp::Vector{T}
end

function respiration(
    gpp::T,
    alresp::T,
    temp::AbstractArray{T},
    grass::Int,
    lai::T,
    monthlyfpar::AbstractArray{T},
    pft::U,
    pftdict
)::RespirationResults{T} where {T <: Real, U <: Int}
    # Constants
    Ln = T(50.0)
    y = T(0.8)
    m10 = T(1.6)
    p1 = T(0.25)
    stemcarbon = T(0.5)
    e0 = T(308.56)
    tref = T(10.0)
    t0 = T(46.02)

    allocfact = pftdict[pft].additional_params.allocfact
    respfact = pftdict[pft].additional_params.respfact

    # Calculate leafmass and litterfall
    litterfall = lai * Ln * allocfact

    # Calculate stem maintenance respiration costs
    stemresp = T(0.0)
    mstemresp = zeros(T, 12)
    for m in 1:12
        if temp[m] <= -46.02
            mstemresp[m] = T(0.0)
        else
            mstemresp[m] = lai * stemcarbon * respfact * exp(e0 * (T(1.0) / (tref + t0) - T(1.0) / (temp[m] + t0)))
        end
        stemresp += mstemresp[m]
    end

    # Calculate belowground maintenance respiration costs
    leafmaint = T(0.0)
    finerootresp = p1 * litterfall
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
    if grass == 2
        stemresp = T(0.0)
        mstemresp = zeros(T, 12)
    end

    # Growth respiration and annual NPP
    growthresp = (T(1.0) - y) * (gpp - stemresp - leafresp - finerootresp)
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

    return RespirationResults(
        npp, stemresp, percentcost, mstemresp, mrootresp, backleafresp
    )
end

end # module
