# Third-Party
using Statistics

function run(m::TrollPfaffenModel, vars_in::Vector{Union{T, U}}) where {T <: Real, U <: Int}

    # Define Troll-Paffen climate zones with numerical values and descriptions
    TROLL = Dict(
        :TP_I_1    => 1,  # Polar ice-deserts
        :TP_I_2    => 2,  # Polar frost-debris belt
        :TP_I_3    => 3,  # Tundra
        :TP_I_4    => 4,  # Sub-polar tussock grassland and moors
        :TP_II_1   => 5,  # Oceanic humid coniferous woods
        :TP_II_2   => 6,  # Continental coniferous woods
        :TP_II_3   => 7,  # Highly continental dry coniferous woods
        :TP_III_1  => 8,  # Evergreen broad-leaved and mixed woods
        :TP_III_2  => 9,  # Oceanic deciduous broad-leaved and mixed woods
        :TP_III_3  => 10, # Sub-oceanic deciduous broad-leaved and mixed woods
        :TP_III_4  => 11, # Sub-continental deciduous broad-leaved and mixed woods
        :TP_III_5  => 12, # Continental deciduous broad-leaved and mixed woods as well as wooded steppe
        :TP_III_6  => 13, # Highly continental deciduous broad-leaved and mixed woods as well as wooded steppe
        :TP_III_7  => 14, # Deciduous broad-leaved and mixed wood and wooded steppe
        :TP_III_7a => 15, # Thermophile dry wood and wooded steppe
        :TP_III_8  => 16, # Humid deciduous broad-leaved and mixed wood
        :TP_III_9  => 17, # High grass-steppe with perennial herbs
        :TP_III_9a => 18, # Humid steppe with mild winters
        :TP_III_10 => 19, # Short grass-, dwarf shrub-, or thorn-steppe
        :TP_III_10a=> 20, # Steppe with short grass, dwarf shrubs, and thorns
        :TP_III_11 => 21, # Central and East-Asian grass and dwarf shrub steppe
        :TP_III_12 => 22, # Semi-desert and desert with cold winters
        :TP_III_12a=> 23, # Semi-desert and desert with mild winters
        :TP_IV_1   => 24, # Sub-tropical hard-leaved and coniferous wood
        :TP_IV_2   => 25, # Sub-tropical grass and shrub-steppe
        :TP_IV_3   => 26, # Sub-tropical thorn- and succulents-steppe
        :TP_IV_4   => 27, # Sub-tropical steppe with short grass
        :TP_IV_5   => 28, # Sub-tropical semi-deserts and deserts
        :TP_IV_6   => 29, # Sub-tropical high-grassland
        :TP_IV_7   => 30, # Sub-tropical humid forests
        :TP_V_1    => 31, # Evergreen tropical rain forest
        :TP_V_2    => 32, # Rain-green humid forest
        :TP_V_2a   => 33, # Half-deciduous transition wood
        :TP_V_3    => 34, # Rain-green dry wood and savannah
        :TP_V_4    => 35, # Tropical thorn-succulent wood and savannah
        :TP_V_4a   => 36, # Tropical dry climates with humid months in winter
        :TP_V_5    => 37, # Tropical semi-deserts and deserts
        :NA        => 38  # Not Classified
    )

    # Extract temperature and precipitation data
    temp = vars_in[5:16]    # Monthly temperatures
    precip = vars_in[17:28] # Monthly precipitation

    # Calculate statistics
    temp_max = maximum(temp)
    temp_min = minimum(temp)
    temp_mean = mean(temp)
    temp_range = temp_max - temp_min
    precip_sum = sum(precip)

    # Calculate Growing Degree Days
    nVegDays = get_growing_degree_days(temp, 5.0)

    # Calculate Humid Months
    nHumid = get_humid_months(temp, precip)

    # Determine if in northern hemisphere
    bNorth = sum(temp[4:9]) > sum(temp[10:12]) + sum(temp[1:2])

    # Determine classification
    zone =
        # Polar and Subpolar Zones
        if temp_max < 0
            TROLL[:TP_I_1]
        elseif temp_max < 6
            TROLL[:TP_I_2]
        elseif temp_max < 12 && temp_min < -8
            TROLL[:TP_I_3]
        elseif temp_max < 12 && temp_min >= -8 && temp_range < 13
            TROLL[:TP_I_4]

        # Cold Temperate Boreal Zone
        elseif temp_max < 15 && temp_min >= -3 && temp_min < 2 && is_between(nVegDays, 120, 180)
            TROLL[:TP_II_1]
        elseif temp_max < 20 && temp_range < 40 && is_between(nVegDays, 100, 150)
            TROLL[:TP_II_2]
        elseif temp_max < 20 && temp_range >= 40
            TROLL[:TP_II_3]

        # Cool Temperate Zones
        elseif temp_min >= -3 && temp_min < 2 && nVegDays >= 200
            TROLL[:TP_III_3]
        elseif temp_max < 15 && is_between(temp_min, 2, 10) && temp_range < 10
            TROLL[:TP_III_1]
        elseif temp_max < 20 && temp_min >= 2 && temp_range < 16
            TROLL[:TP_III_2]
        elseif temp_max < 20 && is_between(temp_range, 20, 30) && is_between(nVegDays, 160, 210)
            TROLL[:TP_III_4]
        elseif temp_max < 20 && is_between(temp_min, -20, -10) && is_between(temp_range, 30, 40) && is_between(nVegDays, 150, 180)
            TROLL[:TP_III_5]
        elseif temp_max >= 20 && is_between(temp_min, -30, -10) && temp_range > 40
            TROLL[:TP_III_6]

        # Steppe Climates
        elseif temp_min < 0
            if nHumid >= 6
                TROLL[:TP_III_9]
            elseif precip[3] + precip[4] + precip[5] < precip[6] + precip[7] + precip[8]  # PWinter < PSummer
                TROLL[:TP_III_10]
            else
                TROLL[:TP_III_9a]
            end
        elseif temp_min < 6
            TROLL[:TP_III_12a]

        # Tropical and Subtropical Zones
        elseif temp_min > 0 && temp_mean > 18.3
            if nHumid > 9.5
                TROLL[:TP_V_1]
            elseif nHumid > 7
                if !bNorth
                    TROLL[:TP_V_2a]
                else
                    TROLL[:TP_V_2]
                end
            elseif nHumid > 4.5
                TROLL[:TP_V_3]
            elseif nHumid > 2
                if !bNorth
                    TROLL[:TP_V_4a]
                else
                    TROLL[:TP_V_4]
                end
            else
                TROLL[:TP_V_5]
            end
        else
            TROLL[:NA]
        end

    return zone
end

# Utility functions
function is_between(x, low, high)
    return low <= x <= high
end

function get_growing_degree_days(temp::Vector{Float64}, base_temp::Float64)
    return sum(max(t - base_temp, 0.0) for t in temp)
end

function get_humid_months(temp::Vector{Float64}, precip::Vector{Float64})
    temp_daily = daily_interp(temp)
    precip_daily = daily_interp(precip)
    humid_days = sum(precip_daily[i] > 2 * temp_daily[i] for i in 1:365)
    return humid_days * 12.0 / 365.0
end

