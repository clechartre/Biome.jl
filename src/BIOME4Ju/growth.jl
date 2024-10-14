module Growth

include("./growth_subroutines/c4photo.jl")
include("./growth_subroutines/calcphi.jl")
include("./growth_subroutines/daily.jl")
include("./growth_subroutines/fire.jl")
include("./growth_subroutines/hetresp.jl")
include("./growth_subroutines/hydrology.jl")
include("./growth_subroutines/isotope.jl")
include("./growth_subroutines/photosynthesis.jl")
include("./growth_subroutines/respiration.jl")

using .C4Photosynthesis
using .CalcPhi
using .Daily
using .FireCalculation
using .HeterotrophicRespiration
using .Hydrology
using .Isotopes
using .Photosynthesis
using .Respiration
using Statistics: mean

struct GrowthResults
    npp::Float64
    outv::Vector{Int}
    realin::Vector{Int}
end

function safe_exp(x::Float64)::Float64
    try
        return exp(x)
    catch e
        return Inf
    end
end

function safe_round_to_int(x::Float64)::Int64
    if isnan(x)
        return 0
    elseif x > typemax(Int64)
        return typemax(Int64)
    elseif x < typemin(Int64)
        return typemin(Int64)
    else
        return round(Int, x)
    end
end


function initialize_arrays()::Tuple{Vector{Int}, Vector{Int}, Vector{Float64}, Vector{Float64}}
    midday = [16, 44, 75, 105, 136, 166, 197, 228, 258, 289, 319, 350]
    days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    optratioa = [0.95, 0.9, 0.8, 0.8, 0.9, 0.8, 0.9, 0.65, 0.65, 0.70, 0.90, 0.75, 0.80]
    kk = [0.7, 0.7, 0.6, 0.6, 0.5, 0.5, 0.4, 0.4, 0.4, 0.3, 0.5, 0.3, 0.6]
    return midday, days, optratioa, kk
end

function determine_c4_and_optratio(pft::Int, optratioa::AbstractArray{Float64})::Tuple{Bool, Float64}
    c4 = (pft in [9, 10])
    optratio = c4 ? 0.4 : optratioa[pft]
    return c4, optratio
end

