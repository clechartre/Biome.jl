function safe_exp(x::T)::T where {T <: Real}
    try
        return exp(x)
    catch
        return T(Inf)
    end
end


function safe_round_to_int(x::T)::Int where {T <: Real}
    if isnan(x)
        return 0
    elseif x > typemax(Int)
        return typemax(Int)
    elseif x < typemin(Int)
        return typemin(Int)
    else
        return round(Int, x)
    end
end