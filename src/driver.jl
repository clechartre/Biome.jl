"""
    Biome4Driver

Main driver module for the BIOME model suite.

This module provides the command-line interface and data processing pipeline
for running various biome classification models including BIOME4, Wissmann,
Thornthwaite, Koppen-Geiger, and Troll-Pfaffen classifications.
"""

using Pkg
Pkg.instantiate() 

using BIOME   

# Standard library
using Base.Threads
using Base.Iterators
using Printf
using Statistics
using Dates
using Missings

# Third-party
using ArgParse
using ComponentArrays
using NCDatasets
using DataStructures: OrderedDict
using Plots
using DimensionalData
gr()

"""
    main(coordstring, co2, tempfile, precfile, sunfile, soilfile, year, model)

Main execution function for the BIOME model driver.

Processes climate and soil data for a specified region and time period,
applies the selected biome classification model, and writes results to
NetCDF output files.

# Arguments
- `coordstring::String`: Coordinate specification ("alldata" or "lon1/lon2/lat1/lat2")
- `co2::T`: Atmospheric CO2 concentration (ppm)
- `tempfile::String`: Path to NetCDF file containing temperature data
- `precfile::String`: Path to NetCDF file containing precipitation data
- `sunfile::String`: Path to NetCDF file containing cloud cover/sunshine data
- `soilfile::String`: Path to NetCDF file containing soil property data
- `year::String`: Year identifier for output filename
- `model::String`: Model type ("biome4", "wissmann", "thornthwaite", etc.)

# Notes
- Processes data in spatial chunks to manage memory usage
- Creates or appends to NetCDF output files
- Supports resume functionality for interrupted runs
- Handles missing data values appropriately
"""
function main(
    coordstring::String,
    co2::T,
    tempfile::String,
    precfile::String,
    sunfile::String,
    soilfile::String,
    year::String,
    model::String
) where {T<:Real}
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

    # Open the first dataset to get dimensions, then close
    temp_ds = NCDataset(tempfile, "a")
    lon_full = temp_ds["lon"][:]
    lat_full = temp_ds["lat"][:]
    xlen = length(lon_full)
    ylen = length(lat_full)
    llen = 2
    tlen = 12
    close(temp_ds)
    dz = T[5, 10, 15, 30, 40, 100]

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

        strx, stry, cntx, cnty = get_array_indices(
            lon_full, lat_full, lon_min, lon_max, lat_min, lat_max
        )

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
        output_dataset = NCDataset(outfile, "a")

        # Extract existing variables
        biome_var = output_dataset["biome"]
        wdom_var = output_dataset["wdom"]
        gdom_var = output_dataset["gdom"]
        npp_var = output_dataset["npp"]
        tcm_var = output_dataset["tcm"]
        gdd0_var = output_dataset["gdd0"]
        gdd5_var = output_dataset["gdd5"]
        subpft_var = output_dataset["subpft"]
        wetness_var = output_dataset["wetness"]
    else
        output_dataset = NCDataset(outfile, "c")

        # Define dimensions and variables if creating the file
        defDim(output_dataset, "lon", size(lon, 1))
        defDim(output_dataset, "lat", size(lat, 1))
        defDim(output_dataset, "time", llen)
        defDim(output_dataset, "months", tlen)
        defDim(output_dataset, "pft", 14)

        # Define variables with appropriate types and dimensions
        lon_var = defVar(
            output_dataset, "lon", T, ("lon",), 
            attrib=OrderedDict("units" => "degrees_east")
        )
        lat_var = defVar(
            output_dataset, "lat", T, ("lat",), 
            attrib=OrderedDict("units" => "degrees_north")
        )
        biome_var = defVar(
            output_dataset, "biome", Int16, ("lon", "lat"), 
            attrib=OrderedDict("description" => "Biome classification")
        )
        wdom_var = defVar(
            output_dataset, "wdom", Int16, ("lon", "lat"), 
            attrib=OrderedDict("description" => "Dominant woody vegetation")
        )
        gdom_var = defVar(
            output_dataset, "gdom", Int16, ("lon", "lat"), 
            attrib=OrderedDict("description" => "Dominant grass vegetation")
        )
        npp_var = defVar(
            output_dataset, "npp", T, ("lon", "lat", "pft"), 
            attrib=OrderedDict(
                "units" => "gC/m^2/month", 
                "description" => "Net primary productivity"
            )
        )
        tcm_var = defVar(
            output_dataset, "tcm", T, ("lon", "lat"), 
            attrib=OrderedDict("description" => "tcm")
        )
        gdd0_var = defVar(
            output_dataset, "gdd0", T, ("lon", "lat"), 
            attrib=OrderedDict("description" => "gdd0")
        )
        gdd5_var = defVar(
            output_dataset, "gdd5", T, ("lon", "lat"), 
            attrib=OrderedDict("description" => "gdd5")
        )
        subpft_var = defVar(
            output_dataset, "subpft", T, ("lon", "lat"), 
            attrib=OrderedDict("description" => "subpft")
        )
        wetness_var = defVar(
            output_dataset, "wetness", T, ("lon", "lat"), 
            attrib=OrderedDict("description" => "wetness")
        )

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
        npp_var[:, :, :] = fill(T(-9999.0), cntx, cnty, 14)
        tcm_var[:, :] = fill(T(-9999.0), cntx, cnty)
        gdd0_var[:, :] = fill(T(-9999.0), cntx, cnty)
        gdd5_var[:, :] = fill(T(-9999.0), cntx, cnty)
        subpft_var[:, :] = fill(T(-9999.0), cntx, cnty)
        wetness_var[:, :] = fill(T(-9999.0), cntx, cnty)
    end

    # Set up chunking variables
    x_chunk_size = 1000
    chunk_size = x_chunk_size
    lat_chunk = nothing

    # Read latitude (only once since it's the same for all x chunks)
    Dataset(tempfile) do ds
        lat_chunk = ds["lat"][stry:endy]
    end

    for x_chunk_start in strx:chunk_size:endx
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
        tmin_chunk = ifelse.(
            tcm_chunk .!= missval_sp, 
            T(0.006) .* tcm_chunk.^2 .+ T(1.316) .* tcm_chunk .- T(21.9), 
            missval_sp
        )

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
            dz = ds["dz"][:]
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

        println("max temp: ", maximum(temp_chunk), ", min temp: ", minimum(temp_chunk))
        println("max tmin: ", maximum(tmin_chunk), ", min tmin: ", minimum(tmin_chunk))
        println("max prec: ", maximum(prec_chunk), ", min prec: ", minimum(prec_chunk))
        println("max cldp: ", maximum(cldp_chunk), ", min cldp: ", minimum(cldp_chunk))
        println("max ksat: ", maximum(ksat_chunk), ", min ksat: ", minimum(ksat_chunk))
        println("max whc: ", maximum(whc_chunk), ", min whc: ", minimum(whc_chunk))

        # Instantiate the PFTs before going into pixels
        PFTS = PFTClassification()

        # Process the data in this chunk
        process_chunk(
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
            strx,
            model_instance,
            PFTS
        )
    end

    # Close the NetCDF file
    close(output_dataset)
