# Third-party
using Statistics: mean

# Import all growth subroutines 
include("./growth_subroutines/c4photo.jl")
include("./growth_subroutines/calcphi.jl")
include("./growth_subroutines/fire.jl")
include("./growth_subroutines/hetresp.jl")
include("./growth_subroutines/hydrology.jl")
include("./growth_subroutines/isotope.jl")
include("./growth_subroutines/photosynthesis.jl")
include("./growth_subroutines/respiration.jl")

export c4photo, calcphi, fire, hetresp, hydrology, isotope, photosynthesis, respiration


function safe_exp(x::T)::T where {T <: Real}
    try
        return exp(x)
    catch e
        return Inf
    end
end

function safe_round_to_int(x::T)::Int where {T <: Real}
    if isnan(x)
        return 0
    elseif x > typemax(Int)
        return typemax(Int)
    elseif x < typemin(Int)
        return typemin(Int)
    else
        return round(Int, x)
    end
end

function initialize_arrays(::Type{T}, ::Type{U})::Tuple{Vector{U}, Vector{U}} where {T <: Real, U <: Int}
    midday = U[16, 44, 75, 105, 136, 166, 197, 228, 258, 289, 319, 350]
    days = U[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    return midday, days
end

function determine_c4_and_optratio(BIOME4PFTS::AbstractPFTList, pft::U, optratioa::T, c4_override::Union{Bool, Nothing}=nothing)::Tuple{Bool, T} where {T <: Real, U <: Int}
    if c4_override != nothing
        c4 = c4_override
    else
        if get_characteristic(BIOME4PFTS.pft_list[pft], :c4) == true 
            c4 = true
        else
            c4 = false
        end 
    end

    optratio = c4 ? T(0.4) : T(optratioa)
    return c4, optratio
end


function growth(
    maxlai::T,
    annp::T,
    sun::AbstractArray{T},
    temp::AbstractArray{T},
    dprec::AbstractArray{T},
    dmelt::AbstractArray{T},
    dpet::AbstractArray{T},
    k::AbstractArray{T},
    BIOME4PFTS::AbstractPFTList,
    pft::U,
    dayl::AbstractArray{T},
    dtemp::AbstractArray{T},
    dphen::AbstractArray{T},
    co2::T,
    p::T,
    tsoil::AbstractArray{T},
    mnpp::Vector{T},
    c4mnpp::Vector{T}
)::Tuple{T, AbstractArray{T}, AbstractArray{T}} where {T <: Real, U <: Int}

    # Initialize variables
    c4_override = nothing
    reprocess = true

    while reprocess == true
        reprocess = false

        # Initialize set values
        midday, days= initialize_arrays(T, U)
        optratioa = get_characteristic(BIOME4PFTS.pft_list[pft], :optratioa)
        kk = get_characteristic(BIOME4PFTS.pft_list[pft], :kk)
        ca = co2 * T(1e-6)
        rainscalar = T(1000.0)
        wst = annp / rainscalar
        wst = min(wst, T(1.0))

        phentype = get_characteristic(BIOME4PFTS.pft_list[pft], :phenological_type)
        mgmin = get_characteristic(BIOME4PFTS.pft_list[pft], :max_min_canopy_conductance)
        root = get_characteristic(BIOME4PFTS.pft_list[pft], :root_fraction_top_soil)
        age = get_characteristic(BIOME4PFTS.pft_list[pft], :leaf_longevity)
        sapwood = get_characteristic(BIOME4PFTS.pft_list[pft], :sapwood_respiration)
        emax = get_characteristic(BIOME4PFTS.pft_list[pft], :Emax)
        maxfvc = one(T) - T(exp(-kk * maxlai))

        # Initialize values 
        # FIXME hopefully there is a better way
        phi = T(0.0)
        Rmean = T(0.0)
        meanKlit = T(0.0)
        meanKsoil = T(0.0)
        gphot = T(0.0)
        maxgc = T(0.0)

        # Initialize Array
        lresp = zeros(T, 12)
        Rlit = zeros(T, 12)
        Rfst = zeros(T, 12)
        Rslo = zeros(T, 12)
        Rtot = zeros(T, 12)
        isoflux = zeros(T, 12)
        isoR = zeros(T, 12)
        maintresp = zeros(T, 12)
        mgrowresp = zeros(T, 12)
        mstemresp = zeros(T, 12)
        mrootresp = zeros(T, 12)
        mgpp = zeros(T, 12)
        CCratio = zeros(T, 12)
        isoresp = zeros(T, 12)
        c4gpp = zeros(T, 12)
        c4fpar = zeros(T, 12)
        c4parr = zeros(T, 12)
        c4apar = zeros(T, 12)
        c4ccratio = zeros(T, 12)
        c4leafresp = zeros(T, 12)
        monthlyfpar = zeros(T, 12)
        monthlyparr = zeros(T, 12)
        monthlyapar = zeros(T, 12)
        mlresp = zeros(T, 12)
        optgc = zeros(T, 12)
    
        # Set the value of optratio depending on whether c4 plant or not.
        c4, optratio = determine_c4_and_optratio(BIOME4PFTS, pft, optratioa, c4_override)
    

        maxgc = T(0.0)
        for m in 1:12
            tsecs = T(3600.0) * dayl[m]
            fpar = T(1.0) - T(exp(-kk * maxlai))

            if c4
                alllresp, pgphot, aday = c4photo(optratio, sun[m], dayl[m], temp[m], age, fpar, p, ca, pft, BIOME4PFTS)
                lresp[m] = alllresp
            else
                alllresp, pgphot, aday  = photosynthesis(optratio, sun[m], dayl[m], temp[m], age, fpar, p, ca, pft, BIOME4PFTS)
                lresp[m] = alllresp
            end
    
            if tsecs > 0.0 && aday > 0.0
                gt = mgmin + (T(1.6) * aday) / (ca * (T(1.0) - optratio)) / tsecs
            else
                gt = T(0.0)
            end
    
            # This gives us the final non-water-stressed gc value
            optgc[m] = gt
    
            # Store output values:
            maxgc = max(maxgc, optgc[m])
        end
    
        doptgc = daily(optgc)

        meanfvc, meangc, meanwr, meanaet, runoffmonth, wet, dayfvc, annaet, sumoff, greendays, runnoff, wilt = hydrology(
            dprec, dmelt, dpet, root, k, maxfvc, pft, phentype,
            wst, doptgc, mgmin, dphen, dtemp, sapwood, emax, BIOME4PFTS)

        set_characteristic(BIOME4PFTS.pft_list[pft], :greendays, greendays)
        set_characteristic(BIOME4PFTS.pft_list[pft], :mwet, meanwr)

        # Initialize annual variables
        alresp = T(0.0)
        gpp = T(0.0)
        leaftime = T(0.0)
        annualparr = T(0.0)
        annualapar = T(0.0)

        for m in 1:12
            # If meangc is zero then photosynthesis must also be zero
            if meangc[m] == T(0.0)
                gphot = T(0.0)
                rtbis = T(0.0)
                leafresp = lresp[m] * (meanfvc[m] / maxfvc)
            else
                # Iterate to a solution for gphot given this meangc value using bisection method
                x1 = T(0.02)
                x2 = optratio + T(0.05)
                rtbis = x1
                dx = x2 - x1
                for _ in 1:10
                    dx *= T(0.5)
                    xmid = rtbis + dx
                    fpar = meanfvc[m]
    
                    if c4
                        allleafresp, alligphot, alladay = c4photo(xmid, sun[m], dayl[m], temp[m], age, fpar, p, ca, pft, BIOME4PFTS)
                        leafresp = allleafresp
                        igphot = alligphot
                        aday = alladay
                    else
                        allleafresp, alligphot, alladay = photosynthesis(xmid, sun[m], dayl[m], temp[m], age, fpar, p, ca, pft, BIOME4PFTS)
                        leafresp = allleafresp
                        igphot = alligphot
                        aday = alladay
                    end
    
                    gt = 3600 * dayl[m] * meangc[m]
    
                    ap = if gt == T(0.0) T(0.0) else mgmin + (gt / 1.6) * (ca * (1.0 - xmid)) end
    
                    fmid = aday - ap

                    if fmid <= T(0.0)
                        rtbis = xmid
                        gphot = igphot
                    end
                end
    
            end
    
            # Calculate monthly PAR values
            monthlyfpar[m] = meanfvc[m]
            monthlyparr[m] = sun[m] * days[m] * 1e-6
            monthlyapar[m] = monthlyparr[m] * monthlyfpar[m]
    
            # Store monthly results in lists
            mgpp[m] = days[m] * gphot
            mlresp[m] = days[m] * leafresp
            CCratio[m] = rtbis
            isoresp[m] = mlresp[m]
    
            # Accumulate annual totals
            annualapar += monthlyapar[m]
            annualparr += monthlyparr[m]
            gpp += mgpp[m]
            alresp += mlresp[m]
    
            if c4
                c4gpp[m] = mgpp[m]
                c4fpar[m] = monthlyfpar[m]
                c4parr[m] = monthlyparr[m]
                c4apar[m] = monthlyapar[m]
                c4ccratio[m] = rtbis
                c4leafresp[m] = mlresp[m]
            end
        end
    
        # Calculate monthly LAI
        monthlylai = [log(1 - monthlyfpar[m]) / (-kk) for m in 1:12]
    
        # Calculate 10-day LAI
        tendaylai = zeros(T, 40)  # Initialize a vector of size 40
        i = 1
        for day in 1:10:365
            tendaylai[i] = log(1 - dayfvc[day]) / (-kk)
            i += 1
        end
    
        # Calculate annual FPAR (%) from annual totals of APAR and PAR
        annualfpar = if annualapar == T(0.0) T(0.0) else T(100.0) * annualapar / annualparr end
    
        # Calculate annual respiration costs to find annual NPP
        npp, stemresp, percentcost, mstemresp, mrootresp, backleafresp = respiration(gpp, alresp, temp, sapwood, maxlai, monthlyfpar, pft, BIOME4PFTS)

        if wilt
            npp = -9999.0
        end
    
        # Calculate monthly NPP
        nppsum = T(0.0)
        # Calculate maintenance and growth respiration for months 1 to 11
        for m in 1:11
            maintresp[m] = mlresp[m] + backleafresp[m] + mstemresp[m] + mrootresp[m]
            mgrowresp[m] = T(0.02) * (mgpp[m + 1] - maintresp[m + 1])
            mgrowresp[m] = max(mgrowresp[m], T(0.0))
            mnpp[m] = mgpp[m] - (maintresp[m] + mgrowresp[m])
        end
    
        # Handle month 12 separately
        maintresp[12] = mlresp[12] + backleafresp[12] + mstemresp[12] + mrootresp[12]
        mgrowresp[12] = T(0.02) * (mgpp[1] - maintresp[1])
        mgrowresp[12] = max(mgrowresp[12], T(0.0))
        mnpp[12] = mgpp[12] - (maintresp[12] + mgrowresp[12])

        # Sum up monthly NPP and assign to c4mnpp if c4 is true
        for m in 1:12
            if c4
                c4mnpp[m] = mnpp[m]
            end
            nppsum += mnpp[m]
        end
    
        nppsum, c4pct, c4month, mnpp, annc4npp, monthlyfpar, monthlyparr, monthlyapar, CCratio, isoresp = compare_c3_c4_npp(
            pft, mnpp, c4mnpp, monthlyfpar, monthlyparr, monthlyapar, CCratio, isoresp, c4fpar, c4parr, c4apar, c4ccratio, c4leafresp, nppsum, c4, BIOME4PFTS)
    
        if get_characteristic(BIOME4PFTS.pft_list[pft], :name) == "C3C4WoodyDesert"
            if c4
                c4 = false
                c4_override = false
                reprocess = true
                continue
            end
        end
    
        if npp != nppsum
            npp = nppsum
        else
            npp = npp
        end
    
        if npp <= T(0.0)
            return T(npp), mnpp, c4mnpp
        end
    
        if gpp > 0.0 
            if get_characteristic(BIOME4PFTS.pft_list[pft], :grass) == true || get_characteristic(BIOME4PFTS.pft_list[pft], :name) == "C3_C4_woody_desert"
            #  calculate the phi term that is used in the C4 13C fractionation
            #  routines
                phi = calcphi(mgpp)
            end
            meanC3, meanC4, C3DA, C4DA = isotope(CCratio, ca, temp, isoresp, c4month, mgpp, phi, gpp)
        end
    
        Rlit, Rfst, Rslo, Rtot, isoR, isoflux, Rmean, meanKlit, meanKsoil = hetresp(pft, npp, temp, tsoil, meanaet, meanwr, meanC3, Rlit, Rfst, Rslo, Rtot, isoR, isoflux, Rmean, meanKlit, meanKsoil, BIOME4PFTS)

        annresp = sum(Rtot)
    
        annnep = 0.0
        cflux = zeros(T, 12)
        for m in 1:12
            cflux[m] = mnpp[m] - Rtot[m]
            annnep += cflux[m]
        end
    
        BIOME4PFTS = fire(wet, pft, maxlai, npp, BIOME4PFTS)
    
    
        return npp, mnpp, c4mnpp
    
end
end 

function compare_c3_c4_npp(
    pft::Int,
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
    c4::Bool,
    BIOME4PFTS::AbstractPFTList
) where {T <: Real}
    c4months = 0
    annc4npp = T(0.0)
    c4month = fill(false, 12)
    
    for m in 1:12
        if get_characteristic(BIOME4PFTS.pft_list[pft], :name) == "C4_tropical_grass"
            c4month[m] = true
        end
    end

    if get_characteristic(BIOME4PFTS.pft_list[pft], :name) == "C3_C4_woody_desert"
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
            mnpp[m] = c4mnpp[m]
            annc4npp += c4mnpp[m]
            monthlyfpar[m] = c4fpar[m]
            monthlyparr[m] = c4parr[m]
            monthlyapar[m] = c4apar[m]
            CCratio[m] = c4ccratio[m]
            isoresp[m] = c4leafresp[m]
        end
        totnpp += mnpp[m]
    end

    if c4months >= 2
        nppsum = totnpp
    end

    c4pct = (nppsum != 0) ? annc4npp / nppsum : T(0.0)

    return nppsum, c4pct, c4month, mnpp, annc4npp, monthlyfpar, monthlyparr, monthlyapar, CCratio, isoresp
end
