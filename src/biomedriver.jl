module BiomeDriver

using ..Biome: BiomeModel, BaseModel, BIOME4Model, BIOMEDominanceModel, WissmannModel, KoppenModel, ThornthwaiteModel, TrollPaffenModel,
        BIOME4, ClimateModel, MechanisticModel, GrowthWorkspace,
        AbstractPFTList, AbstractPFTCharacteristics, AbstractPFT,
        AbstractBiomeCharacteristics, AbstractBiome, PFTClassification,
        P0, G, CP, T0, M, R0,
        runmodel, change_type, assign_biome as base_assign_biome
using ..Biome.BIOME4: assign_biome as biome4_assign_biome

# Standard library
using Statistics
using Missings
using Base.Threads

# Third-party
using ArgParse
using NCDatasets
import ArchGDAL
using Rasters
using DataStructures: OrderedDict
using DimensionalData

export ModelSetup, execute

mutable struct ModelSetup{M<:BiomeModel, T<:Real}
    model::M
    lon::AbstractVector{<:Real}
    lat::AbstractVector{<:Real}
    co2::T
    rasters::NamedTuple
    pftlist::Union{AbstractPFTList,Nothing}
    biome_assignment::Union{Function, Nothing}
    int_type::Type{<:Integer}
    float_type::Type{<:AbstractFloat}
end

function ModelSetup(Model::BiomeModel;
                    co2::Real = 378.0,
                    pftlist::Union{AbstractPFTList,Nothing} = nothing,
                    biome_assignment::Union{Function,Nothing} = nothing,
                    fill_value::Real = -9999.0,
                    kwargs...)

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

    # Use the element type of the first raster as the canonical type,
    # but drop Missing so float_type is the non-missing element type.
    first_raster = first(values(raster_dict))
    float_type = Missings.nonmissingtype(eltype(first_raster))

    # Ensure raster element types (ignoring Missing) match the target type and detect missing values.
    type_mismatch = any(r -> Missings.nonmissingtype(eltype(r)) != float_type, values(raster_dict))

    if type_mismatch
        # Convert Rasters
        @warn "Raster element types do not match $(float_type). Converting all rasters to $float_type and replacing missing with $fill_value."
        for (k, r) in pairs(raster_dict)
            data = Array(r)
            fillv = convert(float_type, fill_value)
            dataf = convert.(float_type, coalesce.(data, fillv))
            raster_dict[k] = Raster(dataf, dims=dims(r), name=k)
        end

        # Convert PFTList
        @warn "Converting PFT list to match raster data types."
        pftlist = change_type(pftlist, float_type)
    end

    # Convert CO2 to the raster non-missing element type
    co2 = convert(float_type, co2)

    # Convert Dict to NamedTuple (keeps keys as symbols)
    rasters = (; (Symbol(k) => v for (k, v) in raster_dict)...)

    # Extract longitude and latitude from the temp raster (which is mandatory for all models)
    # so ok to refer to
    lon = collect(lookup(rasters[:temp], X))
    lat = collect(lookup(rasters[:temp], Y))

    if biome_assignment === nothing
        if Model isa BIOME4Model || Model isa BIOMEDominanceModel
            biome_assignment = biome4_assign_biome
        else
            biome_assignment = base_assign_biome
        end
    end

    return ModelSetup(Model, lon, lat, co2, rasters, pftlist, biome_assignment, Int64, float_type)
end

function execute(setup::ModelSetup; bounds::Union{Tuple{X,Y}, Nothing} = nothing, outfile::Union{String, Nothing}=nothing)
    M = setup.model
    pftlist = setup.pftlist
    env_raster = setup.rasters
    BiomeDriver._simulate!(
        M,
        setup.co2,
        pftlist,
        env_raster;
        bounds=bounds,
        outfile=outfile,
        biome_assignment=setup.biome_assignment
    )
end