end

"""
    process_chunk(current_chunk_size, cnty, temp_chunk, elv_chunk, lat_chunk, co2, tmin_chunk, prec_chunk, cldp_chunk, ksat_chunk, whc_chunk, dz, lon_chunk, biome_var, wdom_var, gdom_var, npp_var, tcm_var, gdd0_var, gdd5_var, subpft_var, wetness_var, output_dataset, strx, model_instance)

Process a spatial chunk of data by iterating through grid cells.

Handles parallel processing of a spatial chunk, skipping already processed
cells and managing data synchronization with the output file.

# Arguments
- `current_chunk_size`: Number of longitude indices in current chunk
- `cnty`: Number of latitude indices
- `temp_chunk`: Temperature data chunk (x, y, month)
- `elv_chunk`: Elevation data chunk (x, y)
- `lat_chunk`: Latitude values for chunk
- `co2`: CO2 concentration
- `tmin_chunk`: Minimum temperature chunk (x, y)
- `prec_chunk`: Precipitation data chunk (x, y, month)
- `cldp_chunk`: Cloud cover data chunk (x, y, month)
- `ksat_chunk`: Saturated conductivity chunk (x, y, layer)
- `whc_chunk`: Water holding capacity chunk (x, y, layer)
- `dz`: Soil layer thickness vector
- `lon_chunk`: Longitude values for chunk
- `*_var`: NetCDF output variables
- `output_dataset`: NetCDF dataset handle
- `strx`: Starting x index in global grid
- `model_instance`: Biome model instance to run

# Notes
- Skips cells that are already processed (non-missing values)
- Synchronizes output every 10 rows to prevent data loss
- Handles missing data appropriately
"""
function process_chunk(
    current_chunk_size, cnty,
    temp_chunk, elv_chunk, lat_chunk, co2, tmin_chunk, 
    prec_chunk, cldp_chunk, ksat_chunk, whc_chunk, dz, 
    lon_chunk, biome_var, wdom_var, gdom_var, 
    npp_var, tcm_var, gdd0_var, gdd5_var, subpft_var, wetness_var,
    output_dataset, strx, model_instance::BiomeModel, PFTS::AbstractPFTList
)
    for y in 1:cnty
        println("Serially processing y index $y")

        y_global_index = y

        # Check if the row is already processed. If yes, skip
        if all(biome_var[:, y_global_index] .!= -9999.0)
            continue
        end

        for x in 1:current_chunk_size
            if temp_chunk[x, y, 1] == -9999.0 || (whc_chunk[x, y, :] == -9999.0)
                continue
            end

            process_cell(
                x, y, strx, temp_chunk, elv_chunk, lat_chunk, co2, tmin_chunk, 
                prec_chunk, cldp_chunk, ksat_chunk, whc_chunk,
                dz, lon_chunk, biome_var, wdom_var, gdom_var, npp_var, 
                tcm_var, gdd0_var, gdd5_var, subpft_var, wetness_var, 
                model_instance, PFTS
            )
        end

        if y % 10 == 0
            sync(output_dataset)
        end
    end
