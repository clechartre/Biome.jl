module Biome4Driver

# Standard library
using Base.Threads
using Base.Iterators
using Printf

# Third-party
using ArgParse
using NCDatasets
using DataStructures: OrderedDict
using Statistics
ENV["GKSwstype"] = "100"  # Offscreen (no display required)
using Plots
gr()
using Dates
using Missings

# First-party
include("./biome4.jl")
using .BIOME4

function main(
    coordstring::String,
    co2::Float64,
    diagnosticmode::Bool,
    tempfile::String,
    tminfile::String,
    precfile::String,
    sunfile::String,
    ksatfile::String,
    whcfile::String,
    year::String,
    resolution::String,
    checkpoint_file::String
)
    # Chunk and checkpoint parameters
    chunk_size = 1000 # For functioning on node/debug, 100 works

    println("Temperature file: $tempfile")
    println("Temperature minimum file: $tminfile")
    println("Precipitation file: $precfile")
    println("Cloud percent file: $sunfile")
    println("Saturated conductivity file: $ksatfile")
    println("Water holding capacity file $whcfile")

    # Set the resolution value based on the flag
    res_value = resolution == "low" ? 0.5 : 0.009

    # Open the first dataset just to get the dimensions for the output, then close again
    temp_ds = NCDataset(tempfile, "a")
    lon = temp_ds["lon"][:]  # Keep lon and lat as they are, cut according to bbox
    lat = temp_ds["lat"][:]
    # Now hardcoded will be determined by whc 
    xlen = length(lon)
    ylen = length(lat)
    llen = 2
    tlen = 12
    close(temp_ds)
    

    if coordstring == "alldata"
        strx = 1
        stry = 1
        cntx = xlen
        cnty = ylen
        endx = strx + cntx - 1
        endy = stry + cnty - 1
    else
        boundingbox = [parse(Float64, x) for x in split(coordstring, "/")]
        lon_min = boundingbox[1]
        lon_max = boundingbox[2]
        lat_min = boundingbox[3]
        lat_max = boundingbox[4]

        strx, stry, cntx, cnty = get_array_indices(lon_min, lon_max, lat_min, lat_max, res_value)

        endx = strx + cntx - 1
        endy = stry + cnty - 1
    end

    println("Bounding box: $strx $stry $endx $endy $cntx, $cnty")

    lon = lon[strx:endx]
    lat = lat[stry:endy]

    # Dynamically create the output filename
    outfile = "./output_$(year).nc"
    if isfile(outfile)
        println("File $outfile already exists. Resuming from last processed row.")
        output_dataset = NCDataset(outfile, "a")  # Open in append mode

        # Extract existing variables
        biome_var = output_dataset["biome"]      # Extract the biome variable
        wdom_var = output_dataset["wdom"]        # Extract the woody dominance variable
        gdom_var = output_dataset["gdom"]        # Extract the grass dominance variable
        npp_var = output_dataset["npp"]          # Extract the NPP variable
        tcm_var = output_dataset["tcm"]          # Extract the TCM variable
        gdd0_var = output_dataset["gdd0"]        # Extract GDD0 variable
        gdd5_var = output_dataset["gdd5"]        # Extract GDD5 variable
        subpft_var = output_dataset["subpft"]    # Extract the subpft variable
        wetness_var = output_dataset["wetness"]  # Extract the wetness variable

    else
        println("File $outfile does not exist. Creating a new file.")
        output_dataset = NCDataset(outfile, "c")

        # Define dimensions and variables if creating the file
        defDim(output_dataset, "lon", size(lon, 1))
        defDim(output_dataset, "lat", size(lat, 1))
        defDim(output_dataset, "time", llen)
        defDim(output_dataset, "months", tlen)
        defDim(output_dataset, "pft", 13)

        # Define variables with appropriate types and dimensions
        lon_var = defVar(output_dataset, "lon", Float64, ("lon",), attrib = OrderedDict("units" => "degrees_east"))
        lat_var = defVar(output_dataset, "lat", Float64, ("lat",), attrib = OrderedDict("units" => "degrees_north"))
        biome_var = defVar(output_dataset, "biome", Int16, ("lon", "lat"), attrib = OrderedDict("description" => "Biome classification"))
        wdom_var = defVar(output_dataset, "wdom", Float64, ("lon", "lat"), attrib = OrderedDict("description" => "Dominant woody vegetation"))
        gdom_var = defVar(output_dataset, "gdom", Float64, ("lon", "lat"), attrib = OrderedDict("description" => "Dominant grass vegetation"))
        npp_var = defVar(output_dataset, "npp", Float32, ("lon", "lat", "pft"), attrib = OrderedDict("units" => "gC/m^2/month", "description" => "Net primary productivity"))
        tcm_var = defVar(output_dataset, "tcm", Float64, ("lon", "lat"), attrib = OrderedDict("description" => "tcm"))
        gdd0_var = defVar(output_dataset, "gdd0", Float64, ("lon", "lat"), attrib = OrderedDict("description" => "gdd0"))
        gdd5_var = defVar(output_dataset, "gdd5", Float64, ("lon", "lat"), attrib = OrderedDict("description" => "gdd5"))
        subpft_var = defVar(output_dataset, "subpft", Float64, ("lon", "lat"), attrib = OrderedDict("description" => "subpft"))
        wetness_var = defVar(output_dataset, "wetness", Float64, ("lon", "lat"), attrib = OrderedDict("description" => "wetness"))

        # Add global attributes to the dataset
        output_dataset.attrib["title"] = "Biome prediction output"
        output_dataset.attrib["institution"] = "WSL"
        output_dataset.attrib["source"] = "BIOME4 Model"

        # Fill with placeholder values initially
        lon_var[:] = lon
        lat_var[:] = lat
        biome_var[:, :] = fill(-9999, cntx, cnty)
        wdom_var[:, :] = fill(-9999, cntx, cnty)
        gdom_var[:, :] = fill(-9999, cntx, cnty)
        npp_var[:, :, :] = fill(-9999.0f0, cntx, cnty, 13)
        tcm_var[:, :] = fill(-9999.0f0, cntx, cnty)
        gdd0_var[:, :] = fill(-9999.0f0, cntx, cnty)
        gdd5_var[:, :] = fill(-9999.0f0, cntx, cnty)
        subpft_var[:, :] = fill(-9999.0f0, cntx, cnty)
        wetness_var[:, :] = fill(-9999.0f0, cntx, cnty)
    end

    # Load checkpoint
    x_chunk_start = load_checkpoint(checkpoint_file, strx)
    println("Resuming from x_chunk_start: $x_chunk_start")

    # Set up chunking variables
    x_chunk_size = chunk_size
    lat_chunk = nothing

    for x_chunk_start in x_chunk_start:chunk_size:endx
        x_chunk_end = min(x_chunk_start + x_chunk_size - 1, endx)
        current_chunk_size = x_chunk_end - x_chunk_start + 1

        println("Processing x indices from $x_chunk_start to $x_chunk_end")

        # Initialize variables for this chunk
        temp_chunk = zeros(Float32, (current_chunk_size, cnty, 12))
        tmin_chunk = zeros(Float32, (current_chunk_size, cnty))
        prec_chunk = zeros(Float32, (current_chunk_size, cnty, 12))
        cldp_chunk = zeros(Float32, (current_chunk_size, cnty, 12))
        ksat_chunk = zeros(Float32, (current_chunk_size, cnty, 2))
        whc_chunk = zeros(Float32, (current_chunk_size, cnty, 2))
        elv_chunk = zeros(Float32, (current_chunk_size, cnty))

        # Read longitude for this chunk
        lon_chunk = nothing
        Dataset(tempfile) do ds
            lon_chunk = ds["lon"][x_chunk_start:x_chunk_end]
        end

        # Read latitude (only once since it's the same for all x chunks)
        if x_chunk_start == strx
            Dataset(tempfile) do ds
                lat_chunk = ds["lat"][stry:endy]
            end
        end

        Dataset(tempfile) do ds
            temp_chunk = ds["temp"][x_chunk_start:x_chunk_end, stry:endy, :]
            temp_chunk = uniform_fill_value(temp_chunk)
        end

        Dataset(tminfile) do ds
            tmin_chunk = ds["tmin"][x_chunk_start:x_chunk_end, stry:endy]
            tmin_chunk = uniform_fill_value(tmin_chunk)
        end

        Dataset(precfile) do ds
            prec_chunk = ds["prec"][x_chunk_start:x_chunk_end, stry:endy, :]
            prec_chunk = uniform_fill_value(prec_chunk)
        end

        Dataset(sunfile) do ds
            cldp_chunk = ds["sun"][x_chunk_start:x_chunk_end, stry:endy, :]
            cldp_chunk = uniform_fill_value(cldp_chunk)
        end

        Dataset(ksatfile) do ds
            ksat_chunk = ds["ksat"][x_chunk_start:x_chunk_end, stry:endy, :]
            ksat_chunk = uniform_fill_value(ksat_chunk)
        end

        Dataset(whcfile) do ds
            whc_chunk = ds["whc"][x_chunk_start:x_chunk_end, stry:endy, :]
            whc_chunk = uniform_fill_value(whc_chunk)
        end

        # Read elevation data if available
        if @isdefined(elvfile) && isfile(elvfile)
            Dataset(elvfile) do ds
                elv_chunk = ds["elv"][x_chunk_start:x_chunk_end, stry:endy]
                elv_chunk = uniform_fill_value(elv_chunk)
            end
        else
            elv_chunk = zeros(Float32, (current_chunk_size, cnty))
        end

        # Flip the data arrays along the latitude axis - change this if data is not generated from CHELSA
        temp_chunk = temp_chunk[:, :, :]
        tmin_chunk = tmin_chunk[:, :]
        prec_chunk = prec_chunk[:, :, :]
        cldp_chunk = cldp_chunk[:, :, :]
        ksat_chunk = ksat_chunk[:, end:-1:1, :]
        whc_chunk = whc_chunk[:, end:-1:1, :]
        elv_chunk = elv_chunk[:, end:-1:1]

        println("max temp: ", maximum(temp_chunk), ", min temp: ", minimum(temp_chunk))
        println("max tmin: ", maximum(tmin_chunk), ", min tmin: ", minimum(tmin_chunk))
        println("max prec: ", maximum(prec_chunk), ", min prec: ", minimum(prec_chunk))
        println("max cldp: ", maximum(cldp_chunk), ", min cldp: ", minimum(cldp_chunk))
        println("max ksat: ", maximum(ksat_chunk), ", min ksat: ", minimum(ksat_chunk))
        println("max whc: ", maximum(whc_chunk), ", min whc: ", minimum(whc_chunk))

        # Process the data in this chunk
        parallel_process_chunk(
            current_chunk_size,
            cnty,
            temp_chunk,
            elv_chunk,
            lat_chunk,
            co2,
            tmin_chunk,
            prec_chunk,
            cldp_chunk,
            ksat_chunk,
            whc_chunk,
            lon_chunk,
            diagnosticmode,
            biome_var,
            wdom_var,
            gdom_var,
            npp_var,
            tcm_var,
            gdd0_var,
            gdd5_var,
            subpft_var,
            wetness_var,
            output_dataset,
            x_chunk_start,
            strx,
            stry,
            endy
        )

        # Save the checkpoint after processing the chunk
        save_checkpoint(checkpoint_file, x_chunk_start)
    end

    # Close the NetCDF file
    close(output_dataset)
