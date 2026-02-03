using Statistics

"""
    runmodel(m::ThornthwaiteModel, vars_in::Vector{Union{T, U}}, args...; kwargs...) where {T <: Real, U <: Int}

Compute Thornthwaite climate classification zones from monthly temperature and precipitation data.

# Arguments
- `m::ThornthwaiteModel`
  The model instance (not directly used in this implementation, provided for dispatch).
- `vars_in::Vector{Union{T, U}}`
  A length‑28 vector containing:
  1. Elements 1–4: (unused placeholders)
  2. Elements 5–16: twelve monthly mean temperatures (Real values)
  3. Elements 17–28: twelve monthly total precipitations (Real values)

# Returns
- `output::Vector{Any}`  
  A vector of length 50 (initialized to zeros of type `T`), where:
  - `output[1]` is an `Int` code for the temperature zone:
    1. Tropical  
    2. Mesothermal  
    3. Microthermal  
    4. Taiga  
    5. Tundra  
    6. Frost  
  - `output[2]` is an `Int` code for the moisture zone:
    1. Wet  
    2. Humid  
    3. Subhumid  
    4. Semiarid  
    5. Arid  
  - All other entries remain zero.
"""
function runmodel(m::ThornthwaiteModel, input_variables::NamedTuple, args...; kwargs...)
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
    @unpack_namedtuple_climate input_variables

    # Validate input
    if length(temp) != 12 || length(prec) != 12
        error("Temperature and precipitation arrays must have 12 values each (monthly data).")
    end

    # Initialize variables
    PE = 0.0
    TE = 0.0

    # Calculate PE and TE
    for i in 1:12
        t = temp[i]
        p = prec[i]

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
    output = (temperature_zone = temperature_zone, moisture_zone = moisture_zone)

    return output

end
