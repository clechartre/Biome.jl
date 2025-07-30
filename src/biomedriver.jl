module BiomeDriver

using ..Biome: BiomeModel, BaseModel, BIOME4Model, BIOMEDominanceModel, WissmannModel, KoppenModel, ThornthwaiteModel, TrollPfaffenModel,
        BIOME4, ClimateModel, MechanisticModel,
        AbstractPFTList, AbstractPFTCharacteristics, AbstractPFT,
        AbstractBiomeCharacteristics, AbstractBiome, PFTClassification, P0, G, CP, T0, M, R0, run, assign_biome

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

export ModelSetup, run!

mutable struct ModelSetupObj{M<:BiomeModel}
    model::M
    lon::Vector{Float64}
    lat::Vector{Float64}
    co2::Float64
    rasters::Dict{Symbol,Raster}
    pftlist::Union{AbstractPFTList,Nothing}
    biome_assignment::Function
end

function ModelSetup(::Type{M}; co2::Float64 = 378.0,
                    pftlist = nothing,
                    biome_assignment::Function = assign_biome,
                    kwargs...) where {M<:BiomeModel}

    # Separate out raster arguments from others
    rasters = Dict{Symbol,Raster}()
    for (key, val) in kwargs
        if val isa Raster
            rasters[key] = val
        end
    end

    # Ensure required keys exist
    @assert :temp in keys(rasters) "A `temp` raster must be provided."
    @assert :prec in keys(rasters) "A `prec` raster must be provided."

    # Extract longitude and latitude from the temp raster
    lon = collect(dims(rasters[:temp], X))
    lat = collect(dims(rasters[:temp], Y))

    return ModelSetupObj{M}(M(), lon, lat, co2, rasters, pftlist, biome_assignment)
end

function run!(setup::ModelSetupObj; coordstring::String="alldata", outfile::String="out.nc")
  M = setup.model
  PFTs = setup.pftlist
  temp = setup.rasters[:temp]
  prec = setup.rasters[:prec]
  sun  = get(setup.rasters, :sun,  nothing)
  ksat = get(setup.rasters, :ksat, nothing)
  whc  = get(setup.rasters, :whc,  nothing)
  BiomeDriver._execute!(
    M, setup.co2, setup.lon, setup.lat, PFTs,
    temp, prec, sun, ksat, whc;
    coordstring=coordstring,
    outfile=outfile,
    biome_assignment=setup.biome_assignment
  )
end

