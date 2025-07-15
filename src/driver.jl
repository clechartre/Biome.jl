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
using Statistics
using Missings

# Third-party
using ArgParse
using NCDatasets
import ArchGDAL # Dependency to Rasters
using Rasters
using DataStructures: OrderedDict
using DimensionalData


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
    elseif model == "dominance"
        BIOMEDominanceModel()
    else
        error("Unknown model: $model")
    end

    # Open the first dataset to get dimensions, then close
    temp_raster = Raster(tempfile)
    lon_full = collect(dims(temp_raster, X))
    lat_full = collect(dims(temp_raster, Y))
    xlen = length(lon_full)
    ylen = length(lat_full)
    dz = T[5, 10, 15, 30, 40, 100]

    if coordstring == "alldata"
        strx = 1
        stry = 1
        cntx = xlen
        cnty = ylen
        endx = strx + cntx - 1
        endy = stry + cnty - 1
    else
        coords = parse_coordinates(coordstring)
        strx, stry, cntx, cnty = get_array_indices(lon_full, lat_full, coords...)
        endx = strx + cntx - 1
        endy = stry + cnty - 1
    end

    println("Bounding box indices: strx=$strx, stry=$stry, endx=$endx, endy=$endy")
    println("Bounding box counts: cntx=$cntx, cnty=$cnty")

    lon = lon_full[strx:endx]
    lat = lat_full[stry:endy]

    # Dynamically create the output filename
    outfile = "./output_$(model)_$(year).nc"
    
    if isfile(outfile)
        println("File $outfile already exists. Resuming from last processed row.")
        output_dataset = NCDataset(outfile, "a")
        output_stack = load_existing_rasterstack(output_dataset, model_instance, lon, lat)
    else
        output_dataset = NCDataset(outfile, "c")
        println("Creating new output file: $outfile")
        create_output_variables(output_dataset, model_instance, lon, lat, cntx, cnty)
        output_stack = create_output_rasterstack(model_instance, lon, lat, cntx, cnty)
    end

    # Set up chunking variables
    x_chunk_size = 1000
    chunk_size = x_chunk_size

    # Read latitude (only once since it's the same for all x chunks)
    lat_chunk = collect(dims(temp_raster, Y))[stry:endy]

    for x_chunk_start in strx:chunk_size:endx
        x_chunk_end = min(x_chunk_start + x_chunk_size - 1, endx)
        current_chunk_size = x_chunk_end - x_chunk_start + 1

        println("Processing x indices from $x_chunk_start to $x_chunk_end")

        # Read longitude for this chunk
        lon_chunk = lon_full[x_chunk_start:x_chunk_end]

        # Read temperature data
        temp_raster = Raster(tempfile, name = "temp")
        temp_chunk = temp_raster[x_chunk_start:x_chunk_end, stry:endy, :]
        temp_chunk = Array(temp_chunk)
        temp_chunk = uniform_fill_value(temp_chunk)

        # Compute tcm_chunk as the minimum of temp_chunk over months
        tcm_chunk = minimum(temp_chunk, dims=3)

        # Define missing value
        missval_sp = T(-9999.0)

        # Calculate tmin_chunk
        tmin_chunk = ifelse.(
            tcm_chunk .!= missval_sp, 
            T(0.006) .* tcm_chunk.^2 .+ T(1.316) .* tcm_chunk .- T(21.9), 
            missval_sp
        )

        # Read precipitation data
        prec_raster = Raster(precfile, name = "prec")
        prec_chunk = prec_raster[x_chunk_start:x_chunk_end, stry:endy, :]
        prec_chunk = Array(prec_chunk)
        prec_chunk = uniform_fill_value(prec_chunk)

        # Read cloud/sun data
        sun_raster = Raster(sunfile, name = "sun")
        cldp_chunk = sun_raster[x_chunk_start:x_chunk_end, stry:endy, :]
        cldp_chunk = Array(cldp_chunk)
        cldp_chunk = uniform_fill_value(cldp_chunk)

        # Read soil data
        ksat_raster = Raster(soilfile, name = "Ksat")
        ksat_chunk = ksat_raster[x_chunk_start:x_chunk_end, stry:endy, :]
        ksat_chunk = Array(ksat_chunk)
        ksat_chunk = uniform_fill_value(ksat_chunk)

        whc_raster = Raster(soilfile, name = "whc")
        whc_chunk = whc_raster[x_chunk_start:x_chunk_end, stry:endy, :]
        whc_chunk = Array(whc_chunk)
        whc_chunk = uniform_fill_value(whc_chunk)

        # Read elevation data if available
        if @isdefined(elvfile) && isfile(elvfile)
            elv_raster = Raster(elvfile)
            elv_chunk = elv_raster[x_chunk_start:x_chunk_end, stry:endy]
            elv_chunk = Array(elv_chunk)
            elv_chunk = uniform_fill_value(elv_chunk)
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
            output_stack,  # Changed to RasterStack
            output_dataset,
            strx,
            model_instance,
            PFTS
        )
    end

    # Final sync before closing
    sync_rasterstack_to_netcdf(output_stack, output_dataset, model_instance)
    close(output_dataset)
