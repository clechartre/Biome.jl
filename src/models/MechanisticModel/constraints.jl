# """
#     constraints(tcm, twm, tminin, gdd5, rad0, gdd0, maxdepth, pftlist, pftstates)

# Calculate constraints for biome classification based on temperature, GDD, and 
# other parameters. Sets each PFT’s `present` flag in `states`.

# # Arguments
# - `tcm`: Temperature of coldest month (°C)
# - `twm`: Temperature of warmest month (°C)
# - `tminin`: Minimum temperature (°C)
# - `gdd5`: Growing degree days above 5°C
# - `rad0`: Annual radiation (MJ/m²/year)   # (not used here, but kept for interface consistency)
# - `gdd0`: Growing degree days above 0°C
# - `maxdepth`: Maximum snow depth (mm)
# - `pftlist`: List of plant functional types to evaluate
# - `pftstates`: Dict mapping each `AbstractPFT` to its `PFTState`

# # Returns
# - `tmin`: Adjusted minimum temperature (°C)
# - `pftlist`: (unchanged) PFT list
# """
# function constraints(
#     pftlist::AbstractPFTList,
#     pftstates::Dict{AbstractPFT,PFTState},
#     env_variables::NamedTuple
# )::Dict{AbstractPFT,PFTState}
#     for pft in pftlist.pft_list
#         valid = true
#         cons = get_characteristic(pft, :constraints)

#         # Check each constraint dynamically
#         for (key, (lower, upper)) in pairs(cons)
#             # Skip soil water balance, we deal with it later
#             if key == :swb
#                 continue
#             end
#             if haskey(env_variables, key)
#                 val = getfield(env_variables, key)
                
#                 # Handle both scalar and vector values
#                 constraint_met = if isa(val, AbstractVector)
#                     # For vectors, check if all values meet the constraint
#                     # Skip missing values
#                     non_missing_vals = filter(!ismissing, val)
#                     if isempty(non_missing_vals)
#                         false  # All values are missing
#                     else
#                         all(v -> (lower == -Inf || v ≥ lower) && (upper == Inf || v < upper), non_missing_vals)
#                     end
#                 else
#                     # For scalar values (original logic)
#                     if ismissing(val)
#                         false
#                     else
#                         (lower == -Inf || val ≥ lower) && (upper == Inf || val < upper)
#                     end
#                 end
                
#                 if !constraint_met
#                     valid = false
#                     break
#                 end
#             else
#                 @warn "Environmental variable `$(key)` not found in input but is required by constraints for PFT $(pft)"
#                 valid = false
#                 break
#             end
#         end

#         pftstates[pft].present = valid
#     end

#     return pftstates
# end

"""
    constraints(pftlist, pftstates, env_variables) -> Dict{AbstractPFT,PFTState}

Soft multivariate probability of presence (no hard 0/1). For each constraint key
with (lower, upper), derive μ (midpoint) and σ = halfwidth/K (K=2), compare the
environmental value(s), accumulate d² = mean over dims of ((x-μ)/σ)^2, and set
presence_prob = exp(-0.5*d²), floored at 0.01.

- Vectors: use mean of per-element squared z-scores over non-missing.
- -Inf / +Inf: replace with large sentinels; if both are infinite → skip dim.
- `:swb` is skipped (handled elsewhere).
"""
function constraints(
    pftlist::AbstractPFTList,
    pftstates::Dict{AbstractPFT,PFTState},
    env_variables::NamedTuple
)::Dict{AbstractPFT,PFTState}
    # constants (kept inside to stay close to your original signature)
    K_at_bound = 2.0         # bounds at ±Kσ → prob at bound ≈ exp(-0.5*K^2)
    p_floor    = 0.01
    big_neg    = -9.999e9
    big_pos    =  9.999e8

    for pft in pftlist.pft_list
        cons = get_characteristic(pft, :constraints)

        # accumulate Mahalanobis-like distance across constraint dimensions
        d2 = zero(Float64)   # will promote to Dual during AD if needed
        n_dims = 0

        # Check each constraint dynamically
        for (key, (lower, upper)) in pairs(cons)
            # Skip soil water balance, we deal with it later
            if key == :swb
                continue
            end

            if haskey(env_variables, key)
                val = getfield(env_variables, key)

                # normalize bounds (both infinite → skip this dimension)
                both_inf = (!isfinite(lower) && !isfinite(upper))
                if both_inf
                    continue
                end
                # replace one-sided infinities with sentinels
                lo = isfinite(lower) ? lower : big_neg
                up = isfinite(upper) ? upper : big_pos
                if up <= lo
                    up = lo + 1.0
                end

                half = (up - lo) / 2
                μ    = lo + half
                σ    = max(half / K_at_bound, eps())  # avoid zero

                # Handle both scalar and vector values
                if isa(val, AbstractVector)
                    non_missing_vals = collect(skipmissing(val))
                    if !isempty(non_missing_vals)
                        # mean of squared z-scores over elements
                        # pick a numeric type that supports AD if present
                        T = promote_type(eltype(non_missing_vals), Float64)
                        μT, σT = T(μ), T(σ)
                        d2_dim = zero(T)
                        for v in non_missing_vals
                            d2_dim += ((T(v) - μT) / σT)^2
                        end
                        d2 += d2_dim / length(non_missing_vals)
                        n_dims += 1
                    else
                        # no information → skip this dimension
                        continue
                    end
                else
                    if ismissing(val)
                        # skip dimension if missing
                        continue
                    else
                        # scalar contribution
                        T = promote_type(typeof(val), Float64)
                        d2 += ((T(val) - T(μ)) / T(σ))^2
                        n_dims += 1
                    end
                end
            else
                @warn "Environmental variable `$(key)` not found in input but is required by constraints for PFT $(pft)"
                # stay close to your control flow: previously broke/flagged false;
                # here we just skip this dimension to avoid injecting arbitrary penalty.
                continue
            end
        end

        # Convert distance to probability
        d2 = n_dims == 0 ? zero(d2) : d2 / n_dims
        p  = exp(-one(d2) * d2 / 2)

        pftstates[pft].present= p
    end

    return pftstates
end