end


function parallel_process_chunk(
    current_chunk_size, cnty,
    temp_chunk, elv_chunk, lat_chunk, co2, tmin_chunk, prec_chunk, cldp_chunk, ksat_chunk, whc_chunk, lon_chunk, diag,
    biome_var, wdom_var, gdom_var, npp_var, tcm_var, gdd0_var, gdd5_var, subpft_var, wetness_var,
    output_dataset,
    x_chunk_start, strx, stry, endy
)
    # Container to hold the spawned tasks (futures)
    futures = []

    for y in 1:cnty
        println("Parallel processing y index $y")

        # Skip already processed rows
        if all(biome_var[:, y] .!= -9999)
            println("Skipping already processed row: $y")
            continue
        end

        # Spawn a single task to process all x indices at once for this y
        push!(futures, Threads.@spawn begin
            for x in 1:current_chunk_size
                process_cell(
                    x, y, strx,
                    temp_chunk, elv_chunk, lat_chunk, co2, tmin_chunk, prec_chunk, cldp_chunk, ksat_chunk, whc_chunk, lon_chunk, diag,
                    biome_var, wdom_var, gdom_var, npp_var, tcm_var, gdd0_var, gdd5_var, subpft_var, wetness_var,
                    output_dataset,
                    x_chunk_start
                )
            end
        end)
    end

    # Wait for all futures to complete
    for future in futures
        fetch(future)
    end

    sync(output_dataset)