function _simulate!(
        model::BiomeModel,
        co2::T,
        pftlist,
        env_raster::NamedTuple;
        bounds::Union{Tuple{X,Y}, Nothing} = nothing,
        outfile::Union{String, Nothing} = nothing,
        biome_assignment::Union{Function, Nothing} = nothing
    ) where {T<:Real}

    if biome_assignment === nothing
        if model isa BIOME4Model || model isa BIOMEDominanceModel
            biome_assignment = biome4_assign_biome
        else
            biome_assignment = base_assign_biome
        end
    end

    if pftlist === nothing
        @warn "No pftlist provided, using default PFT classification."
        pftlist = get_pft_list(model) # FIXME we should specify the type here
    end

    numofpfts = (pftlist !== nothing) ? length(pftlist.pft_list) : 0
    dz = T[5, 10, 15, 30, 40, 100]

    # Cut the input rasters to bounds
    env_raster = isnothing(bounds) ? env_raster :
    (ref = env_raster[:temp][bounds...];
     map(r -> crop(r; to=ref, dims=(X, Y)), env_raster))

    # reference grid (after subsetting)
    ref = env_raster[:temp]

    lon = collect(lookup(ref, X))
    lat = collect(lookup(ref, Y))
    cntx = length(lon)
    cnty = length(lat)

    println("Processing grid: cntx=$cntx, cnty=$cnty")
    println("Bounds: X $(extrema(lon)), Y $(extrema(lat))")

    x_dim = dims(ref, X)
    y_dim = dims(ref, Y)

    if isnothing(outfile)
        # We don't make a file
        output_stack = create_output_rasterstack(model, x_dim, y_dim, cntx, cnty, numofpfts)

    else
        if isfile(outfile)
            println("File $outfile already exists. Resuming from last processed row.")
            output_dataset = NCDataset(outfile, "a")
            output_stack = load_existing_rasterstack(output_dataset, model, x_dim, y_dim, numofpfts)
        else
            output_dataset = NCDataset(outfile, "c")
            println("Creating new output file: $outfile")
            create_output_variables(output_dataset, model, lon, lat, cntx, cnty, numofpfts)
            output_stack = create_output_rasterstack(model, x_dim, y_dim, cntx, cnty, numofpfts)
        end
    end

    # Create a lock for thread-safe file I/O
    file_lock = ReentrantLock()

    # Loop over all grid cells
    Threads.@threads for y in 1:cnty
        println("Processing y index $y")
        lat_val = lat[y]

        # Check if the row is already processed using the primary variable
        primary_var = get_primary_variable(model)
        if all(output_stack[primary_var][:, y] .!= -9999.0)
            println("Row $y already processed, skipping.")
            continue
        end

        env_chunks = Dict{Symbol, Any}()

        for x in 1:cntx
            lon_val = lon[x]

            empty!(env_chunks)

            for (var, raster) in pairs(env_raster)
                if ndims(raster) == 2
                    # 2D raster: store scalar directly
                    env_chunks[var] = raster[x, y]
                else
                    # 3D raster: extract the full vector at (x,y,:)
                    chunk = Array(raster[x, y, :])
                    env_chunks[var] = uniform_fill_value(chunk)
                end
            end

            # Skip cell if all environmental variables are missing
            skip_cell = false
            for val in values(env_chunks)
                if val isa AbstractArray
                    if all(v -> v == -9999.0, val)
                        skip_cell = true
                        break
                    end
                elseif val == -9999.0
                    skip_cell = true
                    break
                end
            end

            if skip_cell
                continue
            end

            process_cell(
                x,
                y,
                lat_val,
                lon_val,
                co2,
                env_chunks,
                dz,
                output_stack,
                model,
                pftlist,
                biome_assignment
            )
        end

        # Sync to NetCDF every 10 rows with thread-safe locking
        if isnothing(outfile)
            continue
        else
            if y % 10 == 0
                lock(file_lock) do
                    sync_rasterstack_to_netcdf(output_stack, output_dataset, model)
                end
            end
        end
    end

    # Final sync before closing (lock ensures thread-safe access)
    if isnothing(outfile)
        return output_stack
    else
        lock(file_lock) do
            sync_rasterstack_to_netcdf(output_stack, output_dataset, model)
            close(output_dataset)
        end
    end
end

"""
    create_output_rasterstack(model, x_dim, y_dim, cntx, cnty, numofpfts)

Create a RasterStack for output variables based on the model type, preserving
the X/Y dimension objects from the reference Raster.
"""
function create_output_rasterstack(model::BiomeModel, x_dim, y_dim, cntx, cnty, numofpfts)
    schema = get_output_schema(model)

    rasters = Raster[]
    for (var_name, var_info) in schema
        if var_info.dims == ("lon", "lat")
            raster = Raster(
                fill(-9999.0, cntx, cnty),
                dims=(x_dim, y_dim),
                name=Symbol(var_name)
            )
        elseif var_info.dims == ("lon", "lat", "pft")
            pft_dim = Dim{:pft}(1:numofpfts+1)
            raster = Raster(
                fill(-9999.0, cntx, cnty, numofpfts+1),
                dims=(x_dim, y_dim, pft_dim),
                name=Symbol(var_name)
            )
        end
        push!(rasters, raster)
    end

    return RasterStack(Tuple(rasters))
