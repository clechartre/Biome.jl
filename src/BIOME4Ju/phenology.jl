"""Calculate the a generic phenology for any summergreen pft
three month period centred around the coldest month is
defined as the minimum period during which foliage is not
present. Plants then start growing leaves and the end of this
3 month period or when the temperature gos above 5oC if this
occurs later. Plants take 200 gdd5 to grow a full leaf canopy."""

module Phenology

using Base.Iterators: cycle

function phenology(
    dtemp::AbstractArray{Float64},
    temp::AbstractArray{Float64},
    tcm::Float64,
    tdif::Float64,
    tmin::Float64,
    pft::Int,
    ddayl::AbstractArray{Float64},
    pftpar::AbstractArray{Float64, 2}
)::AbstractArray{Float64}
    daysinmonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    dphen = zeros(Float64, 365, 2)
    ramp = [0.0, pftpar[pft, 8], pftpar[pft, 9]]

    ont = pft == 7 ? 0.0 : 5.0

    warm = tcm
    ncm = 0
    hotm = 0
    for m in 1:12
        if temp[m] == tcm
            ncm = m
        end
        if temp[m] > warm
            warm = temp[m]
            hotm = m
        end
    end

    for phencase in 1:2
        coldm = [ncm - 1, ncm, ncm + 1]
        if coldm[1] == 0
            coldm[1] = 12
        end
        if coldm[3] == 13
            coldm[3] = 1
        end
        if hotm == 12
            hotm = 0
        end

        gdd = 0.0
        winter = 0
        for _ in 1:2
            day = 0
            flip = 0
            for m in 1:12
                for dayofmonth in 1:daysinmonth[m]
                    day += 1
                    if dtemp[day] > ont
                        if m ∉ coldm
                            today = max(dtemp[day], 0.0)
                            gdd += today
                            dphen[day, phencase] = if gdd == 0.0
                                0.0
                            elseif ramp[phencase] != 0
                                gdd / ramp[phencase]
                            else
                                0
                            end
                            if gdd >= ramp[phencase]
                                dphen[day, phencase] = 1.0
                            end
                            flip = 1
                        else
                            if flip == 1
                                winter = 0
                            end
                            winter += 1
                            dphen[day, phencase] = 0.0
                            gdd = 0.0
                            flip = 0
                        end
                    end

                    if phencase == 2
                        if m >= hotm
                            if dtemp[day] < -10.0 || ddayl[day] < 10.0
                                dphen[day, phencase] = 0.0
                            end
                        elseif m == coldm[1]
                            dphen[day, phencase] = 0.0
                        end
                    elseif phencase == 3
                        if dtemp[day] < -5.0
                            dphen[day, phencase] = 0.0
                        end
                    end
                end
            end
        end
    end

    return dphen
end

end # module

using .Phenology

# Example run
dtemp = [rand() * 20.0 for _ in 1:365]
temp = [10.0 for _ in 1:12]
tcm = -5.0
tdif = 0.0
tmin = -15.0
pft = 1
ddayl = [10.0 for _ in 1:365]
pftpar = rand(10, 10)

result = Phenology.phenology(dtemp, temp, tcm, tdif, tmin, pft, ddayl, pftpar)
println(result)
