module Competition

include("./newassignbiome.jl")
using .BiomeAssignment
using LinearAlgebra: norm
using Statistics: mean
using Printf: @sprintf

"""
Competition submodule.
"""

struct CompetitionResults{T <: Real, U <: Int}
    biome::U
    output::AbstractArray{T}
end

function competition2(
    optnpp::AbstractArray{T},
    optlai::AbstractArray{T},
    tmin::T,
    tprec::T,
    pfts::AbstractArray{U}, 
    optdata,
    output,      
    diagmode::Bool,
    numofpfts::U,
    gdd0::T,
    gdd5::T,
    tcm::T,
    pftpar,
    soil::AbstractArray{T}   
)::CompetitionResults{T, U} where {T <: Real, U <: Int}

    # Initialize all of the variables that index an array
    optpft = U(0)
    subpft = U(0)
    grasspft = U(0)
    pftmaxnpp = U(0)
    pftmaxlai = U(0)
    dom = U(0)
    wdom = U(0)

    maxnpp = T(0.0)
    maxlai = T(0.0)
    grassnpp = T(0.0)

    present = initialize_presence(numofpfts, optnpp, pftpar)
    grass = [pftpar[pft].additional_params.grass == true for pft in 1:numofpfts]
    grass = vcat(grass, false)

    # Choose the dominant woody PFT on the basis of NPP - for all PFTs but lichen_forbs
    for pft in keys(pftpar)
        if pftpar[pft].name == "lichen_forb"
            continue  # Skip iteration for lichen_forbs
        end

        if grass[pft]
            if optnpp[pft+1] > grassnpp
                grassnpp = optnpp[pft+1]
                grasspft = pft
            end
        else
            if optnpp[pft+1] > maxnpp
                maxnpp = optnpp[pft+1]
                pftmaxnpp = pft
            end
            if optlai[pft+1] > maxlai
                maxlai = optlai[pft+1]
                pftmaxlai = pft
            elseif optlai[pft+1] == maxlai
                maxlai = optlai[pftmaxnpp+1]
                pftmaxlai = pftmaxnpp
            end
        end
    end

    # Find average annual soil moisture value for all PFTs
    wetlayer, drymonth, wettest, driest, wetness = calculate_soil_moisture(numofpfts, optdata)

    # Determine the subdominant woody PFT
    optpft, wdom, subpft, subnpp = determine_subdominant_pft(pftmaxnpp, optnpp, pftpar)

    # Determine the optimal PFT based on various conditions
    optpft, woodnpp, woodylai, greendays, grasslai, nppdif, wdom, subpft = determine_optimal_pft(
        optpft,
        wdom,
        subpft,
        optnpp,
        optlai,
        grasspft,
        tmin,
        gdd5,
        tcm,
        tprec,
        wetness,
        optdata,
        present,
        pftpar
    )

    # Output some diagnostics if diagmode is on
    if diagmode
        output_diagnostics(
            numofpfts,
            pfts,
            drymonth,
            driest,
            wetness,
            optdata,
            wdom,
            optnpp,
            optlai,
            grasspft,
            grassnpp,
            subpft
        )
    end

    # Format values for output
    dom, npp, lai, grasslai, optpft = format_values_for_output(
        optpft, wdom, grasspft, optnpp, optlai, grassnpp, optdata, woodnpp, woodylai, grasslai
    )

    # Call the newassignbiome function
    biome = BiomeAssignment.newassignbiome(
        optpft,
        wdom,
        subpft,
        npp,
        subnpp,
        greendays,
        gdd0,
        gdd5,
        tcm,
        present,
        woodylai,
        grasslai,
        tmin,
        pftpar
    )

    output = assign_output_values(
        output,
        dom,
        lai,
        npp,
        optlai,
        optnpp,
        grasspft,
        wetness,
        wetlayer,
        optdata,
        optpft,
        tprec,
        pftpar,
        wdom,
        tcm,
        gdd0,
        gdd5,
        subpft,
        nppdif
    )

    return CompetitionResults(biome, output)
end

function initialize_presence(numofpfts::Int, optnpp::AbstractVector{T}, pftpar)::Dict{String, Bool} where T <: Real

    # Initialize present dynamically based on optnpp
    present = Dict{String, Bool}()
    for pft in 1:numofpfts
        if optnpp[pft+1] > 0.0
            present[pftpar[pft].name] = true
        else
            present[pftpar[pft].name] = false
        end
    end
    present["cold_herbaceous"] = true # Special case

    return present