end

"""
    load_existing_rasterstack(dataset, model, x_dim, y_dim, numofpfts)

Load existing data from NetCDF into a RasterStack for resume functionality,
reusing the reference X/Y dimension objects.
"""
function load_existing_rasterstack(dataset, model::BiomeModel, x_dim, y_dim, numofpfts)
    schema = get_output_schema(model)
    rasters = Raster[]

    for (var_name, var_info) in schema
        if haskey(dataset, var_name)
            if var_info.dims == ("lon", "lat")
                data = Array(dataset[var_name][:, :])
                raster = Raster(data, dims=(x_dim, y_dim), name=Symbol(var_name))
            elseif var_info.dims == ("lon", "lat", "pft")
                pft_dim = Dim{:pft}(1:numofpfts+1)
                data = Array(dataset[var_name][:, :, :])
                raster = Raster(data, dims=(x_dim, y_dim, pft_dim), name=Symbol(var_name))
            end
            push!(rasters, raster)
        end
    end

    return RasterStack(Tuple(rasters))
end

"""
    process_cell(...)

Process a single grid cell for biome classification using RasterStack.
"""
function process_cell(
    x,
    y,
    lat_val,
    lon_val,
    co2::T,
    env_chunks,
    dz,
    output_stack::RasterStack,
    model::BiomeModel,
    pftlist::AbstractPFTList,
    biome_assignment::Function
) where {T<:Real}

    primary_var = get_primary_variable(model)
    if output_stack[primary_var][x, y] != -9999.0
        println("Cell ($x, $y) already processed, skipping.")
        return
    end

    # Calculate atmospheric pressure from elevation (NOTE: your original formula had no elevation input;
    # left unchanged structurally, but verify this is what you intend.)
    p = P0 * (1.0 - (G) / (CP * T0))^(CP * M / R0)

    input_dict = Dict{Symbol, Any}()
    input_dict[:lat] = lat_val
    input_dict[:lon] = lon_val
    input_dict[:co2] = co2
    input_dict[:p] = p
    input_dict[:dz] = dz

    merge!(input_dict, env_chunks)

    input_variables = (; input_dict...)

    # Run the model 
    output = runmodel(model, input_variables; pftlist = pftlist, biome_assignment = biome_assignment)

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

function get_pft_list(m::Union{BaseModel})
    return PFTClassification([
        NeedleleafEvergreenPFT(),
        BroadleafEvergreenPFT(),
        NeedleleafDeciduousPFT(),
        BroadleafDeciduousPFT(),
        C3GrassPFT(),
        C4GrassPFT()
    ])
end

function get_pft_list(::Union{WissmannModel, KoppenModel, ThornthwaiteModel, TrollPaffenModel})
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

function get_primary_variable(model::TrollPaffenModel)
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

function process_cell_output(model::TrollPaffenModel, x, y, output, output_stack::RasterStack; numofpfts)
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
        "biome" => (type=Int16, dims=("lon", "lat"), attrs=Dict("description" => "Biome classification")),
        "optpft" => (type=Int16, dims=("lon", "lat"), attrs=Dict("description" => "Dominant PFT")),
        "npp" => (type=Float64, dims=("lon", "lat", "pft"), attrs=Dict("units" => "m²/m²", "description" => "Annual Net primary productivity")),
    )
end

function get_output_schema(model::WissmannModel)
    return Dict(
        "climate_zone" => (type=Int16, dims=("lon", "lat"), attrs=Dict("description" => "Wissmann climate zone classification")),
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

function get_output_schema(model::TrollPaffenModel; int_type::Type{<:Integer} = Int)
    return Dict(
    "troll_zone" => (type = int_type, dims = ("lon", "lat"), attrs = Dict("description" => "Troll-Paffen climate zone"))
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

function get_required_dimensions(model::Union{WissmannModel, KoppenModel, ThornthwaiteModel, TrollPaffenModel}, cntx, cnty; kwargs...)
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
    dims = get_required_dimensions(model, cntx, cnty; numofpfts=numofpfts)
    for (name, size) in dims
        defDim(dataset, name, size)
    end

    # Define coordinate variables
    lon_var = defVar(dataset, "lon", T, ("lon",), attrib=Dict("units" => "degrees_east"))
    lat_var = defVar(dataset, "lat", T, ("lat",), attrib=Dict("units" => "degrees_north"))

    # Fill coordinate variables (already plain vectors from Rasters.lookup)
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
        "--co2"
        help = "CO2 concentration"
        arg_type = Real
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