function growth(
    maxlai::Float64,
    annp::Float64,
    sun::AbstractArray{Float64},
    temp::AbstractArray{Float64},
    dprec::AbstractArray{Float64},
    dmelt::AbstractArray{Float64},
    dpet::AbstractArray{Float64},
    k::AbstractArray{Float64},
    pftpar::AbstractArray{Float64, 2},
    pft::Int,
    dayl::AbstractArray{Float64},
    dtemp::AbstractArray{Float64},
    outv::Vector{Int},
    dphen::AbstractArray{Float64},
    co2::Real,
    p::Real,
    tsoil::AbstractArray{Float64},
    realin::Vector{},
)::GrowthResults
    # Initialize the arrays and set values
    midday, days, optratioa, kk = initialize_arrays()
    ca = co2 * 1e-6
    rainscalar = 1000.0
    wst = annp / rainscalar
    wst = min(wst, 1.0)
    phentype = round(Int, pftpar[pft,1])
    mgmin = pftpar[pft,2]
    root = pftpar[pft,6]
    age = pftpar[pft, 7]
    c4pot = pftpar[pft, 11]
    grass = round(Int, pftpar[pft, 10])
    emax = pftpar[pft,3]
    maxfvc = 1.0 - exp(-kk[pft] * maxlai)
    fpar = 1.0 - exp(-kk[pft] * maxlai)
    phi = 0.0
    doptgc = [0.0 for _ in 1:12]

    # Set the value of optratio depending on whether c4 plant or not.
    c4, optratio = determine_c4_and_optratio(pft, optratioa)

    # Calculate monthly values for the optimum non-water-stressed gc (optgc)
    maxgc = 0.0
    optgc = [0.0 for _ in 1:12]
    
    # Initialize the array to store photosynthesis results
    if c4
        photosynthesis_results_list = Vector{typeof(C4Photosynthesis.c4photo(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1))}(undef, 12)
    else
        photosynthesis_results_list = Vector{typeof(Photosynthesis.photosynthesis(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1))}(undef, 12)
    end

    for m in 1:12
        tsecs = 3600.0 * dayl[m]
        fpar = 1.0 - exp(-kk[pft] * maxlai)
        
        if c4
            photosynthesis_results_list[m] = C4Photosynthesis.c4photo(optratio, sun[m], dayl[m], temp[m], age, fpar, p, ca, pft)
        else

            photosynthesis_results_list[m] = Photosynthesis.photosynthesis(optratio, sun[m], dayl[m], temp[m], age, fpar, p, ca, pft)
        end

        if tsecs > 0.0 && photosynthesis_results_list[m].aday > 0.0
            gt = mgmin + (1.6 * photosynthesis_results_list[m].aday) / (ca * (1.0 - optratio)) / tsecs
        else
            gt = 0.0
        end

        # This gives us the final non-water-stressed gc value
        optgc[m] = gt

        # Store output values:
        maxgc = max(maxgc, optgc[m])
    end

    # Call the hydrology function with the necessary parameters
    hydrology_results = Hydrology.hydrology(
        dprec, dmelt, dpet, root, k, maxfvc, pft, phentype, wst, optgc, mgmin, dphen, dtemp, grass, emax, pftpar
    )

    # Initialize lists to store monthly values
    mgpp = zeros(Float64, 12)
    mlresp = zeros(Float64, 12)
    monthlyfpar = zeros(Float64, 12)
    monthlyparr = zeros(Float64, 12)
    monthlyapar = zeros(Float64, 12)
    CCratio = zeros(Float64, 12)
    isoresp = zeros(Float64, 12)

    c4gpp = zeros(Float64, 12)
    c4fpar = zeros(Float64, 12)
    c4parr = zeros(Float64, 12)
    c4apar = zeros(Float64, 12)
    c4ccratio = zeros(Float64, 12)
    c4leafresp = zeros(Float64, 12)

    # Initialize annual variables
    alresp = 0.0
    gpp = 0.0
    annualparr = 0.0
    annualapar = 0.0
    gphot = 0.0
    leafresp = 0.0

    for m in 1:12
        # If meangc is zero then photosynthesis must also be zero
        if hydrology_results.meangc[m] == 0.0
            gphot = 0.0
            rtbis = 0.0
            leafresp = photosynthesis_results_list[m].leafresp * (hydrology_results.meanfvc[m] / maxfvc)
        else
            # Iterate to a solution for gphot given this meangc value using bisection method
            x1 = 0.02
            x2 = optratio + 0.05
            rtbis = x1
            dx = x2 - x1
            for j in 1:10
                dx *= 0.5
                xmid = rtbis + dx
                fpar = hydrology_results.meanfvc[m]

                if c4
                    photosynthesis_results_list[m] = C4Photosynthesis.c4photo(xmid, sun[m], dayl[m], temp[m], age, fpar, p, ca, pft)
                else
                    photosynthesis_results_list[m] = Photosynthesis.photosynthesis(xmid, sun[m], dayl[m], temp[m], age, fpar, p, ca, pft)
                end

                gt = 3600 * dayl[m] * hydrology_results.meangc[m]

                ap = if gt == 0.0 0.0 else mgmin + (gt / 1.6) * (ca * (1.0 - xmid)) end

                fmid = photosynthesis_results_list[m].aday - ap

                if fmid <= 0.0
                    rtbis = xmid
                    gphot = photosynthesis_results_list[m].grossphot
                end
            end

            # leafresp = photosynthesis_results_list[m].leafresp * (hydrology_results.meanfvc[m] / maxfvc)
        end

        # Calculate monthly PAR values
        monthlyfpar[m] = hydrology_results.meanfvc[m]
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
    monthlylai = [log(1 - monthlyfpar[m]) / (-kk[pft]) for m in 1:12]

    # Calculate 10-day LAI
    tendaylai = zeros(Float64, 40)  # Initialize a vector of size 40
    i = 1
    for day in 1:10:365
        tendaylai[i] = log(1 - hydrology_results.dayfvc[day]) / (-kk[pft])
        i += 1
    end

    # Calculate annual FPAR (%) from annual totals of APAR and PAR
    annualfpar = if annualapar == 0.0 0.0 else 100.0 * annualapar / annualparr end

    # Calculate annual respiration costs to find annual NPP
    respiration_results = Respiration.respiration(gpp, alresp, temp, grass, maxlai, fpar, pft)

    if hydrology_results.wilt
        npp = -9999.0
    end

    # Calculate monthly NPP
    nppsum = 0.0
    mnpp = zeros(Float64, 12)
    c4mnpp = zeros(Float64, 12)

    # Calculate maintenance and growth respiration for months 1 to 11
    maintresp = zeros(Float64, 12)
    mgrowresp = zeros(Float64, 12)
    for m in 1:11
        maintresp[m] = mlresp[m] + respiration_results.backleafresp[m] + respiration_results.mstemresp[m] + respiration_results.mrootresp[m]
        mgrowresp[m] = 0.02 * (mgpp[m + 1] - maintresp[m + 1])
        mgrowresp[m] = max(mgrowresp[m], 0.0)
        mnpp[m] = mgpp[m] - (maintresp[m] + mgrowresp[m])
    end

    # Calculate maintenance and growth respiration for month 12
    maintresp[12] = mlresp[12] + respiration_results.backleafresp[12] + respiration_results.mstemresp[12] + respiration_results.mrootresp[12]
    mgrowresp[12] = 0.02 * (mgpp[1] - maintresp[1])
    mgrowresp[12] = max(mgrowresp[12], 0.0)
    mnpp[12] = mgpp[12] - (maintresp[12] + mgrowresp[12])

    for m in 1:12
        if c4
            c4mnpp[m] = mnpp[m]
        end
        nppsum += mnpp[m]
    end

    #  If this is a temperate grass or desert shrub pft, compare both
    #  C3 and C4 NPP and choose the more productive one on a monthly basis. 
    #  However the C4 advantage period must be for at least two months 
    #  (ie. long enough to complete a life cycle).

    nppsum, c4pct, c4month = compare_c3_c4_npp(pft,mnpp,c4mnpp,monthlyfpar,monthlyparr,monthlyapar,CCratio,isoresp,c4fpar,c4parr,c4apar,c4ccratio,c4leafresp,nppsum,c4)

    if respiration_results.npp != nppsum
        npp = nppsum
    else
        npp = respiration_results.npp
    end

    if npp <= 0.0
        return GrowthResults(npp, outv, realin)
    end


    # Initialize an empty isotope_results object 
    isotope_results = Isotopes.IsotopeResult(0.0, 0.0, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])

    if gpp > 0.0 
        if pft >= 8
        #  calculate the phi term that is used in the C4 13C fractionation
        #  routines
            phi = CalcPhi.calcphi(mgpp)
        end
        isotope_results = Isotopes.isotope(CCratio, ca, temp, isoresp, c4month, mgpp, phi, gpp)
    end

    moist = map(mean, hydrology_results.meanwr)
    hetresp_results = HeterotrophicRespiration.hetresp(pft, npp, temp, tsoil, hydrology_results.meanaet, moist, isotope_results.meanC3)

    annresp = sum(hetresp_results.Rtot)

    annnep = 0.0
    cflux = zeros(Float64, 12)
    for m in 1:12
        cflux[m] = mnpp[m] - hetresp_results.Rtot[m]
        annnep += cflux[m]
    end

    fire_results = FireCalculation.fire(hydrology_results.wet, pft, maxlai, npp)

    outv, realin = output_results(
        hydrology_results.meanwr,
        monthlyfpar,
        npp,
        hydrology_results.annaet,
        maxgc,
        respiration_results.stemresp,
        hydrology_results.runnoff,
        annualparr,
        annualfpar,
        respiration_results.percentcost,
        isotope_results.meanC3,
        isotope_results.meanC4,
        phi,
        hetresp_results.Rmean,
        c4pct,
        annresp,
        mnpp,
        isotope_results.C3DA,
        hetresp_results.isoR,
        hetresp_results.Rtot,
        hetresp_results.isoflux,
        cflux,
        hydrology_results.meangc,
        monthlylai,
        hydrology_results.runoffmonth,
        mgpp,
        annnep,
        fire_results.firedays,
        hydrology_results.greendays,
        tendaylai,
        hetresp_results.meanKlit,
        hetresp_results.meanKsoil,
        outv,
        realin
    )

    return GrowthResults(npp, outv, realin)