end


function calculate_soil_moisture(
    numofpfts::U,
    optdata::AbstractArray{T}
)::Tuple{AbstractArray{T}, Vector{U}, AbstractArray{T}, AbstractArray{T}, AbstractArray{T}} where {T <: Real, U <: Int}
    wetlayer = zeros(T, numofpfts+1, 2)
    drymonth = zeros(U, 15)
    wettest = fill(T(-1.0), numofpfts+1)
    driest = fill(T(101.0), numofpfts+1)
    wetness = zeros(T, numofpfts+1)

    for pft in 1:numofpfts
        wetness[pft+1] = T(0.0)
        wetlayer[pft+1, 1] = T(0.0)
        wetlayer[pft+1, 2] = T(0.0)
        drymonth[pft+1] = U(0)
        wettest[pft+1] = T(-1.0)
        driest[pft+1] = T(101.0)

        for m in 1:12
            mwet = optdata[pft+1, m + 412]
            wetness[pft+1] += (mwet / T(12.0))
            wetlayer[pft+1, 1] += optdata[pft+1, m + 412] / T(12.0)
            wetlayer[pft+1, 2] += optdata[pft+1, m + 424] / T(12.0)
            if mwet > wettest[pft+1]
                wettest[pft+1] = mwet
            end
            if mwet < driest[pft+1]
                drymonth[pft+1] = U(m)
                driest[pft+1] = mwet
            end
        end
    end

    return wetlayer, drymonth, wettest, driest, wetness
end

function determine_subdominant_pft(pftmaxnpp::U, optnpp::AbstractArray{T}, pftpar)::Tuple{U, U, U, T} where {T <: Real, U <: Int}
    optpft = pftmaxnpp
    wdom = optpft

    subnpp = T(0.0)
    subpft = U(0)

    for pft in keys(pftpar)
        if pft != wdom && (pftpar[pft].additional_params.grass == false && pftpar[pft].additional_params.grass == false && pftpar[pft].additional_params.c4 == false)
            if optnpp[pft+1] > subnpp
                subnpp = optnpp[pft+1]
                subpft = pft
            end
        end
    end

    return optpft, wdom, subpft, subnpp
end

