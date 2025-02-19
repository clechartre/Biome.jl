module Constraints

using ComponentArrays: ComponentArray

function constraints(
    tcm::T,
    twm::T,
    tminin::T,
    gdd5::T,
    rad0::T,
    gdd0::T,
    maxdepth::T,
    pftdict
)::Tuple{T, T, AbstractArray{T}, Vector{Int}} where{T <: Real}
    npft = 13
    nclin = 6
    undefined_value = -99.9

    limits = Dict(k => v.constraints for (k, v) in pftdict)
    
    tmin = tminin <= tcm ? tminin : tcm - 5.0
    ts = twm - tcm

    clindex = [tcm, tmin, gdd5, gdd0, twm, maxdepth]
    pfts = zeros(Int, npft)

    for ip in 1:npft
        valid = true
        for (iv, key) in enumerate([:tcm, :min, :gdd, :gdd0, :twm, :snow])
            if haskey(limits[ip], key)
                lower_limit, upper_limit = limits[ip][key]
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
        end
        pfts[ip] = valid ? 1 : 0
    end

    return tmin, ts, clindex, pfts
end

end # module
