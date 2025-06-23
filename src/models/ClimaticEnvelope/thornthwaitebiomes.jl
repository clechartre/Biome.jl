using Statistics

function run(m::ThornthwaiteModel, vars_in::Vector{Union{T, U}}) where {T <: Real, U <: Int}
    # Define Thornthwaite climate zones with numerical values
    THORN = Dict(
        :Wet        => 1,
        :Humid      => 2,
        :Subhumid   => 3,
        :Semiarid   => 4,
        :Arid       => 5
    )

    THORN_TEMP = Dict(
        :Tropical       => 1,
        :Mesothermal    => 2,
        :Microthermal   => 3,
        :Taiga          => 4,
        :Tundra         => 5,
        :Frost          => 6
    )

    # Extract temperature and precipitation data
    temp = vars_in[5:16]    # Monthly temperatures
    precip = vars_in[17:28] # Monthly precipitation

    # Validate input
    if length(temp) != 12 || length(precip) != 12
        error("Temperature and precipitation arrays must have 12 values each (monthly data).")
    end

    # Initialize variables
    PE = 0.0
    TE = 0.0

    # Calculate PE and TE
    for i in 1:12
        t = temp[i]
        p = precip[i]

        # Avoid division by zero or negative temperatures
        if t > 0
            PE += 1.65 * (p / (t + 12.2))^(10/9)
            TE += t * 1.8 / 4
        end
    end

    # Classify moisture index based on PE
    moisture_zone = 
        if PE >= 128
            THORN[:Wet]
        elseif PE >= 64
            THORN[:Humid]
        elseif PE >= 32
            THORN[:Subhumid]
        elseif PE >= 16
            THORN[:Semiarid]
        else
            THORN[:Arid]
        end

    # Classify temperature zone based on TE
    temperature_zone =
        if TE >= 128
            THORN_TEMP[:Tropical]
        elseif TE >= 64
            THORN_TEMP[:Mesothermal]
        elseif TE >= 32
            THORN_TEMP[:Microthermal]
        elseif TE >= 16
            THORN_TEMP[:Taiga]
        elseif TE > 0
            THORN_TEMP[:Tundra]
        else
            THORN_TEMP[:Frost]
        end

    # Store results in output
    return temperature_zone, moisture_zone

end