function determine_optimal_pft(
    optpft::U,
    wdom::U,
    subpft::U,
    optnpp::AbstractArray{T},
    optlai::AbstractArray{T},
    grasspft::U,
    tmin::T,
    gdd5::T,
    tcm::T,
    tprec::T,
    wetness::AbstractArray{T},
    optdata::AbstractArray{},
    present::Dict{String, Bool},
    pftpar
)::Tuple{U, T, T, U, T, T, U, U} where {T <: Real, U <: Int}
    flop = false

    # Initialize variables
    woodylai = optlai[wdom+1]
    woodnpp = optnpp[wdom+1]
    grasslai = optlai[grasspft+1]
    firedays = optdata[wdom+1, 199]
    subfiredays = optdata[subpft+1, 199]
    greendays = optdata[wdom+1, 200]
    nppdif = optnpp[wdom+1] - optnpp[grasspft+1]
    
    while true
        # Update variables dynamically if wdom changes
        woodylai = optlai[wdom+1]
        woodnpp = optnpp[wdom+1]
        grasslai = optlai[grasspft+1]

        if wdom != 0
            firedays = optdata[wdom+1, 199]
            subfiredays = optdata[subpft+1, 199]
            greendays = optdata[wdom+1, 200]
        else
            firedays = 0
            subfiredays = 0
            greendays = 0
        end

        nppdif = optnpp[wdom+1] - optnpp[grasspft+1]

        # Mimicking Fortran conditions and goto-like behavior
        # if (wdom == 3 || wdom == 5) && tmin > T(0.0)
        if wdom != 0 && (pftpar[wdom].name == "temperate_broadleaved_evergreen" || pftpar[wdom].name == "cool_conifer") && tmin > T(0.0)
            if gdd5 > T(5000.0)
                wdom = find_index_by_name(pftpar, "tropical_drought_deciduous")
                continue
            end
        end

        # if wdom == 1
        if wdom != 0 && pftpar[wdom].name == "tropical_evergreen"
            if optnpp[wdom+1] < T(2000.0)
                wdom = find_index_by_name(pftpar, "tropical_drought_deciduous")
                subpft = find_index_by_name(pftpar, "tropical_evergreen")
                continue
            end
        end

        # if wdom == 2
        if wdom != 0 && pftpar[wdom].name == "tropical_drought_deciduous"
            if woodylai < T(2.0)
                optpft = grasspft
            elseif grasspft != 0 && pftpar[grasspft].name == "C4_tropical_grass" && woodylai < T(3.6)
                optpft = 14 # FIXME should we change this to numofpfts + 1?
            elseif greendays < 270 && tcm > T(21.0)&& tprec < T(1700.0)
                optpft = 14
            else
                optpft = wdom
            end
        end

        # if wdom == 3
        if wdom != 0 && pftpar[wdom].name == "temperate_broadleaved_evergreen"
            if optnpp[wdom+1] < T(140.0)
                optpft = grasspft
            elseif woodylai < T(1.0)
                optpft = grasspft
            elseif woodylai < T(2.0)
                optpft = 14
            else
                optpft = wdom
            end
        end

        # if wdom == 4
        if wdom != 0 && pftpar[wdom].name == "temperate_deciduous"
            if woodylai < T(2.0)
                optpft = grasspft
            elseif firedays > 210 && nppdif < 0.0
                if !flop && subpft != 0
                    wdom = subpft
                    subpft = find_index_by_name(pftpar, "temperate_deciduous")
                    flop = true
                    continue
                else
                    optpft = grasspft
                end
            elseif woodylai < T(3.0) || firedays > U(180)
                if nppdif < 0.0
                    optpft = 14
                elseif !flop && subpft != 0
                    wdom = subpft
                    subpft = find_index_by_name(pftpar, "temperate_deciduous")
                    flop = true
                    continue
                end
            else
                optpft = wdom
            end
        end

        # if wdom == 5
        if wdom != 0 && pftpar[wdom].name == "cool_conifer"
            if present["temperate_broadleaved_evergreen"]
                wdom = find_index_by_name(pftpar, "temperate_broadleaved_evergreen")
                subpft = find_index_by_name(pftpar, "cool_conifer")
                continue
            elseif optnpp[wdom+1] < T(140.0)
                optpft = grasspft
            elseif woodylai < T(1.2)
                optpft = 14
            else
                optpft = wdom
            end
        end

        # if wdom == 6
        if wdom != 0 && pftpar[wdom].name == "boreal_evergreen"
            if optnpp[wdom+1] < T(140.0)
                optpft = grasspft
            elseif firedays > U(90)
                if !flop && subpft != 0
                    wdom = subpft
                    subpft = find_index_by_name(pftpar, "boreal_evergreen")
                    flop = true
                    continue
                else
                    optpft = wdom
                end
            end
        end

        # if wdom == 7
        if wdom != 0 && pftpar[wdom].name == "boreal_deciduous"
            if optnpp[wdom+1] < T(120.0)
                optpft = grasspft
            elseif wetness[wdom+1] < T(30.0) && nppdif < T(0.0)
                optpft = grasspft
            else
                optpft = wdom
            end
        end

        if wdom == 0
            if grasspft != 0
                optpft = grasspft
            elseif optnpp[14] != 0.0
                optpft = find_index_by_name(pftpar, "lichen_forb")
            else
                optpft = 0
            end
        end

        if optpft == 0 && present["C3_C4_woody_desert"]
            optpft = find_index_by_name(pftpar, "C3_C4_woody_desert")
        end

        if optpft ∉ [0, 14] && pftpar[optpft].name == "C3_C4_woody_desert"
            index = find_index_by_name(pftpar, "C3_C4_woody_desert") # FIXME double check if this works
            if grasspft != 0 && pftpar[grasspft].name != "C4_tropical_grass" && optnpp[grasspft+1] > optnpp[index+1] 
                optpft = grasspft
            else
                optpft = find_index_by_name(pftpar, "C3_C4_woody_desert")
            end
        end

        if optpft == grasspft
            if optlai[grasspft+1] < 1.8 && present["C3_C4_woody_desert"]
                optpft = find_index_by_name(pftpar, "C3_C4_woody_desert")
            else
                optpft = grasspft
            end
        end

        if optpft ∉ [0, 14]  && pftpar[optpft].name == "tundra_shrubs"
            if wetness[optpft+1] <= 25.0 && present["cold_herbaceous"]
                optpft = find_index_by_name(pftpar, "cold_herbaceous")
            end
        end

        break
    end

    return optpft, woodnpp, woodylai, greendays, grasslai, nppdif, wdom, subpft