end

"""
    process_cell(x, y, strx, temp_chunk, elv_chunk, lat_chunk, co2, tmin_chunk, prec_chunk, cldp_chunk, ksat_chunk, whc_chunk, dz, lon_chunk, biome_var, wdom_var, gdom_var, npp_var, tcm_var, gdd0_var, gdd5_var, subpft_var, wetness_var, model)

Process a single grid cell for biome classification.

Extracts data for a single grid cell, prepares model inputs, runs the 
selected biome model, and writes results to output variables.

# Arguments
- `x, y`: Local indices within the current chunk
- `strx`: Starting x index in global grid
- Various `*_chunk` arrays: Climate and soil data for the chunk
- `dz`: Soil layer thickness vector
- `lon_chunk`: Longitude values for chunk
- Various `*_var`: NetCDF output variables to write to
- `model`: Biome model instance to run

# Notes
- Skips already processed cells to support resume functionality
- Calculates atmospheric pressure from elevation
- Aggregates soil properties by layer
- Formats input vector for model execution
- Handles coordinate transformations between local and global indices
"""
function process_cell(
    x, y, strx,
    temp_chunk, elv_chunk, lat_chunk, co2::T, tmin_chunk, 
    prec_chunk, cldp_chunk, ksat_chunk, whc_chunk, dz, 
    lon_chunk,
    biome_var, wdom_var, gdom_var, npp_var, tcm_var, gdd0_var,
    gdd5_var, subpft_var, wetness_var, model::BiomeModel, PFTS::AbstractPFTList
) where {T<:Real}
    # Convert local indices to global indices
    x_global_index = x
    y_global_index = y

    if biome_var[x_global_index, y_global_index] != -9999
        println("Cell ($x_global_index, $y_global_index) already processed, skipping.")
        return
    end

    if temp_chunk[x, y, :] == -9999.0 || (whc_chunk[x, y, :] == -9999.0)
        return
    end    

    elv = elv_chunk[x, y]
    # Calculate atmospheric pressure from elevation
    p = P0 * (1.0 - (G * elv) / (CP * T0))^(CP * M / R0)

    input = zeros(T, 50)

    input[1] = lat_chunk[y]
    input[2] = co2
    input[3] = p
    input[4] = tmin_chunk[x, y]
    input[5:16] .= temp_chunk[x, y, :]
    input[17:28] .= prec_chunk[x, y, :]
    input[29:40] .= cldp_chunk[x, y, :]
    input[41] = sum(ksat_chunk[x, y, 1:3] .* dz[1:3]) / sum(dz[1:3])
    input[42] = sum(ksat_chunk[x, y, 4:6] .* dz[4:6]) / sum(dz[4:6])
    input[43] = sum(whc_chunk[x, y, 1:3] .* dz[1:3])
    input[44] = sum(whc_chunk[x, y, 4:6] .* dz[4:6])
    input[49] = lon_chunk[x]

    # Run the model 
    output = BIOME.run(model, input, PFTS)

    # Write results to the output variables
    biome_var[x_global_index, y_global_index] = output[1]
    wdom_var[x_global_index, y_global_index] = output[2]
    npp_var[x_global_index, y_global_index, :] = output[3:16]