# internal: almost exactly your old `main()`
function _execute!(
        model::BiomeModel,
        co2::T, 
        lon, 
        lat, 
        pftlist,
        temp_raster::Raster, 
        prec_raster::Raster,
        clt_raster::Union{Raster,Nothing}, 
        ksat_raster::Union{Raster,Nothing},
        whc_raster::Union{Raster,Nothing};
        coordstring::String, 
        outfile::String,
        biome_assignment::Function = Biome.assign_biome
        ) where {T<:Real}

    if  pftlist === nothing
        @warn "No pftlist provided, using default PFT classification."
        pftlist = get_pft_list(model)
    end


    if pftlist !== nothing
        numofpfts = length(pftlist.pft_list)
    else
        numofpfts = 0
    end

    # Open the first dataset to get dimensions, then close
    lon_full = lon
    lat_full = lat
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

    if isfile(outfile)
        println("File $outfile already exists. Resuming from last processed row.")
        output_dataset = NCDataset(outfile, "a")
        output_stack = load_existing_rasterstack(output_dataset, model, lon, lat, numofpfts)
    else
        output_dataset = NCDataset(outfile, "c")
        println("Creating new output file: $outfile")
        create_output_variables(output_dataset, model, lon, lat, cntx, cnty, numofpfts)
        output_stack = create_output_rasterstack(model, lon, lat, cntx, cnty, numofpfts)
    end

    # Set up chunking variables
    chunk_size = 1000 # We're only processing 1000 rows at a time

    # Read latitude (only once since it's the same for all x chunks)
    lat_chunk = collect(dims(temp_raster, Y))[stry:endy]

    for x_chunk_start in strx:chunk_size:endx
        x_chunk_end = min(x_chunk_start + chunk_size - 1, endx)
        current_chunk_size = x_chunk_end - x_chunk_start + 1

        println("Processing x indices from $x_chunk_start to $x_chunk_end")

        # Read longitude for this chunk
        lon_chunk = lon_full[x_chunk_start:x_chunk_end]

        # Read temperature data
        temp_chunk = temp_raster[x_chunk_start:x_chunk_end, stry:endy, :]
        temp_chunk = Array(temp_chunk) |> uniform_fill_value

        # Read precipitation data
        prec_chunk = prec_raster[x_chunk_start:x_chunk_end, stry:endy, :]
        prec_chunk = Array(prec_chunk) |> uniform_fill_value

        # Optional Data 
        # Read cloud cover data
        if clt_raster !== nothing
            cldp_chunk = Array(clt_raster[x_chunk_start:x_chunk_end, stry:endy, :]) |> uniform_fill_value
        else
            cldp_chunk = fill(0.0, current_chunk_size, cnty, size(temp_chunk,3))
        end
        
        # Read soil data
        if ksat_raster !== nothing
            ksat_chunk = Array(ksat_raster[x_chunk_start:x_chunk_end, stry:endy, :]) |> uniform_fill_value
        else
            ksat_chunk = fill(0.0, current_chunk_size, cnty, size(temp_chunk,3))
        end
        
        if whc_raster !== nothing
            whc_chunk = Array(whc_raster[x_chunk_start:x_chunk_end, stry:endy, :]) |> uniform_fill_value
        else
            whc_chunk = fill(0.0, current_chunk_size, cnty, size(temp_chunk,3))
        end

        println("max temp: ", maximum(temp_chunk), ", min temp: ", minimum(temp_chunk))
        println("max prec: ", maximum(prec_chunk), ", min prec: ", minimum(prec_chunk))
        println("max cldp: ", maximum(cldp_chunk), ", min cldp: ", minimum(cldp_chunk))
        println("max ksat: ", maximum(ksat_chunk), ", min ksat: ", minimum(ksat_chunk))
        println("max whc: ", maximum(whc_chunk), ", min whc: ", minimum(whc_chunk))

        # Process the data in this chunk
        process_chunk(
            current_chunk_size,
            cnty,
            temp_chunk,
            lat_chunk,
            co2,
            prec_chunk,
            cldp_chunk,
            ksat_chunk,
            whc_chunk,
            dz, 
            lon_chunk,
            output_stack,
            output_dataset,
            strx,
            model,
            pftlist,
            biome_assignment
        )
    end

    # Final sync before closing
    sync_rasterstack_to_netcdf(output_stack, output_dataset, model)
    close(output_dataset)
end

