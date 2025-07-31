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


"""
    set_characteristic!(
      pl_mod::Module,
      name::Union{String,Symbol},
      prop::Symbol,
      value
    )

Find in `pl_mod.pft_list` the first `pft` whose
`pft.characteristics.name == name` (where `name` may be
a `Symbol` or `String`), and then mutate that PFT’s
`characteristics.prop` to `value`.
Returns the modified PFT.
"""
function set_characteristic!(
    pl_mod::AbstractPFTList,
    name::Union{String,Symbol},
    prop::Symbol,
    value
)
    # Normalize the lookup name
    target = name isa Symbol ? string(name) : name

    # Find the PFT in pl_mod.pft_list
    list = getfield(pl_mod, :pft_list)
    idx  = findfirst(pft -> pft.characteristics.name == target, list)
    idx === nothing && throw(ArgumentError("no PFT named \"$target\" found"))

    # Grab its characteristics object
    pft = list[idx]
    ch  = pft.characteristics

    if hasproperty(ch, prop) && prop !== :constraints
        # Simple field: mutate in‐place
        setfield!(ch, prop, value)

    elseif hasproperty(ch.constraints, prop)
        # One of the constraint‐keys: rebuild only that entry
        oldc = ch.constraints
        newc = (; oldc..., prop => value)
        setfield!(ch, :constraints, newc)

    else
        throw(ArgumentError("`$prop` is not a field of Characteristics nor a constraint key"))
    end

    return pft
end

function _unpack_climate(x::NamedTuple)
    kk = keys(x)
    vv = values(x)
    i = 1
    for k in kk
        @eval $k = $vv[$i]
        i +=1
    end
end


macro unpack_namedtuple_climate(arg)
 quote
    _unpack_climate($arg)
end |> esc
end
