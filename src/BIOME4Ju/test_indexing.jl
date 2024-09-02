
# Adapted version for both types of indexing

for pft in 1:numofpfts # 1 indexing 
    for pft_0_index in 0:numofpfts
        optlai[pft_0_index+1] = 0
        optlai[pft_0_index+1] = 0
    if pfts[pft] != 0
        if pftpar[pft][1] >= 2
            # Initialize the generic summergreen phenology
            dphen = Phenology.phenology(dtemp, temp, climate_results.cold, ts, tmin, pft, ppeett_results.ddayl, pftpar)
        end
            # Assumed that annp = annual precipitation and subbed by tprec (total precipitation)
            optdata, optlai[pft_0_index+1], optnpp[pft_0_index+1], realin = FindNPP.findnpp(
                pfts,
                pft,
                pft_0_index,
                optlai[pft_0_index+1],
                optnpp[pft_0_index+1],
                tprec,
                dtemp,
                ppeett_results.sun,
                temp,
                snow_results.dprec,
                snow_results.dmelt,
                ppeett_results.dpet,
                ppeett_results.dayl,
                k,
                pftpar,
                optdata,
                dphen,
                co2,
                p,
                tsoil,
                realout,
                numofpfts
            )
        end
    end



# Original one 
 for pft in 1:numofpfts
        optlai[pft] = 0
        optnpp[pft] = 0
    if pfts[pft] != 0
            if pftpar[pft][1] >= 2
                # Initialize the generic summergreen phenology
                dphen = Phenology.phenology(dtemp, temp, climate_results.cold, ts, tmin, pft, ppeett_results.ddayl, pftpar)
            end

            # Assumed that annp = annual precipitation and subbed by tprec (total precipitation)
            optdata, optlai[pft], optnpp[pft], realin = FindNPP.findnpp(
                pfts,
                pft,
                optlai[pft],
                optnpp[pft],
                tprec,
                dtemp,
                ppeett_results.sun,
                temp,
                snow_results.dprec,
                snow_results.dmelt,
                ppeett_results.dpet,
                ppeett_results.dayl,
                k,
                pftpar,
                optdata,
                dphen,
                co2,
                p,
                tsoil,
                realout,
                numofpfts
            )
        end
    end