end


function compare_c3_c4_npp(
    pft::Int,
    mnpp::AbstractArray{Float64},
    c4mnpp::AbstractArray{Float64},
    monthlyfpar::AbstractArray{Float64},
    monthlyparr::AbstractArray{Float64},
    monthlyapar::AbstractArray{Float64},
    CCratio::AbstractArray{Float64},
    isoresp::AbstractArray{Float64},
    c4fpar::AbstractArray{Float64},
    c4parr::AbstractArray{Float64},
    c4apar::AbstractArray{Float64},
    c4ccratio::AbstractArray{Float64},
    c4leafresp::AbstractArray{Float64},
    nppsum::Float64,
    c4::Bool
)::Tuple{Float64, Float64, Vector{Bool}}
    c4months = 0
    annc4npp = 0.0

    c4month = fill(false, 12)
    
    if pft == 9
        c4month .= true
    end

    if pft == 10
        if c4
            c4 = false
            # Recompute everything with C3 pathway
            return compare_c3_c4_npp(pft,mnpp,c4mnpp,monthlyfpar,monthlyparr,monthlyapar,CCratio,isoresp,c4fpar,c4parr,c4apar,c4ccratio,c4leafresp,nppsum,c4)
        end
        
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

    totnpp = 0.0

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

    c4pct = (nppsum > 0) ? annc4npp / nppsum : 0.0

    return nppsum, c4pct, c4month
