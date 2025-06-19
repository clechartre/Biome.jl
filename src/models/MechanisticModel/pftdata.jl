module PFTData

"""
Returns the PFT parameter table initialized with a specified type.

Args:
    ::Type{T} (optional): Type of the table values, e.g., Float32, Float64.

Returns:
    Array{T, 2}: The PFT parameter table as a 25x25 matrix.
"""
function pftdata(::Type{T})::Array{T, 2} where {T <: Real}
    # Dimensions for PFTs and parameters
    npft = 13
    npar = 11

    # Initialize a 25x25 array with default values
    var = fill(T(-99.0), 25, 25)  # Default values set to -99.0

    # Define specific values for the PFTs and their parameters
    parameter_values = [
        [T(1.0), T(0.5), T(10.0), T(-99.0), T(-99.0), T(0.69), T(18.0), T(-99.0), T(-99.0), T(1.0), T(0.0)],
        [T(3.0), T(0.5), T(10.0), T(0.5), T(0.6), T(0.70), T(9.0), T(-99.0), T(-99.0), T(1.0), T(0.0)],
        [T(1.0), T(0.2), T(4.8), T(-99.0), T(-99.0), T(0.67), T(18.0), T(-99.0), T(-99.0), T(1.0), T(0.0)],
        [T(2.0), T(0.8), T(10.0), T(-99.0), T(-99.0), T(0.65), T(7.0), T(200.0), T(-99.0), T(1.0), T(0.0)],
        [T(1.0), T(0.2), T(4.8), T(-99.0), T(-99.0), T(0.52), T(30.0), T(-99.0), T(-99.0), T(1.0), T(0.0)],
        [T(1.0), T(0.5), T(4.5), T(-99.0), T(-99.0), T(0.83), T(24.0), T(-99.0), T(-99.0), T(1.0), T(0.0)],
        [T(2.0), T(0.8), T(10.0), T(-99.0), T(-99.0), T(0.83), T(24.0), T(200.0), T(-99.0), T(1.0), T(0.0)],
        [T(3.0), T(0.8), T(6.5), T(0.2), T(0.3), T(0.83), T(8.0), T(-99.0), T(100.0), T(2.0), T(1.0)],
        [T(3.0), T(0.8), T(8.0), T(0.2), T(0.3), T(0.57), T(10.0), T(-99.0), T(-99.0), T(2.0), T(1.0)],
        [T(1.0), T(0.1), T(1.0), T(-99.0), T(-99.0), T(0.53), T(12.0), T(-99.0), T(-99.0), T(1.0), T(1.0)],
        [T(1.0), T(0.8), T(1.0), T(-99.0), T(-99.0), T(0.93), T(8.0), T(-99.0), T(-99.0), T(1.0), T(0.0)],
        [T(2.0), T(0.8), T(1.0), T(-99.0), T(-99.0), T(0.93), T(8.0), T(-99.0), T(25.0), T(2.0), T(0.0)],
        [T(1.0), T(0.8), T(1.0), T(-99.0), T(-99.0), T(0.93), T(8.0), T(-99.0), T(-99.0), T(1.0), T(0.0)]
    ]

    # Convert parameter_values to a 2D matrix
    parameter_values = hcat(parameter_values...)'

    # Populate the first `npft x npar` section of `var` with the specified values
    var[1:npft, 1:npar] .= parameter_values

    # Set the rest of the array to 0.0
    var[npft+1:end, :] .= T(0.0)
    var[:, npar+1:end] .= T(0.0)

    return var
end

end # module
