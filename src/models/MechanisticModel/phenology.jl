function phenology(
    dphen::AbstractArray{T},
    dtemp::AbstractArray{T},
    temp::AbstractArray{T},
    tcm::T,
    tmin::T,
    pft::AbstractPFT,
    ddayl::AbstractArray{T},
)::AbstractArray{T} where {T <: Real}
    # Days in each month
    daysinmonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    ramp = T[get_characteristic(pft, :GDD5_full_leaf_out), get_characteristic(pft, :GDD0_full_leaf_out)]
    ont = get_characteristic(pft, :name) == "BorealDeciduous" ? T(0.0) : T(5.0)

    # Initialize variables
    warm = tcm
    ncm = (0)
    hotm = (0)

    # Find coldest and hottest months
    for m in 1:12
        if temp[m] == tcm
            ncm = (m)
        end
        if temp[m] > warm
            warm = temp[m]
            hotm = (m)
        end
    end

    # Phenology cases (spinup loop)
    for phencase in 1:2
        coldm = [ncm - 1, ncm, ncm + 1]
        if coldm[1] == (0)
            coldm[1] = (12)
        end
        if coldm[3] == (13)
            coldm[3] = (1)
        end
        if hotm == (12)
            hotm = (0)
        end

        gdd = T(0.0)
        winter = (0)
        flip = (0)

        for _ in 1:2 # Spinup loop
            day = (0)
            for m in 1:12 # Monthly loop
                for _ in 1:daysinmonth[m] # Daily loop
                    day += (1)

                    # Check temperature threshold
                    if dtemp[day] > ont
                        if m != coldm[1] && m != coldm[2] && m != coldm[3]
                            today = max(dtemp[day], T(0.0))

                            gdd += today
                            if gdd == T(0.0)
                                dphen[day, phencase] = T(0.0)
                            else
                                dphen[day, phencase] = gdd / ramp[phencase]
                            end
                            if gdd >= ramp[phencase]
                                dphen[day, phencase] = T(1.0)
                            end
                            flip = (1)
                        else
                            if flip == (1)
                                winter = (0)
                            end
                            winter += (1)
                            dphen[day, phencase] = T(0.0)
                            gdd = T(0.0)
                            flip = (0)
                        end
                    end

                    # Fall leaves removal
                    if phencase == (1)
                        if m >= hotm
                            if dtemp[day] < T(-10.0) || ddayl[day] < T(10.0)
                                dphen[day, phencase] = T(0.0)
                            end
                        elseif m == coldm[1]
                            dphen[day, phencase] = T(0.0)
                        end
                    elseif phencase == (2)
                        if dtemp[day] < T(-5.0)
                            dphen[day, phencase] = T(0.0)
                        end
                    end
                end
            end
        end
    end

    return dphen
end
