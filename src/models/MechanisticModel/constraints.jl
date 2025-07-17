"""
    constraints(tcm, twm, tminin, gdd5, rad0, gdd0, maxdepth, BIOME4PFTS, PFTstates)

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
- `BIOME4PFTS`: List of plant functional types to evaluate
- `PFTstates`: Dict mapping each `AbstractPFT` to its `PFTState`

# Returns
- `tmin`: Adjusted minimum temperature (°C)
- `BIOME4PFTS`: (unchanged) PFT list
"""
function constraints(
    tcm::T,
    twm::T,
    tminin::T,
    gdd5::T,
    rad0::T,
    gdd0::T,
    maxdepth::T,
    BIOME4PFTS::AbstractPFTList,
    PFTstates::Dict{AbstractPFT,PFTState{T,Int}}
)::Tuple{T,Dict{AbstractPFT,PFTState{T,Int}}} where {T<:Real}

    # adjust minimum temp for frost delay
    tmin = tminin <= tcm ? tminin : tcm - T(5.0)

    clindex = (tcm, tmin, gdd5, gdd0, twm, maxdepth)
    constraint_keys = (:tcm, :min, :gdd, :gdd0, :twm, :snow)

    for pft in BIOME4PFTS.pft_list
        valid = true
        cons = get_characteristic(pft, :constraints)

        # check each constraint dimension
        for (i, key) in enumerate(constraint_keys)
            lower, upper = cons[key][1], cons[key][2]
            val = clindex[i]
            if !( (lower == -Inf || val ≥ lower) &&
                  (upper == Inf  || val  < upper) )
                valid = false
                break
            end
        end

        # write into the runtime-state
        PFTstates[pft].present = valid
    end

    return tmin, PFTstates
end