end



function output_diagnostics(
    numofpfts::U,
    pfts::AbstractArray{U},
    drymonth::AbstractArray{U},
    driest::AbstractArray{T},
    wetness::AbstractArray{T},
    optdata::AbstractArray{T},
    wdom::U,
    optnpp::AbstractArray{T},
    optlai::AbstractArray{T},
    grasspft::U,
    grassnpp::T,
    subpft::U
)::Nothing where {T <: Real, U <: Int}
    for pft in 1:numofpfts+1
        if pfts[pft] != 0
            println(@sprintf("%5d%5d%6.2f%6.2f%5d%5d",
                pft, drymonth[pft+1], driest[pft+1], wetness[pft+1], optdata[pft+1, 199], optdata[pft+1, 200]))
        end
    end

    woodylai = optlai[wdom+1]
    woodnpp = optnpp[wdom+1]

    println(" wpft  woodynpp   woodylai gpft grassnpp subpft phi")
    println(@sprintf("%5d%10.2f%10.2f%5d%10.2f%5d%8.2f",
    wdom, woodnpp, woodylai, grasspft, grassnpp, subpft, optdata[8, 52] / 100
    ))
end

function format_values_for_output(
    optpft::U,
    wdom::U,
    grasspft::U,
    optnpp::AbstractArray{T},
    optlai::AbstractArray{T},
    grassnpp::T,
    optdata::AbstractArray{},
    woodnpp,
    woodylai,
    grasslai,
)::Tuple{U, T, T, T, U} where {T <: Real, U <: Int}

    dom = optpft
    
    if optpft == 14

        npprat = woodnpp / grassnpp
        treepct = ((8.0 / 5.0) * npprat) - 0.54

        if treepct < 0.0
            treepct = 0.0
        end
        if treepct >= 1.0
            treepct = 1.0
        end

        grasspct = 1.0 - treepct
        dom = wdom

        lai = (woodylai + (2.0 * grasslai)) / 3.0
        npp = (woodnpp + (2.0 * grassnpp)) / 3.0

        for pos in 137:148
            optdata[dom+1, pos] = (optdata[wdom+1, pos] + (2.0 * optdata[grasspft+1, pos])) / 3.0
        end

        for pos in 80:91
            optdata[dom+1, pos] = (optdata[wdom+1, pos] + (2.0 * optdata[grasspft+1, pos])) / 3.0
        end

        for pos in 37:48
            optdata[dom+1, pos] = (optdata[wdom+1, pos] + (2.0 * optdata[grasspft+1, pos])) / 3.0
        end

        for pos in 123:124
            optdata[dom+1, pos] = (optdata[wdom+1, pos] + (2.0 * optdata[grasspft+1, pos])) / 3.0
        end

        optdata[dom+1, 50] = treepct * optdata[wdom+1, 50] + grasspct * optdata[grasspft+1, 50]
        optdata[dom+1, 98] = (optdata[wdom+1, 98] + (2.0 * optdata[grasspft+1, 98])) / 3.0
    end

    if optlai[dom+1] == 0.0
        optpft = 0
    end

    
    npp = optnpp[dom+1]
    lai = optlai[dom+1]
    grasslai = optlai[grasspft+1]


    return dom, npp, lai, grasslai, optpft
end