"""
    create_output_rasterstack(model::BiomeModel, lon, lat, cntx, cnty)

Create a RasterStack for output variables based on the model type.
"""
function create_output_rasterstack(model::BiomeModel, lon, lat, cntx, cnty, numofpfts)
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
            pft_dim = Dim{:pft}(1:numofpfts+1)
            raster = Raster(
                fill(-9999.0, cntx, cnty, numofpfts+1),
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
function load_existing_rasterstack(dataset, model::BiomeModel, lon, lat, numofpfts)
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
                pft_dim = Dim{:pft}(1:numofpfts+1)
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
    process_chunk(current_chunk_size, cnty, temp_chunk,
lat_chunk, co2, prec_chunk, cldp_chunk, ksat_chunk,
 whc_chunk, dz, lon_chunk, output_stack, output_dataset, strx,
 model, PFTS)

Process a spatial chunk of data by iterating through grid cells using RasterStack.
"""
function process_chunk(
    current_chunk_size, cnty,
    temp_chunk, lat_chunk, co2, 
    prec_chunk, cldp_chunk, ksat_chunk, whc_chunk, dz, 
    lon_chunk, output_stack::RasterStack,
    output_dataset, strx, model::BiomeModel, pftlist::AbstractPFTList,
    biome_assignment::Function
    )
    for y in 1:cnty
        println("Serially processing y index $y")

        # Check if the row is already processed using the primary variable
        primary_var = get_primary_variable(model)
        if any(output_stack[primary_var][:, y] .!= -9999.0)
            println("Row $y already processed, skipping.")
            continue
        end

        for x in 1:current_chunk_size
            if temp_chunk[x, y, 1] == -9999.0 || any(whc_chunk[x, y, :] .== -9999.0)
                continue
            end

            process_cell(
                x, y, strx, temp_chunk, lat_chunk, co2,
                prec_chunk, cldp_chunk, ksat_chunk, whc_chunk,
                dz, lon_chunk, output_stack, model, pftlist, biome_assignment
            )
        end

        # Sync to NetCDF every 10 rows
        if y % 10 == 0
            sync_rasterstack_to_netcdf(output_stack, output_dataset, model)
        end
    end
end

"""
    process_cell(x, y, strx, temp_chunk, lat_chunk, co2, prec_chunk, cldp_chunk, ksat_chunk, whc_chunk, dz, lon_chunk, output_stack, model, PFTS)

Process a single grid cell for biome classification using RasterStack.
"""
function process_cell(
    x, y, strx,
    temp_chunk, lat_chunk, co2::T,
    prec_chunk, cldp_chunk, ksat_chunk, whc_chunk, dz, 
    lon_chunk, output_stack::RasterStack, model::BiomeModel, pftlist::AbstractPFTList,
    biome_assignment::Function
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

    # Calculate atmospheric pressure from elevation
    p = P0 * (1.0 - (G) / (CP * T0))^(CP * M / R0)

    input = zeros(T, 50)
    # input - (lat-lat, co2^cpde)

    input[1] = lat_chunk[y]
    input[2] = co2
    input[3] = p
    input[5:16] .= temp_chunk[x, y, :]
    input[17:28] .= prec_chunk[x, y, :]
    input[29:40] .= cldp_chunk[x, y, :]
    input[41] = sum(ksat_chunk[x, y, 1:3] .* dz[1:3]) / sum(dz[1:3])
    input[42] = sum(ksat_chunk[x, y, 4:6] .* dz[4:6]) / sum(dz[4:6])
    input[43] = sum(whc_chunk[x, y, 1:3] .* dz[1:3])
    input[44] = sum(whc_chunk[x, y, 4:6] .* dz[4:6])
    input[49] = lon_chunk[x]

    # Run the model 
    output = run(model, input; pftlist = pftlist, biome_assignment = biome_assignment)

    numofpfts = length(pftlist.pft_list)

    # Write results using model-specific function
    process_cell_output(model, x, y, output, output_stack; numofpfts = numofpfts)
end

"""
  get_pft_list(model::Union{BaseModel, BIOME4Model})

Return the AbstractPFTList appropriate for `model`.
"""
function get_pft_list(m::Union{BIOME4Model, BIOMEDominanceModel})
    return BIOME4.PFTClassification()
end

function get_pft_list(::Union{WissmannModel, KoppenModel, ThornthwaiteModel, TrollPfaffenModel})
    return PFTClassification()
end

"""
get_primary_variable(model::BiomeModel)

Get the primary variable name for each model type (used for checking if processed).
"""
function get_primary_variable(model::Union{BIOME4Model, BIOMEDominanceModel, BaseModel})
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
function process_cell_output(model::Union{BIOME4Model, BIOMEDominanceModel, BaseModel}, x, y, output, output_stack::RasterStack; numofpfts)
    output_stack[:biome][x, y] = output[1]
    output_stack[:wdom][x, y] = output[2]
    output_stack[:npp][x, y, :] = output[3:3+numofpfts]
end

function process_cell_output(model::WissmannModel, x, y, output, output_stack::RasterStack; numofpfts)
    output_stack[:climate_zone][x, y] = output[1]
end

function process_cell_output(model::KoppenModel, x, y, output, output_stack::RasterStack; numofpfts)
    output_stack[:koppen_class][x, y] = output[1]
end

function process_cell_output(model::ThornthwaiteModel, x, y, output, output_stack::RasterStack; numofpfts)
    output_stack[:temperature_zone][x, y] = output[1]
    output_stack[:moisture_zone][x, y] = output[2]
end

function process_cell_output(model::TrollPfaffenModel, x, y, output, output_stack::RasterStack; numofpfts)
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
function get_output_schema(model::Union{BIOME4Model, BIOMEDominanceModel, BaseModel})
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
function get_required_dimensions(model::Union{BIOME4Model, BIOMEDominanceModel, BaseModel}, cntx, cnty; numofpfts)
    return Dict(
        "lon" => cntx,
        "lat" => cnty,
        "pft" => numofpfts+1
    )
end

function get_required_dimensions(model::Union{WissmannModel, KoppenModel, ThornthwaiteModel, TrollPfaffenModel}, cntx, cnty; kwargs...)
    return Dict(
        "lon" => cntx,
        "lat" => cnty
    )
end

"""
    create_output_variables(dataset, model, lon, lat, cntx, cnty)

Create output variables in NetCDF dataset based on the model type.
"""
function create_output_variables(dataset, model::BiomeModel, lon, lat, cntx, cnty, numofpfts)
    # Define dimensions
    dims = get_required_dimensions(model, cntx, cnty; numofpfts = numofpfts)
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
            var[:, :, :] = fill(-9999, cntx, cnty, numofpfts+1)
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

    execute!(
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

end # module