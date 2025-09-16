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

mutable struct ModelSetup{M<:BiomeModel, T<:Real}
    model::M
    lon::AbstractVector{<:Real}
    lat::AbstractVector{<:Real}
    co2::Float64
    rasters::NamedTuple
    pftlist::Union{AbstractPFTList,Nothing}
    biome_assignment::Function
    int_type::Type{<:Integer}
    float_type::Type{<:AbstractFloat}
end

function ModelSetup(Model::BiomeModel;
                    co2::T = 378.0,
                    pftlist::Union{AbstractPFTList,Nothing} = nothing,
                    biome_assignment::Function = assign_biome,
                    int_type::Type{<:Integer} = Int,
                    float_type::Type{<:AbstractFloat} = Float64,
                    kwargs...) where {T<:Real}

    # Separate out raster arguments from others
    raster_dict = Dict{Symbol,Raster}()
    for (key, val) in kwargs
        if val isa Raster
            raster_dict[key] = val
        end
    end

    # Ensure required keys exist
    @assert :temp in keys(raster_dict) "A `temp` raster must be provided."
    @assert :prec in keys(raster_dict) "A `prec` raster must be provided."

    # Convert Dict to NamedTuple
    rasters = NamedTuple((Symbol(key),value) for (key,value) in raster_dict)

    # Extract longitude and latitude from the temp raster
    lon = collect(dims(rasters[:temp], X))
    lat = collect(dims(rasters[:temp], Y))

    return ModelSetup(Model, lon, lat, co2, rasters, pftlist, biome_assignment, int_type, float_type)
end

function run!(setup::ModelSetup; coordstring::String="alldata", outfile::String="out.nc")
    M = setup.model
    pftlist = setup.pftlist
    env_raster = setup.rasters
    BiomeDriver._execute!(
    M, setup.co2, setup.lon, setup.lat, pftlist, env_raster;
    coordstring=coordstring,
    outfile=outfile,
    biome_assignment=setup.biome_assignment
  )
end


