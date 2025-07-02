function phenology(
    dphen::AbstractArray{T},
    dtemp::AbstractArray{T},
    temp::AbstractArray{T},
    tcm::T,
    tmin::T,
    pft::U,
    ddayl::AbstractArray{T},
    BIOME4PFTS::AbstractPFTList
)::AbstractArray{T} where {T <: Real, U <: Int}
    # Days in each month
    daysinmonth = U[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    dphen = ones(T, 365, 2)
    ramp = T[get_characteristic(BIOME4PFTS.pft_list[pft], :GDD5_full_leaf_out), get_characteristic(BIOME4PFTS.pft_list[pft], :GDD0_full_leaf_out)]
    ont = get_characteristic(BIOME4PFTS.pft_list[pft], :name) == "BorealDeciduous" ? T(0.0) : T(5.0)

    # Initialize variables
    warm = tcm
    ncm = U(0)
    hotm = U(0)

    # Find coldest and hottest months
    for m in 1:12
        if temp[m] == tcm
            ncm = U(m)
        end
        if temp[m] > warm
            warm = temp[m]
            hotm = U(m)
        end
    end

    # Phenology cases (spinup loop)
    for phencase in 1:2
        coldm = U[ncm - 1, ncm, ncm + 1]
        if coldm[1] == U(0)
            coldm[1] = U(12)
        end
        if coldm[3] == U(13)
            coldm[3] = U(1)
        end
        if hotm == U(12)
            hotm = U(0)
        end

        gdd = T(0.0)
        winter = U(0)
        flip = U(0)

        for _ in 1:2 # Spinup loop
            day = U(0)
            for m in 1:12 # Monthly loop
                for _ in 1:daysinmonth[m] # Daily loop
                    day += U(1)

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
                            flip = U(1)
                        else
                            if flip == U(1)
                                winter = U(0)
                            end
                            winter += U(1)
                            dphen[day, phencase] = T(0.0)
                            gdd = T(0.0)
                            flip = U(0)
                        end
                    end

                    # Fall leaves removal
                    if phencase == U(1)
                        if m >= hotm
                            if dtemp[day] < T(-10.0) || ddayl[day] < T(10.0)
                                dphen[day, phencase] = T(0.0)
                            end
                        elseif m == coldm[1]
                            dphen[day, phencase] = T(0.0)
                        end
                    elseif phencase == U(2)
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
