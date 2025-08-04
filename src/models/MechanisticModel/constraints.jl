"""
    constraints(tcm, twm, tminin, gdd5, rad0, gdd0, maxdepth, pftlist, pftstates)

Calculate constraints for biome classification based on temperature, GDD, and 
other parameters. Sets each PFT’s `present` flag in `states`.

# Arguments
- `tcm`: Temperature of coldest month (°C)
- `twm`: Temperature of warmest month (°C)
- `tminin`: Minimum temperature (°C)
- `gdd5`: Growing degree days above 5°C
- `rad0`: Annual radiation (MJ/m²/year)   # (not used here, but kept for interface consistency)
- `gdd0`: Growing degree days above 0°C
- `maxdepth`: Maximum snow depth (mm)
- `pftlist`: List of plant functional types to evaluate
- `pftstates`: Dict mapping each `AbstractPFT` to its `PFTState`

# Returns
- `tmin`: Adjusted minimum temperature (°C)
- `pftlist`: (unchanged) PFT list
"""
function constraints(
    pftlist::AbstractPFTList,
    pftstates::Dict{AbstractPFT,PFTState},
    env_variables::NamedTuple
)::Dict{AbstractPFT,PFTState}
    for pft in pftlist.pft_list
        valid = true
        cons = get_characteristic(pft, :constraints)

        # Check each constraint dynamically
        for (key, (lower, upper)) in pairs(cons)
            # Skip soil water balance, we deal with it later
            if key == :swb
                continue
            end
            if haskey(env_variables, key)
                val = getfield(env_variables, key)
                
                # Handle both scalar and vector values
                constraint_met = if isa(val, AbstractVector)
                    # For vectors, check if all values meet the constraint
                    # Skip missing values
                    non_missing_vals = filter(!ismissing, val)
                    if isempty(non_missing_vals)
                        false  # All values are missing
                    else
                        all(v -> (lower == -Inf || v ≥ lower) && (upper == Inf || v < upper), non_missing_vals)
                    end
                else
                    # For scalar values (original logic)
                    if ismissing(val)
                        false
                    else
                        (lower == -Inf || val ≥ lower) && (upper == Inf || val < upper)
                    end
                end
                
                if !constraint_met
                    valid = false
                    break
                end
            else
                @warn "Environmental variable `$(key)` not found in input but is required by constraints for PFT $(pft)"
                valid = false
                break
            end
        end

        pftstates[pft].present = valid
    end

    return pftstates
end