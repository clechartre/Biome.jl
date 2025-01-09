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
include("../model.jl")
include("./biome4.jl")
include("./models/koppenbiomes.jl")
include("./models/thornthwaitebiomes.jl")
include("./models/trollpfaffenbiomes.jl")
include("./models/wissmannbiomes.jl")

function main(
    coordstring::String,
    co2::T,
    diagnosticmode::Bool,
    tempfile::String,
    precfile::String,
    sunfile::String,
    soilfile::String,
    year::String,
    checkpoint_file::String,
    model::String
) where {T <: Real}

    # Check the model in use
    model_instance = if model == "biome4"
        BIOME4Model()
    elseif model == "wissmann"
        WissmannModel()
    elseif model == "thornthwaite"
        ThornthwaiteModel()
    elseif model == "koppengeiger"
        KoppenModel()
    elseif model == "trollpfaffen"
        TrollPfaffenModel()
    else
        error("Unknown model: $model")
    end

    # Chunk and checkpoint parameters
    chunk_size = 1000 # For functioning on node/debug, 100 works

    # Open the first dataset just to get the dimensions for the output, then close again
    temp_ds = NCDataset(tempfile, "a")
    lon_full = temp_ds["lon"][:]  # Keep lon and lat as they are, cut according to bbox
    lat_full = temp_ds["lat"][:]
    # Now hardcoded will be determined by whc
    xlen = length(lon_full)
    ylen = length(lat_full)
    llen = 2
    tlen = 12
    close(temp_ds)
    dz = T[5, 10, 15, 30, 40, 100 ]

    if coordstring == "alldata"
        strx = 1
        stry = 1
        cntx = xlen
        cnty = ylen
        endx = strx + cntx - 1
        endy = stry + cnty - 1
    else
        boundingbox = [parse(T, x) for x in split(coordstring, "/")]
        lon_min = boundingbox[1]
        lon_max = boundingbox[2]
        lat_min = boundingbox[3]
        lat_max = boundingbox[4]

        strx, stry, cntx, cnty = get_array_indices(lon_full, lat_full, lon_min, lon_max, lat_min, lat_max)

        endx = strx + cntx - 1
        endy = stry + cnty - 1
    end

    println("Bounding box indices: strx=$strx, stry=$stry, endx=$endx, endy=$endy")
    println("Bounding box counts: cntx=$cntx, cnty=$cnty")

    lon = lon_full[strx:endx]
    lat = lat_full[stry:endy]

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
        # # println("File $outfile does not exist. Creating a new file.")
        output_dataset = NCDataset(outfile, "c")

        # Define dimensions and variables if creating the file
        defDim(output_dataset, "lon", size(lon, 1))
        defDim(output_dataset, "lat", size(lat, 1))
        defDim(output_dataset, "time", llen)
        defDim(output_dataset, "months", tlen)
        defDim(output_dataset, "pft", 13)

        # Define variables with appropriate types and dimensions
        lon_var = defVar(output_dataset, "lon", T, ("lon",), attrib = OrderedDict("units" => "degrees_east"))
        lat_var = defVar(output_dataset, "lat", T, ("lat",), attrib = OrderedDict("units" => "degrees_north"))
        biome_var = defVar(output_dataset, "biome", Int16, ("lon", "lat"), attrib = OrderedDict("description" => "Biome classification"))
        wdom_var = defVar(output_dataset, "wdom", T, ("lon", "lat"), attrib = OrderedDict("description" => "Dominant woody vegetation"))
        gdom_var = defVar(output_dataset, "gdom", T, ("lon", "lat"), attrib = OrderedDict("description" => "Dominant grass vegetation"))
        npp_var = defVar(output_dataset, "npp", T, ("lon", "lat", "pft"), attrib = OrderedDict("units" => "gC/m^2/month", "description" => "Net primary productivity"))
        tcm_var = defVar(output_dataset, "tcm", T, ("lon", "lat"), attrib = OrderedDict("description" => "tcm"))
        gdd0_var = defVar(output_dataset, "gdd0", T, ("lon", "lat"), attrib = OrderedDict("description" => "gdd0"))
        gdd5_var = defVar(output_dataset, "gdd5", T, ("lon", "lat"), attrib = OrderedDict("description" => "gdd5"))
        subpft_var = defVar(output_dataset, "subpft", T, ("lon", "lat"), attrib = OrderedDict("description" => "subpft"))
        wetness_var = defVar(output_dataset, "wetness", T, ("lon", "lat"), attrib = OrderedDict("description" => "wetness"))

        # Add global attributes to the dataset
        output_dataset.attrib["title"] = "Biome prediction output"
        output_dataset.attrib["institution"] = "WSL"
        output_dataset.attrib["source"] = "BIOME4 Model"

        # Fill with placeholder values initially
        lon_var[:] = lon
        lat_var[:] = lat
        biome_var[:, :] = fill(T(-9999.0), cntx, cnty)
        wdom_var[:, :] = fill(T(-9999.0), cntx, cnty)
        gdom_var[:, :] = fill(T(-9999.0), cntx, cnty)
        npp_var[:, :, :] = fill(T(-9999.0), cntx, cnty, 13)
        tcm_var[:, :] = fill(T(-9999.0), cntx, cnty)
        gdd0_var[:, :] = fill(T(-9999.0), cntx, cnty)
        gdd5_var[:, :] = fill(T(-9999.0), cntx, cnty)
        subpft_var[:, :] = fill(T(-9999.0), cntx, cnty)
        wetness_var[:, :] = fill(T(-9999.0), cntx, cnty)
    end

    # Load checkpoint
    x_chunk_start = load_checkpoint(checkpoint_file, strx)
    # Ensure x_chunk_start is at least strx
    x_chunk_start = max(x_chunk_start, strx)
    println("Resuming from x_chunk_start: $x_chunk_start")

    # Set up chunking variables
    x_chunk_size = chunk_size
    lat_chunk = nothing

    # Read latitude (only once since it's the same for all x chunks)
    Dataset(tempfile) do ds
        lat_chunk = ds["lat"][stry:endy]
    end

    for x_chunk_start in x_chunk_start:chunk_size:endx
        x_chunk_end = min(x_chunk_start + x_chunk_size - 1, endx)
        current_chunk_size = x_chunk_end - x_chunk_start + 1

        println("Processing x indices from $x_chunk_start to $x_chunk_end")

        # Initialize variables for this chunk
        temp_chunk = zeros(T, (current_chunk_size, cnty, 12))
        tmin_chunk = zeros(T, (current_chunk_size, cnty))
        prec_chunk = zeros(T, (current_chunk_size, cnty, 12))
        cldp_chunk = zeros(T, (current_chunk_size, cnty, 12))
        ksat_chunk = zeros(T, (current_chunk_size, cnty, 2))
        whc_chunk = zeros(T, (current_chunk_size, cnty, 2))
        elv_chunk = zeros(T, (current_chunk_size, cnty))

        # Read longitude for this chunk
        lon_chunk = lon_full[x_chunk_start:x_chunk_end]

        Dataset(tempfile) do ds
            temp_chunk = ds["temp"][x_chunk_start:x_chunk_end, stry:endy, :]
            temp_chunk = uniform_fill_value(temp_chunk)
        end

        # Compute tcm_chunk as the minimum of temp_chunk over months
        tcm_chunk = minimum(temp_chunk, dims=3)

        # Define missing value
        missval_sp = T(-9999.0)

        # Ensure the calculation is applied element-wise, skipping -9999
        tmin_chunk = ifelse.(tcm_chunk .!= missval_sp, T(0.006) .* tcm_chunk.^2 .+ T(1.316) .* tcm_chunk .- T(21.9), missval_sp)


        Dataset(precfile) do ds
            prec_chunk = ds["prec"][x_chunk_start:x_chunk_end, stry:endy, :]
            prec_chunk = uniform_fill_value(prec_chunk)
        end

        Dataset(sunfile) do ds
            cldp_chunk = ds["sun"][x_chunk_start:x_chunk_end, stry:endy, :]
            cldp_chunk = uniform_fill_value(cldp_chunk)
        end

        Dataset(soilfile) do ds
            ksat_chunk = ds["Ksat"][x_chunk_start:x_chunk_end, stry:endy, :]
            ksat_chunk = uniform_fill_value(ksat_chunk)
            whc_chunk = ds["whc"][x_chunk_start:x_chunk_end, stry:endy, :]
            whc_chunk = uniform_fill_value(whc_chunk)
            dz = ds["dz"][:] # is a list
        end


        # Read elevation data if available
        if @isdefined(elvfile) && isfile(elvfile)
            Dataset(elvfile) do ds
                elv_chunk = ds["elv"][x_chunk_start:x_chunk_end, stry:endy]
                elv_chunk = uniform_fill_value(elv_chunk)
            end
        else
            elv_chunk = zeros(T, (current_chunk_size, cnty))
        end

        # Flip the data arrays along the latitude axis if necessary
        # Adjust this section based on your data's orientation
        temp_chunk = temp_chunk[:, :, :]
        tmin_chunk = tmin_chunk[:, :]
        prec_chunk = prec_chunk[:, :, :]
        cldp_chunk = cldp_chunk[:, :, :]
        ksat_chunk = ksat_chunk[:, :, :]
        whc_chunk = whc_chunk[:, :, :]
        elv_chunk = elv_chunk[:, :]

        println("max temp: ", maximum(temp_chunk), ", min temp: ", minimum(temp_chunk))
        println("max tmin: ", maximum(tmin_chunk), ", min tmin: ", minimum(tmin_chunk))
        println("max prec: ", maximum(prec_chunk), ", min prec: ", minimum(prec_chunk))
        println("max cldp: ", maximum(cldp_chunk), ", min cldp: ", minimum(cldp_chunk))
        println("max ksat: ", maximum(ksat_chunk), ", min ksat: ", minimum(ksat_chunk))
        println("max whc: ", maximum(whc_chunk), ", min whc: ", minimum(whc_chunk))

        # Process the data in this chunk
        serial_process_chunk(
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
            dz, 
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
            endy,
            model_instance
        )

        # Save the checkpoint after processing the chunk
        save_checkpoint(checkpoint_file, x_chunk_start)
    end

    # Close the NetCDF file
    close(output_dataset)