end

"""
    create_output_rasterstack(model::BiomeModel, lon, lat, cntx, cnty)

Create a RasterStack for output variables based on the model type.
"""
function create_output_rasterstack(model::BiomeModel, lon, lat, cntx, cnty)
    # Create coordinate dimensions
    lon_dim = X(lon)
    lat_dim = Y(lat)
    
    # Get model schema
    schema = get_output_schema(model)
    
    # Create rasters for each variable
    rasters = []
    
    for (var_name, var_info) in schema
        if var_info.dims == ("lon", "lat")
            raster = Raster(
                fill(-9999.0, cntx, cnty),
                dims=(lon_dim, lat_dim),
                name=Symbol(var_name)
            )
        elseif var_info.dims == ("lon", "lat", "pft")
            pft_dim = Dim{:pft}(1:14)
            raster = Raster(
                fill(-9999.0, cntx, cnty, 14),
                dims=(lon_dim, lat_dim, pft_dim),
                name=Symbol(var_name)
            )
        end
        push!(rasters, raster)
    end
    
    # Convert to tuple and create RasterStack
    return RasterStack(Tuple(rasters))
end

"""
    load_existing_rasterstack(dataset, model, lon, lat)

Load existing data from NetCDF into a RasterStack for resume functionality.
"""
function load_existing_rasterstack(dataset, model::BiomeModel, lon, lat)
    # Create coordinate dimensions
    lon_dim = X(lon)
    lat_dim = Y(lat)
    
    # Get model schema
    schema = get_output_schema(model)
    
    # Load existing rasters
    rasters = []
    
    for (var_name, var_info) in schema
        if haskey(dataset, var_name)
            if var_info.dims == ("lon", "lat")
                data = Array(dataset[var_name][:, :])
                raster = Raster(
                    data,
                    dims=(lon_dim, lat_dim),
                    name=Symbol(var_name)
                )
            elseif var_info.dims == ("lon", "lat", "pft")
                pft_dim = Dim{:pft}(1:14)
                data = Array(dataset[var_name][:, :, :])
                raster = Raster(
                    data,
                    dims=(lon_dim, lat_dim, pft_dim),
                    name=Symbol(var_name)
                )
            end
            push!(rasters, raster)
        end
    end
    
    # Convert to tuple and create RasterStack
    return RasterStack(Tuple(rasters))
end

"""
    process_chunk(current_chunk_size, cnty, temp_chunk, elv_chunk, lat_chunk, co2, tmin_chunk, prec_chunk, cldp_chunk, ksat_chunk, whc_chunk, dz, lon_chunk, output_stack, output_dataset, strx, model_instance, PFTS)

Process a spatial chunk of data by iterating through grid cells using RasterStack.
"""
function process_chunk(
    current_chunk_size, cnty,
    temp_chunk, elv_chunk, lat_chunk, co2, tmin_chunk, 
    prec_chunk, cldp_chunk, ksat_chunk, whc_chunk, dz, 
    lon_chunk, output_stack::RasterStack,
    output_dataset, strx, model_instance::BiomeModel, PFTS::AbstractPFTList
)
    for y in 1:cnty
        println("Serially processing y index $y")

        # Check if the row is already processed using the primary variable
        primary_var = get_primary_variable(model_instance)
        if any(output_stack[primary_var][:, y] .!= -9999.0)
            println("Row $y already processed, skipping.")
            continue
        end

        for x in 1:current_chunk_size
            if temp_chunk[x, y, 1] == -9999.0 || any(whc_chunk[x, y, :] .== -9999.0)
                continue
            end

            process_cell(
                x, y, strx, temp_chunk, elv_chunk, lat_chunk, co2, tmin_chunk, 
                prec_chunk, cldp_chunk, ksat_chunk, whc_chunk,
                dz, lon_chunk, output_stack, model_instance, PFTS
            )
        end

        # Sync to NetCDF every 10 rows
        if y % 10 == 0
            sync_rasterstack_to_netcdf(output_stack, output_dataset, model_instance)
        end
    end