end


function serial_process_chunk(
    current_chunk_size, cnty,
    temp_chunk, elv_chunk, lat_chunk, co2, tmin_chunk, prec_chunk, cldp_chunk, ksat_chunk, whc_chunk, lon_chunk, diag,
    biome_var, wdom_var, gdom_var, npp_var, tcm_var, gdd0_var, gdd5_var, subpft_var, wetness_var,
    output_dataset,
    x_chunk_start, strx, stry, endy
)
    for y in 1:cnty
        println("Processing y index $y")

        # Here, check if the row is already processed. If yes, skipped
        if all(biome_var[:, y] .!= -9999) && all(biome_var[:, y-1] .!= -9999)
            println("Skipping already processed row: $y")
            continue
        end

        for x in 1:current_chunk_size

            if temp[x, y, 1] == -9999.0
                continue
            end
            
            process_cell(
                x, y, strx,
                temp_chunk, elv_chunk, lat_chunk, co2, tmin_chunk, prec_chunk, cldp_chunk, ksat_chunk, whc_chunk, lon_chunk, diag,
                biome_var, wdom_var, gdom_var, npp_var, tcm_var, gdd0_var, gdd5_var, subpft_var, wetness_var,
                output_dataset,
                x_chunk_start
            )
        end

        if y % 10 == 0
            sync(output_dataset)
        end
    end
