"""
    growth

Main growth module for plant functional types.

This module orchestrates the calculation of net primary productivity (NPP) for
plant functional types by integrating photosynthesis, respiration, hydrology,
and carbon cycling processes.
"""

# Third-party
using Statistics: mean

"""
    growth(maxlai, annp, sun, temp, dprec, dmelt, dpet, k, pft, dayl, dtemp, dphen,
           co2, p, tsoil, mnpp, c4mnpp, pftstates, ws)

Calculate net primary productivity and carbon fluxes for a plant functional type.

Uses a GrowthWorkspace `ws` to reuse temporary arrays and avoid repeated allocations.
"""
function growth(
    maxlai::T,
    annp::T,
    sun::AbstractArray{T},
    temp::AbstractArray{T},
    dprec::AbstractArray{T},
    dmelt::AbstractArray{T},
    dpet::AbstractArray{T},
    k::AbstractArray{T},
    pft::AbstractPFT,
    dayl::AbstractArray{T},
    dtemp::AbstractArray{T},
    dphen::AbstractArray{T},
    co2::T,
    p::T,
    tsoil::AbstractArray{T},
    mnpp::Vector{T},
    c4mnpp::Vector{T},
    pftstates::PFTState,
    ws::GrowthWorkspace{T}
)::Tuple{T,AbstractArray{T},AbstractArray{T}, PFTState} where {T<:Real}

    # Reuse workspace arrays instead of reallocating
    lresp       = ws.lresp
    Rlit        = ws.Rlit
    Rfst        = ws.Rfst
    Rslo        = ws.Rslo
    Rtot        = ws.Rtot
    isoflux     = ws.isoflux
    isoR        = ws.isoR
    maintresp   = ws.maintresp
    mgrowresp   = ws.mgrowresp
    mstemresp   = ws.mstemresp
    mrootresp   = ws.mrootresp
    mgpp        = ws.mgpp
    CCratio     = ws.CCratio
    isoresp     = ws.isoresp
    c4gpp       = ws.c4gpp
    c4fpar      = ws.c4fpar
    c4parr      = ws.c4parr
    c4apar      = ws.c4apar
    c4ccratio   = ws.c4ccratio
    c4leafresp  = ws.c4leafresp
    monthlyfpar = ws.monthlyfpar
    monthlyparr = ws.monthlyparr
    monthlyapar = ws.monthlyapar
    mlresp      = ws.mlresp
    optgc       = ws.optgc
    doptgc      = ws.doptgc

    # Clear workspace arrays (no allocations)
    for arr in (lresp, Rlit, Rfst, Rslo, Rtot, isoflux, isoR,
                maintresp, mgrowresp, mstemresp, mrootresp,
                mgpp, CCratio, isoresp,
                c4gpp, c4fpar, c4parr, c4apar, c4ccratio, c4leafresp,
                monthlyfpar, monthlyparr, monthlyapar, mlresp, optgc)
        fill!(arr, zero(T))
    end

    # constants via tuple
    midday, days = initialize_arrays(T, typeof(pft.characteristics).parameters[2])

    c4_override = nothing
    reprocess = true
    U = typeof(pft.characteristics).parameters[2]

    while reprocess
        reprocess = false

        optratioa = T(get_characteristic(pft, :optratioa))
        kk        = T(get_characteristic(pft, :kk))
        ca        = co2 * T(1e-6)
        wst       = min(annp / T(1000.0), T(1.0))

        phentype  = U(get_characteristic(pft, :phenological_type))
        mgmin     = T(get_characteristic(pft, :max_min_canopy_conductance))
        root      = T(get_characteristic(pft, :root_fraction_top_soil))
        age       = T(get_characteristic(pft, :leaf_longevity))
        sapwood   = U(get_characteristic(pft, :sapwood_respiration))
        emax      = T(get_characteristic(pft, :Emax))
        maxfvc    = one(T) - T(exp(-kk * maxlai))


        c4, optratio = determine_c4_and_optratio(pft, optratioa, c4_override)

        maxgc = T(0)
        @inbounds for m in 1:12
            tsecs = T(3600) * dayl[m]
            fpar  = T(1) - exp(-kk * maxlai)

            if c4
                alllresp, pgphot, aday = c4photo(optratio, sun[m], dayl[m],
                                                 temp[m], age, fpar, p, ca, pft)
            else
                alllresp, pgphot, aday = photosynthesis(optratio, sun[m], dayl[m],
                                                        temp[m], age, fpar, p, ca, pft)
            end

            lresp[m] = alllresp
            gt = (tsecs > 0 && aday > 0) ?
                (mgmin + (T(1.6) * aday) / (ca * (T(1) - optratio)) / tsecs) :
                T(0)

            optgc[m] = gt
            maxgc = max(maxgc, gt)
        end

        # Daily canopy conductance (in-place interp)
        daily_interp!(doptgc, optgc)

        meanfvc, meangc, meanwr, meanaet, runoffmonth, wet, dayfvc, annaet,
        sumoff, greendays, runnoff, wilt =
            hydrology(
                dprec, dmelt, dpet, root, k, maxfvc, pft, phentype,
                wst, doptgc, mgmin, dphen, dtemp, sapwood, emax
            )

        pftstates.greendays = greendays
        meanwrround = Vector{T}(undef, 12)
        @inbounds for m in 1:12
            meanwrround[m] = T(safe_round_to_int(100 * meanwr[m][2]))
        end
        pftstates.mwet = meanwrround

        alresp      = T(0)
        gpp         = T(0)
        leaftime    = T(0)  # kept for compatibility, even if unused
        annualparr  = T(0)
        annualapar  = T(0)

        @inbounds for m in 1:12
            if meangc[m] == T(0)
                gphot    = T(0)
                rtbis    = T(0)
                leafresp = lresp[m] * (meanfvc[m] / maxfvc)
            else
                # Bisection loop
                x1 = T(0.02)
                x2 = optratio + T(0.05)
                rtbis = x1
                dx    = x2 - x1

                gphot    = T(0)
                leafresp = T(0)

                for _ in 1:10
                    dx   *= T(0.5)
                    xmid  = rtbis + dx
                    fpar  = meanfvc[m]

                    if c4
                        leafresp, igphot, aday = c4photo(xmid, sun[m], dayl[m],
                                                         temp[m], age, fpar, p, ca, pft)
                    else
                        leafresp, igphot, aday = photosynthesis(xmid, sun[m], dayl[m],
                                                                temp[m], age, fpar, p, ca, pft)
                    end

                    gt = T(3600) * dayl[m] * meangc[m]
                    ap = (gt == T(0)) ? T(0) :
                         (mgmin + (gt / T(1.6)) * (ca * (T(1) - xmid)))

                    fmid = aday - ap
                    if fmid <= T(0)
                        rtbis = xmid
                        gphot = igphot
                    end
                end
            end

            monthlyfpar[m] = meanfvc[m]
            monthlyparr[m] = sun[m] * T(days[m]) * T(1e-6)
            monthlyapar[m] = monthlyparr[m] * monthlyfpar[m]
            mgpp[m]        = T(days[m]) * gphot
            mlresp[m]      = T(days[m]) * leafresp
            CCratio[m]     = rtbis
            isoresp[m]     = mlresp[m]

            annualparr += monthlyparr[m]
            annualapar += monthlyapar[m]
            gpp        += mgpp[m]
            alresp     += mlresp[m]

            if c4
                c4gpp[m]      = mgpp[m]
                c4fpar[m]     = monthlyfpar[m]
                c4parr[m]     = monthlyparr[m]
                c4apar[m]     = monthlyapar[m]
                c4ccratio[m]  = rtbis
                c4leafresp[m] = mlresp[m]
            end
        end

        # Respiration and annual NPP
        npp, stemresp, percentcost, mstemresp, mrootresp, backleafresp =
            respiration(gpp, alresp, temp, sapwood, maxlai, monthlyfpar, pft)

        if wilt
            npp = T(-9999)
        end

        # Monthly NPP
        nppsum = T(0)
        @inbounds for m in 1:11
            maintresp[m] = mlresp[m] + backleafresp[m] +
                           mstemresp[m] + mrootresp[m]
            mgrowresp[m] = max(T(0), T(0.02) * (mgpp[m+1] - maintresp[m+1]))
            mnpp[m]      = mgpp[m] - (maintresp[m] + mgrowresp[m])
        end

        # Month 12
        maintresp[12] = mlresp[12] + backleafresp[12] +
                        mstemresp[12] + mrootresp[12]
        mgrowresp[12] = max(T(0), T(0.02) * (mgpp[1] - maintresp[1]))
        mnpp[12]      = mgpp[12] - (maintresp[12] + mgrowresp[12])

        @inbounds for m in 1:12
            if c4
                c4mnpp[m] = mnpp[m]
            end
            nppsum += mnpp[m]
        end

        # C3/C4 comparison
        nppsum, c4pct, c4month, mnpp, annc4npp,
        monthlyfpar, monthlyparr, monthlyapar, CCratio, isoresp =
            compare_c3_c4_npp(
                pft, mnpp, c4mnpp, monthlyfpar, monthlyparr, monthlyapar,
                CCratio, isoresp, c4fpar, c4parr, c4apar,
                c4ccratio, c4leafresp, nppsum, c4
            )