end

"""
    process_cell(x, y, strx, temp_chunk, elv_chunk, lat_chunk, co2, tmin_chunk, prec_chunk, cldp_chunk, ksat_chunk, whc_chunk, dz, lon_chunk, output_stack, model, PFTS)

Process a single grid cell for biome classification using RasterStack.
"""
function process_cell(
    x, y, strx,
    temp_chunk, elv_chunk, lat_chunk, co2::T, tmin_chunk, 
    prec_chunk, cldp_chunk, ksat_chunk, whc_chunk, dz, 
    lon_chunk, output_stack::RasterStack, model::BiomeModel, PFTS::AbstractPFTList
) where {T<:Real}
    # Check if already processed
    primary_var = get_primary_variable(model)
    if output_stack[primary_var][x, y] != -9999.0
        println("Cell ($x_global_index, $y_global_index) already processed, skipping.")
        return
    end

    # Skip if missing data
    if temp_chunk[x, y, 1] == -9999.0 || any(whc_chunk[x, y, :] .== -9999.0)
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
    
    # Write results using model-specific function
    process_cell_output(model, x, y, output, output_stack)
end

"""
    get_primary_variable(model::BiomeModel)

Get the primary variable name for each model type (used for checking if processed).
"""
function get_primary_variable(model::BIOME4Model)
    return :biome
end

function get_primary_variable(model::WissmannModel)
    return :climate_zone
end

function get_primary_variable(model::KoppenModel)
    return :koppen_class
end

function get_primary_variable(model::ThornthwaiteModel)
    return :temperature_zone
end

function get_primary_variable(model::TrollPfaffenModel)
    return :troll_zone
end


"""
    process_cell_output(model, x, y, output, output_stack)

Write model output to the RasterStack based on model type.
"""
function process_cell_output(model::BIOME4Model, x, y, output, output_stack::RasterStack)
    output_stack[:biome][x, y] = output[1]
    output_stack[:wdom][x, y] = output[2]
    output_stack[:npp][x, y, :] = output[3:16]
end

function process_cell_output(model::WissmannModel, x, y, output, output_stack::RasterStack)
    output_stack[:climate_zone][x, y] = output[1]
end

function process_cell_output(model::KoppenModel, x, y, output, output_stack::RasterStack)
    output_stack[:koppen_class][x, y] = output[1]
end

function process_cell_output(model::ThornthwaiteModel, x, y, output, output_stack::RasterStack)
    output_stack[:temperature_zone][x, y] = output[1]
    output_stack[:moisture_zone][x, y] = output[2]
end

function process_cell_output(model::TrollPfaffenModel, x, y, output, output_stack::RasterStack)
    output_stack[:troll_zone][x, y] = output[1]
end

"""
    sync_rasterstack_to_netcdf(output_stack, dataset, model)

Synchronize RasterStack data to NetCDF file.
"""
function sync_rasterstack_to_netcdf(output_stack::RasterStack, dataset, model::BiomeModel)
    schema = get_output_schema(model)
    
    for (var_name, _) in schema
        if haskey(dataset, var_name)
            dataset[var_name][:] = output_stack[Symbol(var_name)][:]
        end
    end
    
    # Force write to disk
    sync(dataset)
end

"""
    get_output_schema(model::BiomeModel)

Define the output variables and their properties for different biome models.
"""
function get_output_schema(model::BIOME4Model)
    return Dict(
        "biome" => (type=Int16, dims=("lon", "lat"), attrs=Dict("description" => "Biome classification")),
        "wdom" => (type=Int16, dims=("lon", "lat"), attrs=Dict("description" => "Dominant woody vegetation")),
        "npp" => (type=Float64, dims=("lon", "lat", "pft"), attrs=Dict("units" => "gC/m^2/month", "description" => "Net primary productivity")),
    )
