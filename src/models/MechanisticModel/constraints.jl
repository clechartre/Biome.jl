"""
    constraints(tcm, twm, tminin, gdd5, rad0, gdd0, maxdepth, BIOME4PFTS)
    Calculate constraints for biome classification based on temperature, GDD, and other parameters.
    Will determine whether the PFT can occur in the particular grid cell.
    Returns a tuple containing the minimum temperature, temperature difference, constraint index, and updated BIOME4PFTS.
"""
function constraints(
    tcm::T,
    twm::T,
    tminin::T,
    gdd5::T,
    rad0::T,
    gdd0::T,
    maxdepth::T,
    BIOME4PFTS::AbstractPFTList
)::Tuple{T, AbstractPFTList} where{T <: Real}
    nclin = 6
    undefined_value = -99.9
    
    tmin = tminin <= tcm ? tminin : tcm - 5.0
    ts = twm - tcm

    clindex = [tcm, tmin, gdd5, gdd0, twm, maxdepth] 
    
    for ip in 1:length(BIOME4PFTS.pft_list)
        valid = true
        for (iv, key) in enumerate([:tcm, :min, :gdd, :gdd0, :twm, :snow]) # FIXME. Also de-hardcode this? We need to see how we go about wetness later on since we need intermediate values before we compute it
            constraint_values =  get_characteristic(BIOME4PFTS.pft_list[ip], :constraints)[key]
            lower_limit, upper_limit = constraint_values[1], constraint_values[2]
            
            if !(
                (lower_limit != undefined_value && upper_limit != undefined_value && lower_limit <= clindex[iv] < upper_limit) ||
                (lower_limit == undefined_value && upper_limit != undefined_value && clindex[iv] < upper_limit) ||
                (lower_limit != undefined_value && upper_limit == undefined_value && lower_limit <= clindex[iv]) ||
                (lower_limit == undefined_value && upper_limit == undefined_value)
            )
                valid = false
                break
            end
        end
        set_characteristic(BIOME4PFTS.pft_list[ip], :present, valid)
    end

    return tmin, BIOME4PFTS
end