-
        # C3/C4 reprocess rule
        if get_characteristic(pft, :name) == "C3C4WoodyDesert" && c4
            c4_override = false
            reprocess   = true
            continue
        end

        if npp != nppsum
            npp = nppsum
        end

        if npp <= T(0)
            return T(npp), mnpp, c4mnpp, pftstates
        end

        meanC3 = T(0)
        meanC4 = T(0)

        if gpp > T(0)
            if get_characteristic(pft, :grass) == true ||
               get_characteristic(pft, :name) == "C3C4WoodyDesert"

                phi = calcphi(mgpp)

                meanC3, meanC4, C3DA, C4DA =
                    isotope(CCratio, ca, temp, isoresp, c4month, mgpp, phi, gpp)
            end
        end

        Rmean     = T(0)
        meanKlit  = T(0)
        meanKsoil = T(0)

        moist = map(mean, meanwr)

        Rlit, Rfst, Rslo, Rtot, isoR, isoflux, Rmean,
        meanKlit, meanKsoil =
            hetresp(
                pft, npp, tsoil, meanaet, moist, meanC3,
                Rlit, Rfst, Rslo, Rtot, isoR, isoflux,
                Rmean, meanKlit, meanKsoil
            )

        # FIRE
        pftstates.firedays = fire(wet, pft, maxlai, npp)

        return npp, mnpp, c4mnpp, pftstates
    end
