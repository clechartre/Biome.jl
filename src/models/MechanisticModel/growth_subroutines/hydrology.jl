"""
hydrology(dprec, dmelt, deq, root, k, maxfvc, pft, phentype, wst, gcopt, mgmin, dphen, dtemp, sapwood, emax, pftpar) :: HydrologyResults

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
- `sapwood`: Presence of sapwood respiration.
- `emax`: Maximum evapotranspiration efficiency (scalar).
- `pftpar`: PFT parameters (2x5 matrix).

Returns:
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
    dprec::AbstractArray{T},
    dmelt::AbstractArray{T},
    deq::AbstractArray{T},
    root::T,
    k::AbstractArray{T},
    maxfvc::T,
    pft::AbstractPFT,
    phentype::U,
    wst::T,
    gcopt::AbstractArray{T},
    mgmin::T,
    dphen::AbstractArray{T},
    dtemp::AbstractArray{T},
    sapwood::U,
    emax::T

    )::Tuple{AbstractArray{T}, AbstractArray{T}, Vector{T}, AbstractArray{T}, AbstractArray{T}, AbstractArray{T}, AbstractArray{T}, T, T, U, T, Bool } where {T <: Real, U <: Int}
    days = T[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    alfam = T(1.4)
    gm = T(5.0)
    onnw = get_characteristic(pft, :sw_drop)
    offw = get_characteristic(pft, :sw_drop)

    # Initializations
    runoffmonth = zeros(T, 12)
    meanfvc = zeros(T, 12)
    meangc = zeros(T, 12)
    meanwr = [zeros(T, 3) for _ in 1:12]  # Vector of 12 vectors, each of length 3
    meanaet = zeros(T, 12)
    wet = zeros(T, 365)
    dayfvc = zeros(T, 365)
    runnoff = T(0.0)
    drainage = T(0.0)
    aet = T(0.0)
    annaet = T(0.0)
    sumoff = T(0.0)
    greendays = U(0)
    wilt = false
    gc = T(0.0)
    fvc = T(0.0)
    gmin = T(0.0)
    gsurf = T(0.0)

    wr = T(0.0)
    w = zeros(T, 2)
    w[1] = wst
    w[2] = wst

    for _ in 1:2
        # Reset them for the second iteration
        d = 0
        annaet = T(0.0)
        sumoff = T(0.0)
        greendays = U(0)
        wilt = false

        for month in 1:12
            meanfvc[month] = T(0.0)
            meangc[month] = T(0.0)
            meanwr[month][1] = T(0.0)
            meanwr[month][2] = T(0.0)
            meanwr[month][3] = T(0.0)
            meanaet[month] = T(0.0)
            runoffmonth[month] = T(0.0)

            for _ in 1:days[month]
                d += 1
                wr = root * w[1] + (T(1.0) - root) * w[2]

                # Vegetation Phenology Calculation
                if phentype == 1  # Evergreen
                    fvc = maxfvc

                elseif phentype == 2  # Cold deciduous
                    fvc = maxfvc * dphen[d, sapwood]

                elseif sapwood == 2  # sapwood cold deciduous
                    fvc = maxfvc * dphen[d, sapwood]
                    if fvc > T(0.01) && wr > offw
                        fvc = fvc
                    elseif fvc < T(0.01) && wr > onnw
                        fvc = fvc
                    else
                        fvc = T(0.0)
                    end

                elseif fvc > T(0.01) && wr > offw  # Drought deciduous
                    fvc = maxfvc

                elseif fvc < T(0.01) && wr > onnw
                    fvc = maxfvc

                else
                    fvc = T(0.0)
                end

                if fvc > T(0.0)
                    greendays += 1
                end

                if dtemp[d] <= T(-10.0)
                    gc = T(0.0)
                    aet = T(0.0)
                    perc = T(0.0)

                else
                    if fvc == T(0.0)
                        aet = T(0.25) * deq[d]
                    else
                        gmin = mgmin * fvc
                        gc = gcopt[d] * (fvc / maxfvc)
                        gsurf = gc + gmin
                        if gsurf > 0.0
                            alfa = min(T(1.0), alfam * (T(1.0) - exp(-gsurf / gm)))
                            aet = alfa * deq[d]
                        else
                            alfa = T(0.0)
                            aet = T(0.0)
                        end
                    end

                    wetphytomass = T(0.01) * aet
                    waste = T(0.01) * aet
                    demand = aet + wetphytomass + waste
                    supply = emax * wr

                    if demand > supply
                        a = T(1.0) - supply / (deq[d] * alfam)
                        a = max(a, T(0.0))
                        gsurf = -gm * log(a)
                        gc = gsurf - gmin
                        aet = supply
                        if gc <= T(0.0)
                        gc = T(0.0)
                        wilt = true
                        end
                    end                      

                    perc = k[1] * w[1] ^ T(4.0)
                    evap = T(0.0)

                    if wr > T(0.0)
                        r1 = [root * (w[1] / wr), (T(1.0) - root) * (w[2] / wr)]
                    else
                        r1 = T[0.0, 0.0]
                    end

                    if k[5] != T(0.0)
                        w[1] = w[1] + (dprec[d] + dmelt[d] - perc - evap - r1[1] * aet) / k[5]
                    else
                        w[1] = T(0.0)
                    end

                    if k[6] != 0.0
                        w[2] = w[2] + (perc - r1[2] * aet) / k[6]
                    else
                        w[2] = T(0.0)
                    end

                    drainage = T(0)

                    if w[2] >= T(1.0)
                        drainage = (w[2] - T(1.0)) * k[6]
                        w[2] = T(1.0)
                    end

                    runnoff = T(0)

                    if w[1] >= T(1.0)
                        runnoff = (w[1] - T(1.0)) * k[5]
                        w[1] = T(1.0)
                    end

                    if w[1] <= T(0.0)
                        w[1] = T(0.0)
                    end
                    
                    if w[2] <= T(0.0)
                        w[2] = T(0.0)
                    end
                
                end

                annaet += aet
                sumoff += runnoff + drainage
                runoffmonth[month] += runnoff + drainage
                meanwr[month][1] += wr / days[month]
                meanwr[month][2] += w[1] / days[month]
                meanwr[month][3] += w[2] / days[month]

                if gc != T(0.0)
                    meangc[month] += gc / days[month]
                end
                if fvc != T(0.0)
                    meanfvc[month] += fvc / days[month]
                end
                meanaet[month] += aet / days[month]

                wet[d] = wr
                dayfvc[d] = fvc
            end
        end
    end

    meanwr = map(mean, meanwr)

    return  meanfvc, 
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
end