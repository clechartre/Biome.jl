module Hydrology

struct HydrologyResults
    meanfvc::AbstractArray{Float64}
    meangc::AbstractArray{Float64}
    meanwr::Vector{AbstractArray{Float64}}
    meanaet::AbstractArray{Float64}
    runoffmonth::AbstractArray{Float64}
    wet::AbstractArray{Float64}
    dayfvc::AbstractArray{Float64}
    annaet::Float64
    sumoff::Float64
    greendays::Int
    runnoff::Float64
    wilt::Bool
end

"""
    hydrology(dprec, dmelt, deq, root, k, maxfvc, pft, phentype, wst, gcopt, mgmin, dphen, dtemp, grass, emax, pftpar) :: HydrologyResults

Calculate the actual values of canopy conductance (gc), soil moisture, and other hydrological variables.

Arguments:
- `dprec`: Daily precipitation (365-element vector).
- `dmelt`: Daily snowmelt (365-element vector).
- `deq`: Daily equilibrium evapotranspiration (365-element vector).
- `root`: Root fraction (scalar).
- `k`: Array of soil and canopy parameters (vector of 7 elements).
- `maxfvc`: Maximum foliar vegetation cover (scalar).
- `pft`: Plant Functional Type (scalar).
- `phentype`: Phenological type (scalar).
- `wst`: Initial soil moisture (scalar).
- `gcopt`: Optimal canopy conductance (365-element vector).
- `mgmin`: Minimum canopy conductance modifier (scalar).
- `dphen`: Phenology data (365x2 matrix).
- `dtemp`: Daily temperature (365-element vector).
- `grass`: Grass type indicator (scalar).
- `emax`: Maximum evapotranspiration efficiency (scalar).
- `pftpar`: PFT parameters (2x5 matrix).

Returns:
- `HydrologyResults`: A struct containing:
  - `meanfvc`: Mean monthly foliar vegetation cover.
  - `meangc`: Mean monthly canopy conductance.
  - `meanwr`: Mean monthly soil water reservoir (root zone, layer 1, and layer 2).
  - `meanaet`: Mean monthly actual evapotranspiration.
  - `runoffmonth`: Monthly runoff values.
  - `wet`: Daily soil water reservoir values.
  - `dayfvc`: Daily foliar vegetation cover.
  - `annaet`: Annual actual evapotranspiration.
  - `sumoff`: Total runoff and drainage.
  - `greendays`: Number of days with active vegetation.
  - `runnoff`: Final runoff value.
  - `wilt`: Boolean indicating whether wilting occurred.
"""
function hydrology(
    dprec::AbstractArray{Float64},
    dmelt::AbstractArray{Float64},
    deq::AbstractArray{Float64},
    root::Float64,
    k::AbstractArray{Float64},
    maxfvc::Float64,
    pft::Int,
    phentype::Int,
    wst::Float64,
    gcopt::AbstractArray{Float64},
    mgmin::Float64,
    dphen::AbstractArray{Float64},
    dtemp::AbstractArray{Float64},
    grass::Int,
    emax::Float64,
    pftpar::AbstractArray{Float64, 2}
)::HydrologyResults
    days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    alfam = 1.4
    gm = 5.0
    onnw = pftpar[pft, 4]
    offw = pftpar[pft, 4]

    meanfvc = zeros(Float64, 12)
    meangc = zeros(Float64, 12)
    meanwr = [zeros(Float64, 3) for _ in 1:12]
    meanaet = zeros(Float64, 12)
    runoffmonth = zeros(Float64, 12)
    wet = zeros(Float64, 365)
    dayfvc = zeros(Float64, 365)
    runnoff = 0.0
    drainage = 0.0
    gc = 0.0
    fvc = 0.0
    annaet = 0.0
    sumoff = 0.0
    greendays = 0
    wilt = false

    w = zeros(Float64, 2)
    w[1] = wst
    w[2] = wst

    for _ in 1:2
        # Reset them for the second iteration
        d = 0
        annaet = 0.0
        sumoff = 0.0
        greendays = 0
        wilt = false

        for month in 1:12
            meanfvc[month] = 0.0
            meangc[month] = 0.0
            meanwr[month] = [0.0, 0.0, 0.0]
            meanaet[month] = 0.0
            runoffmonth[month] = 0.0

            for dayofmonth in 1:days[month]
                d = d + 1
                wr = root * w[1] + (1.0 - root) * w[2]

                # Vegetation Phenology Calculation
                if phentype == 1  # Evergreen
                    fvc = maxfvc

                elseif phentype == 2 || grass == 2  # Cold deciduous
                    fvc = maxfvc * dphen[d, grass]
                    if fvc > 0.01 && wr > offw
                        fvc = fvc
                    elseif fvc < 0.01 && wr > onnw
                        fvc = fvc
                    else
                        fvc = 0.0
                    end

                elseif fvc > 0.01 && wr > offw  # Drought deciduous
                    fvc = maxfvc

                elseif fvc < 0.01 && wr > onnw
                    fvc = maxfvc

                else
                    fvc = 0.0
                end

                if fvc > 0.0
                    greendays += 1
                end

                if dtemp[d] <= -10.0
                    gc = 0.0
                    aet = 0.0
                    perc = 0.0
                    gmin = mgmin * fvc
                    gsurf = gc + gmin
                else
                    gmin = mgmin * fvc
                    gc = gcopt[month] * (fvc / maxfvc)
                    gsurf = gc + gmin
                    if fvc == 0.0
                        aet = 0.25 * deq[d]
                    else
                        if gsurf > 0.0
                            alfa = min(1.0, alfam * (1.0 - exp(-gsurf / gm)))
                            aet = alfa * deq[d]
                        else
                            alfa = 0.0
                            aet = 0.0
                        end
                    end

                    wetphytomass = 0.01 * aet
                    waste = 0.01 * aet
                    demand = aet + wetphytomass + waste
                    supply = emax * wr

                    if demand > supply
                        a = 1.0 - supply / (deq[d] * alfam)
                        a = max(a, 0.0)
                        gsurf = -gm * log(a)
                        gc = gsurf - gmin
                        aet = supply
                        if gc <= 0.0
                          gc = 0.0
                          wilt = true
                        end
                      end                      
                end

                perc = k[1] * w[1] ^ 4.0
                evap = 0.0

                if wr > 0.0
                    r1 = [root * (w[1] / wr), (1.0 - root) * (w[2] / wr)]
                else
                    r1 = [0.0, 0.0]
                end

                if k[5] != 0.0
                    w[1] = w[1] + (dprec[d] + dmelt[d] - perc - evap - r1[1] * aet) / k[5]
                else
                    w[1] = 0.0
                end

                if k[6] != 0.0
                    w[2] = w[2] + (perc - r1[2] * aet) / k[6]
                else
                    w[2] = 0.0
                end

                drainage = 0

                if w[2] >= 1.0
                    drainage = (w[2] - 1.0) * k[6]
                    w[2] = 1.0
                end

                runnoff = 0

                if w[1] >= 1.0
                    runnoff = (w[1] - 1.0) * k[5]
                    w[1] = 1.0
                end

                if w[1] <= 0.0
                    w[1] = 0.0
                end
                
                if w[2] <= 0.0
                    w[2] = 0.0
                end

                annaet += aet
                sumoff += runnoff + drainage
                runoffmonth[month] += runnoff + drainage
                meanwr[month][1] += wr / days[month]
                meanwr[month][2] += w[1] / days[month]
                meanwr[month][3] += w[2] / days[month]

                if gc != 0.0
                    meangc[month] += gc / days[month]
                end
                if fvc != 0.0
                    meanfvc[month] += fvc / days[month]
                end
                meanaet[month] += aet / days[month]

                wet[d] = wr
                dayfvc[d] = fvc
            end
        end
    end

    return HydrologyResults(
        meanfvc,
        meangc,
        meanwr,
        meanaet,
        runoffmonth,
        wet,
        dayfvc,
        annaet,
        sumoff,
        greendays,
        runnoff,
        wilt
    )
end

end # module

using .Hydrology

# Example run
dprec = [rand() for _ in 1:365]
dmelt = [rand() for _ in 1:365]
deq = [rand() for _ in 1:365]
root = 0.5
k = [0.1, 0.2, 0.3, 0.4, 0.5, 1.0, 1.0]
maxfvc = 0.8
pft = 1
phentype = 1
wst = 0.3
gcopt = [0.1 for _ in 1:365]
mgmin = 0.05
dphen = rand(365, 2)
dtemp = [15.0 for _ in 1:365]
grass = 1
emax = 0.9
pftpar = rand(2, 5)

result = Hydrology.hydrology(dprec, dmelt, deq, root, k, maxfvc, pft, phentype, wst, gcopt, mgmin, dphen, dtemp, grass, emax, pftpar)
println(result)