end


"""
    initialize_arrays(T, U)

Initialize day-of-year arrays for monthly calculations.

# Arguments
- `T`: Real number type
- `U`: Integer type

# Returns
- `midday`: Vector of mid-month day numbers
- `days`: Vector of days per month
"""
function initialize_arrays(
    ::Type{T},
    ::Type{U}
)::Tuple{Vector{U},Vector{U}} where {T<:Real,U<:Int}
    midday = U[16, 44, 75, 105, 136, 166, 197, 228, 258, 289, 319, 350]
    days   = U[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    return midday, days
end

"""
    determine_c4_and_optratio(pft, optratioa, c4_override)

Determine C4 photosynthesis type and optimal ratio for a PFT.
"""
function determine_c4_and_optratio(
    pft::AbstractPFT,
    optratioa::T,
    c4_override::Union{Bool,Nothing}=nothing
)::Tuple{Bool,T} where {T<:Real}
    if c4_override !== nothing
        c4 = c4_override
    else
        c4 = get_characteristic(pft, :c4) == true
    end

    optratio = c4 ? T(0.4) : T(optratioa)
    return c4, optratio
end

"""
    compare_c3_c4_npp(...)

Compare C3 and C4 NPP values and determine optimal photosynthetic pathway.
"""
function compare_c3_c4_npp(
    pft::AbstractPFT,
    mnpp::AbstractArray{T},
    c4mnpp::AbstractArray{T},
    monthlyfpar::AbstractArray{T},
    monthlyparr::AbstractArray{T},
    monthlyapar::AbstractArray{T},
    CCratio::AbstractArray{T},
    isoresp::AbstractArray{T},
    c4fpar::AbstractArray{T},
    c4parr::AbstractArray{T},
    c4apar::AbstractArray{T},
    c4ccratio::AbstractArray{T},
    c4leafresp::AbstractArray{T},
    nppsum::T,
    c4::Bool
) where {T<:Real}
    c4months = 0
    annc4npp = T(0.0)
    c4month  = fill(false, 12)

    for m in 1:12
        if get_characteristic(pft, :name) == "C4TropicalGrass"
            c4month[m] = true
        end
    end

    if get_characteristic(pft, :name) == "C3C4WoodyDesert"
        for m in 1:12
            if c4mnpp[m] > mnpp[m]
                c4months += 1
            end
        end

        if c4months >= 3
            for m in 1:12
                if c4mnpp[m] > mnpp[m]
                    c4month[m] = true
                end
            end
        end
    end

    totnpp = T(0.0)

    for m in 1:12
        if c4month[m]
            mnpp[m]         = c4mnpp[m]
            annc4npp       += c4mnpp[m]
            monthlyfpar[m]  = c4fpar[m]
            monthlyparr[m]  = c4parr[m]
            monthlyapar[m]  = c4apar[m]
            CCratio[m]      = c4ccratio[m]
            isoresp[m]      = c4leafresp[m]
        end
        totnpp += mnpp[m]
    end

    if c4months >= 2
        nppsum = totnpp
    end

    c4pct = (nppsum != T(0)) ? annc4npp / nppsum : T(0.0)

    return nppsum, c4pct, c4month, mnpp, annc4npp,
           monthlyfpar, monthlyparr, monthlyapar, CCratio, isoresp
end