end


function output_results(
    meanwr,
    monthlyfpar,
    npp,
    annaet,
    maxgc,
    stemresp,
    runoff,
    annualparr,
    annualfpar,
    fr,
    isoC3,
    isoC4,
    phi,
    Rmean,
    c4pct,
    annresp,
    mnpp,
    C3DA,
    riso,
    rtot,
    riflux,
    cflux,
    meangc,
    monthlylai,
    runoffmo,
    mgpp,
    annnep,
    firedays,
    greendays,
    tendaylai,
    meanKlit,
    meanKsoil,
    outv,
    realin
)::Tuple{Vector{Int}, Array{Float64,1}}
    anngasum = 0.0
    mcount = 0

    for m in 1:12
        outv[12 + m] = safe_round_to_int(100 * meanwr[m][1])
        outv[412 + m] = safe_round_to_int(100 * meanwr[m][2])
        outv[424 + m] = safe_round_to_int(100 * meanwr[m][3])
        outv[24 + m] = safe_round_to_int(100 * monthlyfpar[m])
    end

    outv[1] = safe_round_to_int(npp)
    outv[3] = safe_round_to_int(annaet)
    outv[4] = safe_round_to_int(maxgc)
    outv[5] = safe_round_to_int(stemresp)
    outv[6] = safe_round_to_int(runoff)
    outv[7] = safe_round_to_int(annualparr)
    outv[8] = safe_round_to_int(annualfpar)
    outv[9] = safe_round_to_int(fr)
    outv[50] = safe_round_to_int(isoC3 * 10)
    outv[51] = safe_round_to_int(isoC4 * 10)
    outv[52] = safe_round_to_int(phi * 100)
    outv[97] = safe_round_to_int(Rmean * 100)
    outv[98] = safe_round_to_int(c4pct * 100)
    outv[99] = safe_round_to_int(annresp * 10)

    for m in 1:12
        realin[36 + m] = safe_round_to_int(mnpp[m])
        outv[79 + m] = safe_round_to_int(C3DA[m] * 100)
        outv[36 + m] = safe_round_to_int(mnpp[m] * 10)
        outv[100 + m] = safe_round_to_int(riso[m] * 10)
        outv[112 + m] = safe_round_to_int(rtot[m] * 10)
        outv[124 + m] = safe_round_to_int(riflux[m] * 10)
        outv[136 + m] = safe_round_to_int(cflux[m] * 10)
        outv[160 + m] = safe_round_to_int(meangc[m])
        outv[172 + m] = safe_round_to_int(monthlylai[m] * 100)
        outv[184 + m] = safe_round_to_int(runoffmo[m])

        if meangc[m] != 0
            mcount += 1
            anngasum += mgpp[m] / meangc[m]
        end
    end

    outv[150] = (mcount != 0) ? safe_round_to_int((anngasum / mcount) * 100) : 0
    outv[149] = safe_round_to_int(annnep * 10)
    outv[199] = safe_round_to_int(firedays)
    outv[200] = greendays

    # for i in 1:40 # if debugging used to be 37
    #     outv[200 + i + 1] = safe_round_to_int(tendaylai[i] * 100)
    # end

    outv[450] = safe_round_to_int(meanKlit * 100)
    outv[451] = safe_round_to_int(meanKsoil * 100)

    return outv, realin
end

end # module