function _execute!(
        model::BiomeModel,
        co2::T, 
        lon, 
        lat, 
        pftlist,
        env_raster::NamedTuple;
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
        coords = parse_coordinates(coordstring, T)
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
    lat_chunk = collect(dims(env_raster[1], Y))[stry:endy]

    for x_chunk_start in strx:chunk_size:endx
        x_chunk_end = min(x_chunk_start + chunk_size - 1, endx)
        current_chunk_size = x_chunk_end - x_chunk_start + 1
        lon_chunk = lon_full[x_chunk_start:x_chunk_end]

        println("Processing x indices from $x_chunk_start to $x_chunk_end")

        # Prepare environmental chunks
        env_chunks = Dict{Symbol,Array}()

        for (entry, raster) in enumerate(env_raster)
            var = keys(env_raster)[entry]
            chunk = raster[x_chunk_start:x_chunk_end, stry:endy, :]
            env_chunks[var] = uniform_fill_value(Array(chunk))
        end

        # Debug: print min/max of each var
        for (var, chunk) in env_chunks
            println("max $var: ", maximum(chunk), ", min $var: ", minimum(chunk))
        end

        for y in 1:cnty
            println("Serially processing y index $y")
    
            # Check if the row is already processed using the primary variable
            primary_var = get_primary_variable(model)
            if any(output_stack[primary_var][:, y] .!= -9999.0)
                println("Row $y already processed, skipping.")
                continue
            end
    
            for x in 1:current_chunk_size
                if any(chunk -> all(v -> v == -9999.0, chunk[x, y, :]), values(env_chunks))
                    continue
                end
    
                process_cell(
                    x, 
                    y, 
                    strx, 
                    lat_chunk, 
                    co2,
                    env_chunks,
                    dz, lon_chunk,
                    output_stack, 
                    model, 
                    pftlist, 
                    biome_assignment
                )
            end
    
            # Sync to NetCDF every 10 rows
            if y % 10 == 0
                sync_rasterstack_to_netcdf(output_stack, output_dataset, model)
            end
        end

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
    process_cell(x, y, strx, temp_chunk, lat_chunk, co2, prec_chunk, cldp_chunk, ksat_chunk, whc_chunk, dz, lon_chunk, output_stack, model, PFTS)

Process a single grid cell for biome classification using RasterStack.
"""
function process_cell(
    x, 
    y, 
    strx,
    lat_chunk,
    co2::T,
    env_chunks, 
    dz, 
    lon_chunk, 
    output_stack::RasterStack, 
    model::BiomeModel, 
    pftlist::AbstractPFTList,
    biome_assignment::Function
    ) where {T<:Real}
    # Check if already processed
    primary_var = get_primary_variable(model)
    if output_stack[primary_var][x, y] != -9999.0
        println("Cell ($x_global_index, $y_global_index) already processed, skipping.")
        return
    end

    # Calculate atmospheric pressure from elevation
    p = P0 * (1.0 - (G) / (CP * T0))^(CP * M / R0)

    input = zeros(T, 50)
    # input - (lat-lat, co2^cpde)

    input_variables = merge(
        (; lat = lat_chunk[y], co2 = co2, p = p, dz = dz, lon = lon_chunk[x]),
        (; (k => env_chunks[k][x, y, :] for k in keys(env_chunks))...)
    )

    # Run the model 
    output = run(model, input_variables; pftlist = pftlist, biome_assignment = biome_assignment)

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
function process_cell_output(model::Union{BIOME4Model, BIOMEDominanceModel, BaseModel}, x, y, output::NamedTuple, output_stack::RasterStack; numofpfts)
    output_stack[:biome][x, y] = output.biome
    output_stack[:optpft][x, y] = output.optpft
    output_stack[:npp][x, y, :] = output.npp
end

function process_cell_output(model::WissmannModel, x, y, output, output_stack::RasterStack; numofpfts)
    output_stack[:climate_zone][x, y] = output.climate_zone
end

function process_cell_output(model::KoppenModel, x, y, output, output_stack::RasterStack; numofpfts)
    output_stack[:koppen_class][x, y] = output.koppen_class
end

function process_cell_output(model::ThornthwaiteModel, x, y, output, output_stack::RasterStack; numofpfts)
    output_stack[:temperature_zone][x, y] = output.temperature_zone
    output_stack[:moisture_zone][x, y] = output.moisture_zone
end

function process_cell_output(model::TrollPfaffenModel, x, y, output, output_stack::RasterStack; numofpfts)
    output_stack[:troll_zone][x, y] = output.troll_zone
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
function get_output_schema(model::Union{BIOME4Model, BIOMEDominanceModel, BaseModel}; 
                            int_type::Type{<:Integer} = Int, 
                            float_type::Type{<:AbstractFloat} = Float64)
    return Dict(
        "biome"  => (type = int_type, dims = ("lon", "lat"), attrs = Dict("description" => "Biome classification")),
        "optpft" => (type = int_type, dims = ("lon", "lat"), attrs = Dict("description" => "Dominant PFT")),
        "npp"    => (type = float_type, dims = ("lon", "lat", "pft"), attrs = Dict("units" => "gC/m^2/month", "description" => "Net primary productivity"))
    )
end

function get_output_schema(model::KoppenModel; int_type::Type{<:Integer} = Int)
    return Dict(
    "koppen_class" => (type = int_type, dims = ("lon", "lat"), attrs = Dict("description" => "Köppen-Geiger climate classification"))
    )
end

function get_output_schema(model::ThornthwaiteModel; int_type::Type{<:Integer} = Int)
    return Dict(
    "temperature_zone" => (type = int_type, dims = ("lon", "lat"), attrs = Dict("description" => "Thornthwaite temperature zone")),
    "moisture_zone"    => (type = int_type, dims = ("lon", "lat"), attrs = Dict("description" => "Thornthwaite moisture zone"))
    )
end

function get_output_schema(model::TrollPfaffenModel; int_type::Type{<:Integer} = Int)
    return Dict(
    "troll_zone" => (type = int_type, dims = ("lon", "lat"), attrs = Dict("description" => "Troll-Pfaffen climate zone"))
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
function create_output_variables(dataset, model::BiomeModel, lon::AbstractVector{T}, lat::AbstractVector{T}, cntx, cnty, numofpfts::U) where {T<:Real, U<:Int}
    # Define dimensions
    dims = get_required_dimensions(model, cntx, cnty; numofpfts = numofpfts)
    for (name, size) in dims
        defDim(dataset, name, size)
    end

    # Define coordinate variables
    lon_var = defVar(dataset, "lon", T, ("lon",), attrib=Dict("units" => "degrees_east"))
    lat_var = defVar(dataset, "lat", T, ("lat",), attrib=Dict("units" => "degrees_north"))

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
    parse_coordinates(coordstring, ::Type{T}) where T<:Real

Parse a coordinate string into numeric bounds using the specified type.
"""
function parse_coordinates(coordstring::String, ::Type{T}) where {T<:Real}
    coords = split(coordstring, "/")
    if length(coords) != 4
        error("Coordinate string must have format: lon_min/lon_max/lat_min/lat_max")
    end
    return parse.(T, coords)
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
    data .= Array{T}(coalesce.(data, fill_value))
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