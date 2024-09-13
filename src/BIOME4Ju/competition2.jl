module Competition

include("./newassignbiome.jl")
using .BiomeAssignment
using LinearAlgebra: norm
using Statistics: mean
using Printf: @sprintf

"""
Competition submodule.
"""

struct CompetitionResults
    biome::Int
    output::AbstractArray{Float64}
end

function competition2(
    optnpp::AbstractArray{Float64},
    optlai::AbstractArray{Float64},
    tmin::Float64,
    tprec::Float64,
    pfts::AbstractArray{Int64}, 
    optdata,     # No typing for now
    output,      
    diagmode::Bool,
    numofpfts::Int,
    gdd0::Float64,
    gdd5::Float64,
    tcm::Float64,
    pftpar::AbstractArray{Float64, 2},
    soil::AbstractArray{Float64}   
)::CompetitionResults

    # Initialize all of the variables that index an array
    # Keep the value but add 1 when using as index
    # Beware because it is both a variable AND an index 
    # This micmac is a flaw of the original Fortran model that uses both 0 and 1-indexing
    # We highly discourage this practice
    optpft = 0      
    subpft = 0      
    grasspft = 0    
    pftmaxnpp = 0
    pftmaxlai = 0
    dom = 0
    wdom = 0

    maxnpp = 0.0
    maxlai = 0.0
    grassnpp = 0.0

    grass, present = initialize_presence(numofpfts, optnpp)

    # Choose the dominant woody PFT on the basis of NPP
    for pft in 1:numofpfts
        if grass[pft+1] == true
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
    optpft, wdom, subpft, subnpp = determine_subdominant_pft(pftmaxnpp, optnpp)

    # Determine the optimal PFT based on various conditions
    optpft, woodnpp, woodylai, greendays, grasslai, nppdif = determine_optimal_pft(
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
        present
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
    dom, npp, lai, grasslai = format_values_for_output(
        optpft, wdom, grasspft, optnpp, optlai, grassnpp, optdata
    )

    # Call the newassignbiome function
    biome = BiomeAssignment.newassignbiome(
        optpft,
        wdom,
        grasspft,
        subpft,
        npp,
        woodnpp,
        grassnpp,
        subnpp,
        greendays,
        gdd0,
        gdd5,
        tcm,
        present,
        woodylai,
        grasslai,
        tmin
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

function initialize_presence(numofpfts::Int, optnpp::AbstractArray{Float64})::Tuple{Vector{Bool}, Vector{Bool}}
    present = falses(numofpfts+1)
    grass = falses(numofpfts+1)

    for pft in 1:numofpfts
        if pft >= 8
            grass[pft+1] = true
        end

        if optnpp[pft+1] > 0.0
            present[pft+1] = true
        end

    end

    grass[10+1] = false
    present[12+1] = true

    return grass, present
end



function calculate_soil_moisture(numofpfts::Int, optdata::AbstractArray{})::Tuple{AbstractArray{Float64}, Vector{Int}, AbstractArray{Float64}, AbstractArray{Float64}, AbstractArray{Float64}}
    wetlayer = zeros(Float64, numofpfts+1, 2)
    drymonth = zeros(Int, 15)
    wettest = fill(-1.0, numofpfts+1)
    driest = fill(101.0, numofpfts+1)
    wetness = zeros(Float64, numofpfts+1)

    for pft in 1:numofpfts
        wetness[pft+1] = 0.0
        wetlayer[pft+1, 1] = 0.0
        wetlayer[pft+1, 2] = 0.0
        drymonth[pft+1] = 0
        wettest[pft+1] = -1.0
        driest[pft+1] = 101.0

        for m in 1:12
            mwet = optdata[pft+1, m + 412]
            wetness[pft+1] += (mwet / 12.0)
            wetlayer[pft+1, 1] += optdata[pft+1, m + 412] / 12.0  # top
            wetlayer[pft+1, 2] += optdata[pft+1, m + 424] / 12.0  # bottom
            if mwet > wettest[pft+1]
                wettest[pft+1] = mwet
            end
            if mwet < driest[pft+1]
                drymonth[pft+1] = m
                driest[pft+1] = mwet
            end
        end
    end

    return wetlayer, drymonth, wettest, driest, wetness
end

function determine_subdominant_pft(pftmaxnpp::Int, optnpp::AbstractArray{Float64})::Tuple{Int, Int, Int, Float64}
    optpft = pftmaxnpp
    wdom = optpft

    subnpp = 0.0
    subpft = 0.0

    for pft in 1:7
        if pft != wdom
            if optnpp[pft+1] > subnpp
                subnpp = optnpp[pft+1]
                subpft = pft
            end
        end
    end

    return optpft, wdom, subpft, subnpp
end

function determine_optimal_pft(
    optpft::Int,
    wdom::Int,
    subpft::Int,
    optnpp::AbstractArray{Float64},
    optlai::AbstractArray{Float64},
    grasspft::Int,
    tmin::Float64,
    gdd5::Float64,
    tcm::Float64,
    tprec::Float64,
    wetness::AbstractArray{Float64},
    optdata::AbstractArray{},
    present::Vector{Bool}
)::Tuple{Int, Float64, Float64, Int, Float64,Float64}
    flop = false
    nppdif = 0

    # Initialize, else I get an error
    woodylai = optlai[wdom+1]
    woodnpp = optnpp[wdom+1]
    grasslai = optlai[grasspft+1]
    
    firedays = optdata[wdom+1, 199]
    subfiredays = optdata[subpft+1, 199]
    greendays = optdata[wdom+1, 200] 

    while true
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
        ratio = 0.0

        if (wdom == 3 || wdom == 5) && tmin > 0.0
            if gdd5 > 5000.0
                wdom = 2
                continue
            end
        end

        if wdom == 1
            if optnpp[wdom+1] < 2000.0
                wdom = 2
                subpft = 1
                continue
            end
        end

        if wdom == 2
            if woodylai < 2.0
                optpft = grasspft
            elseif grasspft == 9 && woodylai < 3.6
                optpft = 14
            elseif greendays < 270 && tcm > 21.0 && tprec < 1700.0
                optpft = 14
            else
                optpft = wdom
            end
        end

        if wdom == 3
            if optnpp[wdom+1] < 140.0
                optpft = grasspft
            elseif woodylai < 1.0
                optpft = grasspft
            elseif woodylai < 2.0
                optpft = 14
            else
                optpft = wdom
            end
        end

        if wdom == 4
            if woodylai < 2.0
                optpft = grasspft
            elseif firedays > 210 && nppdif < 0.0
                if !flop && subpft != 0
                    wdom = subpft
                    subpft = 4
                    flop = true
                    continue
                else
                    optpft = grasspft
                end
            elseif woodylai < 3.0 || firedays > 180
                if nppdif < 0.0
                    optpft = 14
                elseif !flop && subpft != 0
                    wdom = subpft
                    subpft = 4
                    flop = true
                    continue
                end
            else
                optpft = wdom
            end
        end

        if wdom == 5
            if present[3+1]
                wdom = 3
                subpft = 5
                continue
            elseif optnpp[wdom+1] < 140.0
                optpft = grasspft
            elseif woodylai < 1.2
                optpft = 14
            else
                optpft = wdom
            end
        end

        if wdom == 6
            if optnpp[wdom+1] < 140.0
                optpft = grasspft
            elseif firedays > 90
                if !flop && subpft != 0
                    wdom = subpft
                    subpft = 6
                    flop = true
                    continue
                else
                    optpft = wdom
                end
            end
        end

        if wdom == 7
            if optnpp[wdom+1] < 120.0
                optpft = grasspft
            elseif wetness[wdom+1] < 30.0 && nppdif < 0.0
                optpft = grasspft
            else
                optpft = wdom
            end
        end

        if wdom == 0
            if grasspft != 0
                optpft = grasspft
            elseif optnpp[13+1] != 0.0
                optpft = 13
            else
                optpft = 0
            end
        end

        if optpft == 0 && present[10+1]
            optpft = 10
        end

        if optpft == 10
            if grasspft != 9 && optnpp[grasspft+1] > optnpp[10+1]
                optpft = grasspft
            else
                optpft = 10
            end
        end

        if optpft == grasspft
            if optlai[grasspft+1] < 1.8 && present[10+1]
                optpft = 10
            else
                optpft = grasspft
            end
        end

        if optpft == 11
            if wetness[optpft+1] <= 25.0 && present[12+1]
                optpft = 12
            end
        end

        break
    end

    return optpft, woodnpp, woodylai, greendays, grasslai, nppdif
end

function output_diagnostics(
    numofpfts::Int,
    pfts::AbstractArray{Int},
    drymonth::AbstractArray{Int},
    driest::AbstractArray{Float64},
    wetness::AbstractArray{Float64},
    optdata::AbstractArray{Float64},
    wdom::Int,
    optnpp::AbstractArray{Float64},
    optlai::AbstractArray{Float64},
    grasspft::Int,
    grassnpp::Float64,
    subpft::Int
)::Nothing
    for pft in 1:numofpfts+1
        if pfts[pft] != 0
            println(@sprintf("%5d%5d%6.2f%6.2f%5d%5d",
                pft, drymonth[pft+1], driest[pft+1], wetness[pft+1], optdata[pft+1, 199], optdata[pft+1, 200]
            ))
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
    optpft::Int,
    wdom::Int,
    grasspft::Int,
    optnpp::AbstractArray{Float64},
    optlai::AbstractArray{Float64},
    grassnpp::Float64,
    optdata::AbstractArray{}
)::Tuple{Int, Float64, Float64, Float64}

    dom = optpft
    
    if optpft == 14
        woodnpp = optnpp[wdom+1]
        woodylai = optlai[wdom+1]
        grasslai = optlai[grasspft+1]

        npprat = woodnpp / grassnpp
        treepct = ((8.0 / 5.0) * npprat) - 0.54

        if treepct < 0.0
            treepct = 0.0
        end
        if treepct > 1.0
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

    if optpft != 14
        npp = optnpp[dom+1]
        lai = optlai[dom+1]
        grasslai = optlai[grasspft+1]
    end

    return dom, npp, lai, grasslai
end

function assign_output_values(
    output::AbstractArray{},
    dom::Int,
    lai::Float64,
    npp::Float64,
    optlai::AbstractArray{Float64},
    optnpp::AbstractArray{Float64},
    grasspft::Int,
    wetness::AbstractArray{Float64},
    wetlayer::AbstractArray{Float64},
    optdata::AbstractArray{},
    optpft::Int,
    tprec::Float64,
    pftpar::AbstractArray{Float64},
    wdom::Int,
    tcm::Float64,
    gdd0::Float64,
    gdd5::Float64,
    subpft,
    nppdif
)::AbstractArray{Float64}
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

    output[18] = dom == 0 ? 0.0 : round(pftpar[dom, 6] * 100.0)

    for month in 1:12
        output[24 + month] = optdata[dom+1, 24 + month]
    end

    # total deltaA
    output[50] = optdata[dom+1, 50] / 10.0
    # Average delaA for mixed ecosystems
    output[51] = optdata[dom+1, 51]
    # phi value
    output[52] = optdata[8, 52]

    # Optimized NPP for all PFTs
    for i in 1:13
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

end # module Competition