end

function process_cell(
    x, y, strx,
    temp_chunk, elv_chunk, lat_chunk, co2, tmin_chunk, prec_chunk, cldp_chunk, ksat_chunk, whc_chunk, lon_chunk, diag,
    biome_var, wdom_var, gdom_var, npp_var, tcm_var, gdd0_var, gdd5_var, subpft_var, wetness_var,
    output_dataset,
    x_chunk_start
)
    # Constants
    p0 = 101325.0  # sea level standard atmospheric pressure (Pa)
    cp = 1004.68506  # constant-pressure specific heat (J kg-1 K-1)
    T0 = 288.16    # sea level standard temperature (K)
    g = 9.80665    # earth surface gravitational acceleration (m s-1)
    M = 0.02896968 # molar mass of dry air (kg mol-1)
    R0 = 8.314462618  # universal gas constant (J mol-1 K-1)

    # Convert local indices to global indices
    x_global_index = x_chunk_start + x - strx
    y_global_index = y

    if biome_var[x_global_index, y_global_index] != -9999
        println("Cell ($x_global_index, $y_global_index) already processed, skipping.")
        return
    end

    if temp_chunk[x, y, 1] == -9999.0
        return
    end

    input = zeros(Float32, 50)
    output = zeros(Float32, 500)

    elv = elv_chunk[x, y]
    p = p0 * (1.0 - (g * elv) / (cp * T0))^(cp * M / R0)

    input[1] = lat_chunk[y]
    input[2] = co2
    input[3] = p
    input[4] = tmin_chunk[x, y]
    input[5:16] = temp_chunk[x, y, :]
    input[17:28] = prec_chunk[x, y, :]
    input[29:40] = cldp_chunk[x, y, :]
    input[41] = coalesce(mean(ksat_chunk[x, y, 1:2]), -9999.0f0)
    input[42] = coalesce(mean(ksat_chunk[x, y, 1:2]), -9999.0f0)
    input[43] = coalesce(whc_chunk[x, y, 1]/10, -9999.0f0)
    input[44] = coalesce(whc_chunk[x, y, 2]/10, -9999.0f0)
    input[49] = lon_chunk[x]

    input[46] = diag ? 1.0 : 0.0  # diagnostic mode

    output = BIOME4.biome4(input, output)

    # Write results to the output variables
    biome_var[x_global_index, y_global_index] = output[1]
    wdom_var[x_global_index, y_global_index] = output[12]
    gdom_var[x_global_index, y_global_index] = output[13]
    npp_var[x_global_index, y_global_index, :] = output[60:72]
    tcm_var[x_global_index, y_global_index] = output[452]
    gdd0_var[x_global_index, y_global_index] = output[453]
    gdd5_var[x_global_index, y_global_index] = output[454]
    subpft_var[x_global_index, y_global_index] = output[455]
    wetness_var[x_global_index, y_global_index] = output[10]

    println("Processed cell ($x_global_index, $y_global_index)")
end

# Function to load checkpoint
function load_checkpoint(checkpoint_file::String, strx::Int64)
    if isfile(checkpoint_file)
        # Read the checkpoint file to get the last processed chunk
        open(checkpoint_file, "r") do file
            checkpoint_data = readline(file)
            return parse(Int, checkpoint_data)
        end
    else
        # If no checkpoint file exists, start from the beginning
        return strx
    end
end

# Function to save checkpoint
function save_checkpoint(checkpoint_file::String, x_chunk_start::Int)
    open(checkpoint_file, "w") do file
        write(file, "$x_chunk_start\n")
    end
end

function nearest(value, array)
    # This function returns the index of the closest value in `array` to `value`
    idx = argmin(abs.(array .- value))
    return idx