end

"""
    round_to_nearest(value, base=0.05)

Round a floating-point value to the nearest multiple of a base value.

# Arguments
- `value::T`: Value to round
- `base::T`: Base value to round to (default: 0.05)

# Returns
- Rounded value as multiple of base
"""
function round_to_nearest(value::T, base::T=T(0.05)) where {T<:AbstractFloat}
    return round(value / base) * base
end

"""
    get_array_indices(lon_full, lat_full, lon_min, lon_max, lat_min, lat_max)

Calculate array indices for a geographic bounding box.

Determines the start indices and counts for longitude and latitude arrays
based on specified geographic bounds.

# Arguments
- `lon_full, lat_full`: Full coordinate arrays
- `lon_min, lon_max, lat_min, lat_max`: Geographic bounding box coordinates

# Returns
- `strx, stry`: Starting indices for longitude and latitude
- `cntx, cnty`: Counts of elements in longitude and latitude directions

# Notes
- Requires sorted coordinate arrays
- Handles both ascending and descending latitude arrays
- Does not support longitude wrapping around 180°
"""
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

"""
    uniform_fill_value(data; fill_value=-9999.0)

Replace missing and fill values with a uniform fill value.

Replaces `_FillValue` and `Missing` values with the specified `fill_value`
to ensure consistent handling of missing data throughout the processing pipeline.

# Arguments
- `data::Array{T,N}`: Input data array
- `fill_value`: Value to use for missing data (default: -9999.0)

# Returns
- Modified array with uniform fill values

# Notes
- Converts fill_value to match the input array type
- Uses `coalesce` to handle both missing and existing fill values
"""
function uniform_fill_value(data::Array{T,N}; fill_value=-9999.0) where {T,N}
    fill_value = convert(T, fill_value)
    data .= coalesce.(data, fill_value)
    return data
end

"""
    parse_command_line()

Parse command-line arguments for the BIOME model driver.

Sets up argument parsing for all required and optional parameters needed
to run the biome classification models.

# Returns
- Dictionary of parsed command-line arguments

# Arguments Parsed
- `--coordstring`: Geographic bounds or "alldata"
- `--outfile`: Output NetCDF filename
- `--co2`: Atmospheric CO2 concentration (ppm)
- `--tempfile, --precfile, --sunfile, --soilfile`: Input data file paths
- `--year`: Year identifier for output
- `--model`: Model type to run
"""
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

        "--model"
        help = "Which prediction model to use"
        arg_type = String
        default = "biome4"
    end
    return parse_args(s)
end

"""
    main()

Entry point for command-line execution.

Parses command-line arguments and calls the main processing function
with the appropriate parameters.
"""
function main()
    args = parse_command_line()

    main(
        args["coordstring"],
        args["co2"],
        args["tempfile"],
        args["precfile"],
        args["sunfile"],
        args["soilfile"],
        args["year"],
        args["model"]
    )
end

# Make sure main is called
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
# End of module