end

function get_output_schema(model::WissmannModel)
    return Dict(
        "climate_zone" => (type=Int16, dims=("lon", "lat"), attrs=Dict("description" => "Wissmann climate zone classification")),
    )
end

function get_output_schema(model::KoppenModel)
    return Dict(
        "koppen_class" => (type=Int16, dims=("lon", "lat"), attrs=Dict("description" => "Köppen-Geiger climate classification")),
    )
end

function get_output_schema(model::ThornthwaiteModel)
    return Dict(
        "temperature_zone" => (type=Int16, dims=("lon", "lat"), attrs=Dict("description" => "Thornthwaite temperature zone")),
        "moisture_zone" => (type=Int16, dims=("lon", "lat"), attrs=Dict("description" => "Thornthwaite moisture zone")),
    )
end

function get_output_schema(model::TrollPfaffenModel)
    return Dict(
        "troll_zone" => (type=Int16, dims=("lon", "lat"), attrs=Dict("description" => "Troll-Pfaffen climate zone")),
    )
end

"""
    get_required_dimensions(model::BiomeModel, cntx, cnty)

Get the dimensions required for each model type.
"""
function get_required_dimensions(model::BIOME4Model, cntx, cnty)
    return Dict(
        "lon" => cntx,
        "lat" => cnty,
        "pft" => 14
    )
end

function get_required_dimensions(model::Union{WissmannModel, KoppenModel, ThornthwaiteModel, TrollPfaffenModel}, cntx, cnty)
    return Dict(
        "lon" => cntx,
        "lat" => cnty
    )
end

"""
    create_output_variables(dataset, model, lon, lat, cntx, cnty)

Create output variables in NetCDF dataset based on the model type.
"""
function create_output_variables(dataset, model::BiomeModel, lon, lat, cntx, cnty)
    # Define dimensions
    dims = get_required_dimensions(model, cntx, cnty)
    for (name, size) in dims
        defDim(dataset, name, size)
    end
    
    # Define coordinate variables
    lon_var = defVar(dataset, "lon", Float64, ("lon",), attrib=Dict("units" => "degrees_east"))
    lat_var = defVar(dataset, "lat", Float64, ("lat",), attrib=Dict("units" => "degrees_north"))
    
    # Fill coordinate variables
    lon_var[:] = lon
    lat_var[:] = lat
    
    # Define model-specific variables
    schema = get_output_schema(model)
    
    for (var_name, var_info) in schema
        var = defVar(dataset, var_name, var_info.type, var_info.dims, attrib=var_info.attrs)
        
        # Initialize with fill values
        if var_info.dims == ("lon", "lat")
            var[:, :] = fill(-9999, cntx, cnty)
        elseif var_info.dims == ("lon", "lat", "pft")
            var[:, :, :] = fill(-9999, cntx, cnty, 14)
        end
    end
    
    # Add global attributes
    dataset.attrib["title"] = "$(typeof(model)) output"
    dataset.attrib["institution"] = "WSL"
    dataset.attrib["source"] = "BIOME Model Suite"
    dataset.attrib["model"] = string(typeof(model))
end

"""
    parse_coordinates(coordstring)

Parse coordinate string into numeric bounds.
"""
function parse_coordinates(coordstring::String)
    coords = split(coordstring, "/")
    if length(coords) != 4
        error("Coordinate string must have format: lon_min/lon_max/lat_min/lat_max")
    end
    return parse.(Float64, coords)
end

"""
    get_array_indices(lon_full, lat_full, lon_min, lon_max, lat_min, lat_max)

Calculate array indices for a geographic bounding box.
"""
function get_array_indices(lon_full, lat_full, lon_min, lon_max, lat_min, lat_max)
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
"""
function uniform_fill_value(data::Array{T,N}; fill_value=-9999.0) where {T,N}
    fill_value = convert(T, fill_value)
    data .= coalesce.(data, fill_value)
    return data
end

"""
    parse_command_line()

Parse command-line arguments for the BIOME model driver.
"""
function parse_command_line()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--coordstring"
        help = "Coordinate string or 'alldata'"
        arg_type = String
        default = "alldata"

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