end


function get_array_indices(lon_min, lon_max, lat_min, lat_max, resolution=0.5)
    """
    Get array indices for a given bounding box with specified resolution.
    Parameters:
    - lon_min: Minimum longitude (-180 to 180)
    - lon_max: Maximum longitude (-180 to 180)
    - lat_min: Minimum latitude (-90 to 90)
    - lat_max: Maximum latitude (-90 to 90)
    - resolution: Resolution of the array (default is 0.5 degrees)
    Returns:
    - strx, stry: Start coordinates in the array
    - cntx, cnty: Count of tiles in the array
    """
    # Define the array dimensions based on resolution
    lon_range = 360  # Longitude range from -180 to 180
    lat_range = 180  # Latitude range from -90 to 90

    array_width = Int(lon_range / resolution)  # Number of longitude points
    array_height = Int(lat_range / resolution)  # Number of latitude points

    # Calculate the indices
    strx = Int(round((lon_min + 180) / resolution))
    endx = Int(round((lon_max + 180) / resolution))
    stry = Int(round((lat_min + 90) / resolution))
    endy = Int(round((lat_max + 90) / resolution))

    # Handle edge cases
    if lon_min == -180
        strx = 1
    end

    if lon_max == 180
        endx = array_width
    end

    if lat_min == -90
        stry = 1
    end

    if lat_max == 90
        endy = array_height
    end

    # Calculate the counts
    cntx = endx - strx + 1
    cnty = endy - stry + 1

    return strx, stry, cntx, cnty
end


function handle_err(status)
    if status != 0
        println("NetCDF Error: $status")
        exit(1)
    end
end

function save_plot(plot_name::String, lon, lat, data, title::String, clims::Tuple, plot_folder::String, year::String)
    # Close any previous plot windows
    closeall()

    # Create the plot
    p = heatmap(lon, lat, data, xlabel = "Longitude", ylabel = "Latitude", title = title, clims = clims)

    # Define the output file path
    filepath = joinpath(plot_folder, @sprintf("%s_%s.png", plot_name, year))

    # Save the plot
    println("Saving plot to $filepath")
    savefig(p, filepath)

end


function uniform_fill_value(data::Array{T, N}; fill_value=-9999) where {T, N}
    """
    This function processes an array to replace `_FillValue` and `Missing` values with `fill_value`.
    It operates on a provided chunk of data instead of the entire dataset for efficiency.
    
    Parameters:
    - data: The data array to process.
    - fill_value: The value to replace _FillValue and Missing entries with (default is -9999).
    
    Returns:
    - Modified data array with _FillValue and Missing replaced.
    """
    # Replace Missing and _FillValue with the specified fill value
    data .= coalesce.(data, fill_value)
    return data
end


function parse_command_line()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--coordstring"
        help = "Coordinate string or 'alldata'"
        arg_type = String
        default = "alldata"

        "--outfile"
        help = "Output file"
        arg_type = String
        default = "output.nc"

        "--co2"
        help = "CO2 concentration"
        arg_type = Float64
        default = 400.0

        "--diagnosticmode"
        help = "Diagnostic mode"
        arg_type = Bool
        default = true

        "--tempfile"
        help = "Path to the temperature file"
        arg_type = String

        "--tminfile"
        help = "Path to the minimum temperature file"
        arg_type = String

        "--precfile"
        help = "Path to the precipitation file"
        arg_type = String

        "--sunfile"
        help = "Path to the cloud cover file"
        arg_type = String

        "--ksatfile"
        help = "Path to the  saturated conductivity file"
        arg_type = String

        "--whcfile"
        help = "Path to the water holding capacity file"
        arg_type = String

        "--year"
        help = "Year of prediction from the climatology files"
        arg_type = String

        "--resolution"
        help = "Resolution: 'low' or 'high'"
        arg_type = String
        default = "low"

        "--checkpoint_file"
        help = "Path to the checkpoint file'"
        arg_type = String
        default = "biome_checkpoint.txt"

    end
    return parse_args(s)
end

# Call the main function with parsed arguments
function main()
    args = parse_command_line()

    Biome4Driver.main(
        args["coordstring"],
        args["co2"],
        args["diagnosticmode"],
        args["tempfile"],
        args["tminfile"],
        args["precfile"],
        args["sunfile"],
        args["ksatfile"],
        args["whcfile"],
        args["year"],
        args["resolution"],
        args["checkpoint_file"]
    )
end

# Make sure main is called
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

end # End of module