function assign_output_values(
    output::AbstractArray{},
    dom::U,
    lai::T,
    npp::T,
    optlai::AbstractArray{T},
    optnpp::AbstractArray{T},
    grasspft::U,
    wetness::AbstractArray{T},
    wetlayer::AbstractArray{T},
    optdata::AbstractArray{},
    optpft::U,
    tprec::T,
    pftpar,
    wdom::U,
    tcm::T,
    gdd0::T,
    gdd5::T,
    subpft,
    nppdif
)::AbstractArray{T} where {T <: Real, U <: Int}
    output[2] = round(lai * 100.0)
    output[3] = round(npp)
    output[4] = round(optlai[wdom+1] * 100.0)
    output[5] = round(optnpp[wdom+1])
    output[6] = round(optlai[grasspft+1] * 100.0)
    output[7] = round(optnpp[grasspft+1])

    # Annual APAR / annual PAR expressed as a percentage:
    output[8] = optdata[dom+1, 8]

    # Respiration costs (for dom plant type, wood or grass):
    output[9] = optdata[dom+1, 9]

    # Soil moisture for dominant pft:
    output[10] = round(wetness[dom+1] * 10.0)

    # Predicted runoff (for dom plant type, wood or grass):
    output[11] = optdata[wdom+1, 6]

    # Number of the dominant (woody) pft:
    output[12] = optpft

    # Total annual precipitation (hopefully < 9999mm):
    output[13] = min(round(tprec), 9999)

    # Total annual PAR MJ.m-2.yr-1
    output[14] = optdata[dom+1, 7]

    # lairatio is estimated, the original code does not say where it is from
    output[15] = 0.0 # optlai[dom+1] != 0 ? round(100.0 * (lai / optlai[dom+1])) : 0
    output[16] = nppdif

    if lai < 2.0
        output[17] = round((lai / 2.0) * 100.0)
    else
        output[17] = 100
    end

    output[18] = dom == 0 ? 0.0 : round(pftpar[dom].main_params.root_fraction_top_soil * 100.0)

    for month in 1:12
        output[24 + month] = optdata[dom+1, 24 + month]
    end

    # total deltaA
    output[50] = optdata[dom+1, 50] / 10.0
    # Average delaA for mixed ecosystems
    output[51] = optdata[dom+1, 51]
    # phi value
    output[52] = optdata[8+1, 52]

    # Optimized NPP for all PFTs
    for i in 1:14
        output[59 + i] = optnpp[i]
    end

    # monthly discrimination for one pft
    for pos in 80:91
        output[pos] = optdata[dom+1, pos]
    end

    # monthly npp, one pft
    for pos in 37:48
        output[pos] = optdata[dom+1, pos]
    end

    # monthly delta e, dominant PFT
    for pos in 101:112
        output[pos] = optdata[dom+1, pos]
    end

    # monthly het resp, dom pft
    for pos in 113:124
        output[pos] = optdata[dom+1, pos]
    end

    # monthly isoresp (product)
    for pos in 125:136
        output[pos] = optdata[dom+1, pos]
    end

    # monthly net C flux (npp-resp)
    for pos in 137:148
        output[pos] = optdata[dom+1, pos]
    end

    # monthly mean gc
    for pos in 160:172
        output[pos] = optdata[dom+1, pos]
    end

    # monthly LAI
    for pos in 173:184
        output[pos] = optdata[dom+1, pos]
    end

    # monthly runoff
    for pos in 185:196
        output[pos] = optdata[dom+1, pos]
    end

    # Annual NEP
    output[149] = optdata[dom+1, 149]
    # Annual mean A/g
    output[150] = optdata[dom+1, 150]
    # Mean annual hetresp scalar
    output[97] = optdata[dom+1, 97]
    # pct of NPP that is C4
    output[98] = optdata[dom+1, 98]
    # annual het resp
    output[99] = optdata[dom+1, 99]
    # firedays
    output[199] = optdata[wdom+1, 199]
    # greendays
    output[200] = optdata[dom+1, 200]

    # Ten-day LAI * 100
    for pos in 201:241
        output[pos] = optdata[dom+1, pos]
    end

    for pos in 389:400
        output[pos] = optdata[dom+1, pos - 376]
    end

    for pos in 413:424
        output[pos] = optdata[dom+1, pos]
    end

    for pos in 425:436
        output[pos] = optdata[dom+1, pos]
    end

    output[425] = round(wetlayer[dom+1, 1])
    output[426] = round(wetlayer[dom+1, 2])
    output[427] = 0.0 # wetlayer[dom+1, 2] != 0 ? round((wetlayer[dom+1, 1] / wetlayer[dom+1, 2]) * 100.0) : 0

    output[450] = optdata[dom+1, 450]
    output[451] = optdata[dom+1, 451]
    output[452] = tcm
    output[453] = gdd0
    output[454] = gdd5
    output[455] = subpft

    return output
end

function find_index_by_name(pftpar, target_name)
    for (key, element) in pairs(pftpar)
        if element.name == target_name
            return key
        end
    end
    return nothing  # Return nothing if the name is not found
end

end # module Competition
