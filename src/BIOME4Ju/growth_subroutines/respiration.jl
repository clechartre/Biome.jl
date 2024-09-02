"""Calculate annual respiration costs."""

module Respiration

struct RespirationResults
    npp::Float64
    stemresp::Float64
    percentcost::Float64
    mstemresp::AbstractArray{Float64}
    mrootresp::AbstractArray{Float64}
    backleafresp::AbstractArray{Float64}
end

function respiration(
    gpp::Float64,
    alresp::Float64,
    temp::AbstractArray{Float64},
    grass::Int,
    lai::Float64,
    fpar::Float64,
    pft::Int
)::RespirationResults
    # Constants
    Ln = 50.0
    y = 0.8
    m10 = 1.6
    p1 = 0.25
    stemcarbon = 0.5
    e0 = 308.56
    tref = 10.0
    t0 = 46.02

    respfact = [0.8, 0.8, 1.4, 1.6, 0.8, 4.0, 4.0, 1.6, 0.8, 1.4, 4.0, 4.0, 4.0]
    allocfact = [1.0, 1.0, 1.2, 1.2, 1.2, 1.2, 1.2, 1.0, 1.0, 1.0, 1.0, 1.0, 1.5]

    # Calculate leafmass and litterfall
    litterfall = lai * Ln * allocfact[pft]

    # Calculate stem maintenance respiration costs
    stemresp = 0.0
    mstemresp = zeros(Float64, 12)
    for m in 1:12
        if temp[m] <= -46.02
            mstemresp[m] = 0.0
        else
            mstemresp[m] = lai * stemcarbon * respfact[pft] * exp(e0 * (1.0 / (tref + t0) - 1.0 / (temp[m] + t0)))
        end
        stemresp += mstemresp[m]
    end

    # Calculate belowground maintenance respiration costs
    leafmaint = 0.0
    finerootresp = p1 * litterfall
    mrootresp = zeros(Float64, 12)
    backleafresp = zeros(Float64, 12)
    for m in 1:12
        mrootresp[m] = (mstemresp[m] / stemresp) * finerootresp
        backleafresp[m] = mrootresp[m] * fpar * 4.0
        leafmaint += backleafresp[m]
    end

    # Leaf respiration costs
    leafresp = alresp + leafmaint

    # Clear out the stem respiration if grass
    if grass == 2
        stemresp = 0.0
        mstemresp = zeros(Float64, 12)
    end

    # Growth respiration and annual NPP
    growthresp = (1.0 - y) * (gpp - stemresp - leafresp - finerootresp)
    npp = gpp - stemresp - leafresp - finerootresp - growthresp

    # Minimum allocation requirement
    minallocation = 1.0 * litterfall
    if npp < minallocation
        npp = -9999.0
    end

    # Respiration costs as a percentage of GPP
    percentcost = if gpp > 0.0 && npp != -9999.0
        100.0 * (gpp - npp) / gpp
    else
        0.0
    end

    return RespirationResults(
        npp, stemresp, percentcost, mstemresp, mrootresp, backleafresp
    )
end

end # module

using .Respiration

# Example run
gpp = 1000.0
alresp = 50.0
temp = [10.0 for _ in 1:12]
grass = 1
lai = 3.0
fpar = 0.5
pft = 2

result = Respiration.respiration(gpp, alresp, temp, grass, lai, fpar, pft)
println(result)
