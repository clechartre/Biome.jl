"""
    constraints(tcm, twm, tminin, gdd5, rad0, gdd0, maxdepth, BIOME4PFTS)

Calculate constraints for biome classification based on temperature, GDD, and 
other parameters.

Determines whether each PFT can occur in the particular grid cell based on
climate constraints. Uses -Inf and Inf as undefined lower and upper bounds
respectively.

# Arguments
- `tcm`: Temperature of coldest month (°C)
- `twm`: Temperature of warmest month (°C)
- `tminin`: Minimum temperature (°C)
- `gdd5`: Growing degree days above 5°C
- `rad0`: Annual radiation (MJ/m²/year)
- `gdd0`: Growing degree days above 0°C
- `maxdepth`: Maximum snow depth (mm)
- `BIOME4PFTS`: List of plant functional types to evaluate

# Returns
A tuple containing:
- `tmin`: Adjusted minimum temperature (°C)
- `BIOME4PFTS`: Updated PFT list with presence flags set
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
)::Tuple{T,AbstractPFTList} where {T<:Real}
    tmin = tminin <= tcm ? tminin : tcm - T(5.0)
    
    clindex = [tcm, tmin, gdd5, gdd0, twm, maxdepth]
    constraint_keys = [:tcm, :min, :gdd, :gdd0, :twm, :snow]
    
    for ip in 1:length(BIOME4PFTS.pft_list)
        valid = true
        
        for (iv, key) in enumerate(constraint_keys)
            constraint_values = get_characteristic(
                BIOME4PFTS.pft_list[ip], :constraints
            )[key]
            lower_limit, upper_limit = constraint_values[1], constraint_values[2]
            
            # Check if value falls within constraints
            # -Inf means no lower bound, Inf means no upper bound
            within_bounds = (
                (lower_limit == -Inf || clindex[iv] >= lower_limit) &&
                (upper_limit == Inf || clindex[iv] < upper_limit)
            )
            
            if !within_bounds
                valid = false
                break
            end
        end
        
        set_characteristic(BIOME4PFTS.pft_list[ip], :present, valid)
    end

    return tmin, BIOME4PFTS
end