end


function parallel_process_chunk(
    current_chunk_size, cnty,
    temp_chunk, elv_chunk, lat_chunk, co2, tmin_chunk, prec_chunk, cldp_chunk, ksat_chunk, whc_chunk, dz, lon_chunk, diag,
    biome_var, wdom_var, gdom_var, npp_var, tcm_var, gdd0_var, gdd5_var, subpft_var, wetness_var,
    output_dataset, x_chunk_start, strx, stry, endy, model_instance::BiomeModel
)where {T <: Real}
    # Container to hold the spawned tasks (futures)
    futures = []

    for y in 1:cnty
        println("Parallel processing y index $y")

        # Skip already processed rows
        y_global_index = y
        if all(biome_var[:, y_global_index] .!= -9999)
            println("Skipping already processed row: $y")
            continue
        end

        # Spawn a single task to process all x indices at once for this y
        push!(futures, Threads.@spawn begin
            for x in 1:current_chunk_size
                process_cell(
                    x, y, strx,temp_chunk, elv_chunk, lat_chunk, co2, tmin_chunk, prec_chunk, cldp_chunk,
                    ksat_chunk, whc_chunk, dz, lon_chunk, diag, biome_var, wdom_var, gdom_var, npp_var,
                    tcm_var, gdd0_var, gdd5_var, subpft_var, wetness_var,output_dataset, x_chunk_start, model_instance
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
    temp_chunk, elv_chunk, lat_chunk, co2, tmin_chunk, prec_chunk, cldp_chunk, ksat_chunk, whc_chunk, dz,  lon_chunk, diag,
    biome_var, wdom_var, gdom_var, npp_var, tcm_var, gdd0_var, gdd5_var, subpft_var, wetness_var,
    output_dataset, x_chunk_start, strx, stry, endy, model_instance::BiomeModel
)where {T <: Real}
    for y in 1:cnty
        println("Serially processing y index $y")

        y_global_index = y

        # Check if the row is already processed. If yes, skip
        if all(biome_var[:, y_global_index] .!= -9999.0)
            continue
        end

        for x in 1:current_chunk_size
            x_global_index = x_chunk_start - strx + x

            if temp_chunk[x, y, 1] == -9999.0 || (whc_chunk[x, y, :] == -9999.0)
                continue
            end

            process_cell(
                x, y, strx, temp_chunk, elv_chunk, lat_chunk, co2, tmin_chunk, prec_chunk, cldp_chunk, ksat_chunk, whc_chunk,
                dz, lon_chunk, diag, biome_var, wdom_var, gdom_var, npp_var, tcm_var, gdd0_var, gdd5_var, subpft_var, wetness_var,
                output_dataset,x_chunk_start, model_instance
            )
        end

        if y % 10 == 0
            sync(output_dataset)
        end
    end
end

function process_cell(
    x, y, strx,
    temp_chunk, elv_chunk, lat_chunk, co2::T, tmin_chunk, prec_chunk, cldp_chunk, ksat_chunk, whc_chunk, dz, lon_chunk, diag,
    biome_var, wdom_var, gdom_var, npp_var, tcm_var, gdd0_var, gdd5_var, subpft_var, wetness_var,
    output_dataset, x_chunk_start, model::BiomeModel
)where {T <:Real}
    # Constants
    p0 = T(101325.0)  # sea level standard atmospheric pressure (Pa)
    cp = T(1004.68506 ) # constant-pressure specific heat (J kg-1 K-1)
    T0 = T(288.16)    # sea level standard temperature (K)
    g = T(9.80665)    # earth surface gravitational acceleration (m s-1)
    M = T(0.02896968) # molar mass of dry air (kg mol-1)
    R0 = T(8.314462618)  # universal gas constant (J mol-1 K-1)

    # Convert local indices to global indices
    x_global_index = x_chunk_start - strx + x
    y_global_index = y

    if biome_var[x_global_index, y_global_index] != -9999
        println("Cell ($x_global_index, $y_global_index) already processed, skipping.")
        return
    end

    if temp_chunk[x, y, :] == -9999.0 || (whc_chunk[x, y, :] == -9999.0)
        return
    end    

    input = zeros(T, 50)
    output = zeros(T, 500)

    elv = elv_chunk[x, y]
    p = p0 * (1.0 - (g * elv) / (cp * T0))^(cp * M / R0)

    input[1] = lat_chunk[y]
    input[2] = co2
    input[3] = p
    input[4] = tmin_chunk[x, y]
    input[5:16] .= temp_chunk[x, y, :]
    input[17:28] .= prec_chunk[x, y, :]
    input[29:40] .= cldp_chunk[x, y, :]
    input[41] = sum(ksat_chunk[x, y, 1:3] .* dz[1:3]) / sum(dz[1:3])
    input[42] = sum(ksat_chunk[x, y, 4:6] .* dz[4:6]) / sum(dz[4:6])
    input[43] = sum(whc_chunk[x, y, 1:3] .* dz[1:3])  # in mm/cm
    input[44] = sum(whc_chunk[x, y, 4:6] .* dz[4:6])  # in mm/cm    

    input[49] = lon_chunk[x]

    input[46] = diag ? 1.0 : 0.0  # diagnostic mode

    # Run the model 
    output = run(model, input, output)

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

end

# Function to load checkpoint
function load_checkpoint(checkpoint_file::String, strx::U)where {U <: Int}
    if isfile(checkpoint_file)
        # Read the checkpoint file to get the last processed chunk
        open(checkpoint_file, "r") do file
            checkpoint_data = readline(file)
            return parse(U, checkpoint_data)
        end
    else
        # If no checkpoint file exists, start from the beginning
        return strx
    end
end

function round_to_nearest(value::T, base::T = 0.05) where {T <: AbstractFloat}
    return round(value / base) * base
end

# Function to save checkpoint
function save_checkpoint(checkpoint_file::String, x_chunk_start::U)where { U <: Int}
    open(checkpoint_file, "w") do file
        write(file, "$x_chunk_start\n")
    end
end

function get_array_indices(lon_full, lat_full, lon_min, lon_max, lat_min, lat_max)
    # Ensure longitude and latitude arrays are sorted
    lon_sorted = issorted(lon_full)
    lat_sorted = issorted(lat_full) || issorted(lat_full, rev=true)
    if !lon_sorted || !lat_sorted
        error("Longitude and latitude arrays must be sorted")
    end

    # Check if longitude wraps around
    if lon_min > lon_max
        error("Bounding box longitude min is greater than max, wrapping not supported")
    end

    # Find indices for longitude
    strx = findfirst(x -> x >= lon_min, lon_full)
    endx = findlast(x -> x <= lon_max, lon_full)

    # Find indices for latitude
    if lat_full[1] > lat_full[end]
        # Latitude array is in descending order
        stry = findfirst(y -> y <= lat_max, lat_full)
        endy = findlast(y -> y >= lat_min, lat_full)
    else
        # Latitude array is in ascending order
        stry = findfirst(y -> y >= lat_min, lat_full)
        endy = findlast(y -> y <= lat_max, lat_full)
    end

    # Handle cases where indices are not found
    if isnothing(strx) || isnothing(endx) || isnothing(stry) || isnothing(endy)
        error("Bounding box coordinates are outside the range of the data")
    end

    cntx = endx - strx + 1
    cnty = endy - stry + 1

    return strx, stry, cntx, cnty
end

function uniform_fill_value(data::Array{T, N}; fill_value=-9999.0) where {T, N}
    """
    Replaces `_FillValue` and `Missing` values with the specified `fill_value`.
    """
    fill_value = convert(T, fill_value)  # Convert fill_value to match the array type
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
        arg_type = T
        default = 400.0

        "--diagnosticmode"
        help = "Diagnostic mode"
        arg_type = Bool
        default = true

        "--tempfile"
        help = "Path to the temperature file"
        arg_type = String

        "--precfile"
        help = "Path to the precipitation file"
        arg_type = String

        "--sunfile"
        help = "Path to the cloud cover file"
        arg_type = String

        "--soilfile"
        help = "Path to the saturated conductivity file"
        arg_type = String

        "--year"
        help = "Year of prediction from the climatology files"
        arg_type = String

        "--checkpoint_file"
        help = "Path to the checkpoint file"
        arg_type = String
        default = "biome_checkpoint.txt"

        "--model"
        help = "Which prediction model to use"
        arg_type = String # Make this a choice out of a list of options
        default = "biome4"

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
        args["precfile"],
        args["sunfile"],
        args["soilfile"],
        args["year"],
        args["checkpoint_file"],
        args["model"]
    )
end

# Make sure main is called
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

end # End of module