module Biome4Driver

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
using JSON3
using Plots
using Rasters
gr()

# First-party
include("../pfts.jl")
export AbstractPFTList, AbstractPFTCharacteristics, AbstractPFT

# Models
include("../abstractmodel.jl")
export WissmannModel, BIOME4Model, ThornthwaiteModel, KoppenModel, TrollPfaffenModel

# Climatic Envelope Options
include("../models/ClimaticEnvelope/koppenbiomes.jl")
include("../models/ClimaticEnvelope/thornthwaitebiomes.jl")
include("../models/ClimaticEnvelope/trollpfaffenbiomes.jl")
include("../models/ClimaticEnvelope/wissmannbiomes.jl")

# Mechanistic Options
include("../models/MechanisticModel/biome4.jl")
include("../models/MechanisticModel/pfts.jl")

# Objects 
include("../models/MechanisticModel/constants.jl")
using .Constants: T, P0, CP, T0, G, M, R0,
    QEFFC3, DRESPC3, DRESPC4, ABS1, TETA, SLO2, JTOE, OPTRATIO,
    KO25, KC25, TAO25, CMASS, KCQ10, KOQ10, TAOQ10,
    TWIGLOSS, TUNE, LEAFRESP,
    MAXTEMP,
    LN, Y, M10, P1, STEMCARBON,
    E0, TREF, TEMP0,
    A, ES, A1, B3, B

# Now one could also define his own biome classifcation as a module
# import .MyCustomBiomeModel
# mycustombiomeclassification = MyCustomBiomeModel.MyCustomBiomeClassification()

function main(
    coordstring::String,
    co2::T,
    diagnosticmode::Bool,
    tempfile::String,
    precfile::String,
    sunfile::String,
    soilfile::String,
    year::String,
    model::String
) where {T <: Real}

    # Check the model in use
    model_instance = if model == "biome4"
        BIOME4Model()
    elseif model == "wissmann"
        WissmannModel()
        # FIXME we need a placeholder for NULL PFTs
    elseif model == "thornthwaite"
        ThornthwaiteModel()
    elseif model == "koppengeiger"
        KoppenModel()
    elseif model == "trollpfaffen"
        TrollPfaffenModel()
    else
        error("Unknown model: $model")
    end

    # Open the first dataset just to get the dimensions for the output, then close again
    temp_ds = Raster(tempfile, name = "temp", lazy = true) 
    lon_full = lookup(temp_ds, X)
    lat_full = lookup(temp_ds, Y)
    # Now hardcoded will be determined by whc
    xlen = length(lon_full)
    ylen = length(lat_full)
    llen = 2
    tlen = 12
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
        output_dataset = NCDataset(outfile, "a")  # Open in append mode FIXME change to rasters

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
        wdom_var = defVar(output_dataset, "wdom", Int16, ("lon", "lat"), attrib = OrderedDict("description" => "Dominant woody vegetation"))
        gdom_var = defVar(output_dataset, "gdom", Int16, ("lon", "lat"), attrib = OrderedDict("description" => "Dominant grass vegetation"))
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

    # Set up chunking variables
    x_chunk_size = 1000
    chunk_size = x_chunk_size  # Number of x indices to process in each chunk
    lat_chunk = nothing

    # Read latitude (only once since it's the same for all x chunks)
    Dataset(tempfile) do ds
        lat_chunk = ds["lat"][stry:endy]
    end

    for x_chunk_start in strx:chunk_size:endx
        x_chunk_end = min(x_chunk_start + x_chunk_size - 1, endx)
        current_chunk_size = x_chunk_end - x_chunk_start + 1

        println("Processing x indices from $x_chunk_start to $x_chunk_end")

        # Define missing value
        missval_sp = T(-9999.0)

        # Read longitude for this chunk
        lon_chunk = lon_full[x_chunk_start:x_chunk_end]

        temp_chunk = Raster(tempfile, name = "temp", lazy = true)[x_chunk_start:x_chunk_end, stry:endy, :]
        temp_chunk = coalesce.(temp_chunk, missval_sp)

        # Compute tcm_chunk as the minimum of temp_chunk over months
        tcm_chunk = minimum(temp_chunk, dims = Ti)
        tcm_chunk = dropdims(tcm_chunk, dims=3)
        # Replace missing values with missval_sp before computation
        tcm_chunk = coalesce.(tcm_chunk, missval_sp)

        # Ensure the calculation is applied element-wise, skipping -9999
        tmin_chunk = ifelse.(tcm_chunk .!= missval_sp, T(0.006) .* tcm_chunk.^2 .+ T(1.316) .* tcm_chunk .- T(21.9), missval_sp)

        prec_chunk = Raster(precfile, name = "prec", lazy = true)[x_chunk_start:x_chunk_end, stry:endy, :]
        prec_chunk = coalesce.(prec_chunk, missval_sp)

        cldp_chunk = Raster(sunfile, name = "sun", lazy = true)[x_chunk_start:x_chunk_end, stry:endy, :]
        cldp_chunk = coalesce.(cldp_chunk, missval_sp)

        ksat_chunk = Raster(soilfile, name = "Ksat", lazy = true)[x_chunk_start:x_chunk_end, stry:endy, :]
        ksat_chunk = coalesce.(ksat_chunk, missval_sp)
        
        whc_chunk = Raster(soilfile, name = "whc", lazy = true)[x_chunk_start:x_chunk_end, stry:endy, :]
        whc_chunk = coalesce.(whc_chunk, missval_sp)
        
        # Read elevation data if available
        if @isdefined(elvfile) && isfile(elvfile)
            elv_chunk = Raster(elvfile, name = "elv", lazy = true)[x_chunk_start:x_chunk_end, stry:endy]
            elv_chunk = coalesce.(elv_chunk, missval_sp)
        else
            elv_chunk = zeros(T, (current_chunk_size, cnty))
        end

        co2_dim = Dim{:CO2}([1])
        # Create a CO2 raster with this new dimension
        co2_raster = Raster([co2], (co2_dim,))

        # Diagnostics, check whether the values make sense
        println("max temp: ", maximum(temp_chunk), ", min temp: ", minimum(temp_chunk))
        println("max tmin: ", maximum(tmin_chunk), ", min tmin: ", minimum(tmin_chunk))
        println("max prec: ", maximum(prec_chunk), ", min prec: ", minimum(prec_chunk))
        println("max cldp: ", maximum(cldp_chunk), ", min cldp: ", minimum(cldp_chunk))
        println("max ksat: ", maximum(ksat_chunk), ", min ksat: ", minimum(ksat_chunk))
        println("max whc: ", maximum(whc_chunk), ", min whc: ", minimum(whc_chunk))

        # Put the environmental values together into a single raster stack that shares the X, Y and Ti dimensions 
        # Ksat and WHC share the depth dimension called Z 
        files = (temp = temp_chunk, 
                 tmin = tmin_chunk, 
                 prec = prec_chunk, 
                 cldp = cldp_chunk, 
                 ksat = ksat_chunk, 
                 whc = whc_chunk,
                 co2 = co2_raster)
        env_variables = RasterStack(files)
                
        # Process the data in this chunk
        process_chunk(
            current_chunk_size,
            cnty,
            env_variables,
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
            strx,
            model_instance
        )

    end

    # Close the NetCDF file
    close(output_dataset)
end


function process_chunk(
    current_chunk_size, cnty,
    env_variables, diag, biome_var, wdom_var, gdom_var, 
    npp_var, tcm_var, gdd0_var, gdd5_var, subpft_var, wetness_var,
    output_dataset, strx, model_instance::BiomeModel
)where {T <: Real}
    for y in 1:cnty
        println("Serially processing y index $y")

        y_global_index = y

        # Check if the row is already processed. If yes, skip
        if all(biome_var[:, y_global_index] .!= -9999.0)
            continue
        end

        for x in 1:current_chunk_size

            if env_variables[:temp][x, y, :] == -9999.0 || (env_variables[:whc][x, y, :] == -9999.0)
                continue
            end

            process_cell(
                x, y, strx, env_variables,
                diag, biome_var, wdom_var, gdom_var, npp_var, 
                tcm_var, gdd0_var, gdd5_var, subpft_var, wetness_var, model_instance
            )
        end

        if y % 10 == 0
            sync(output_dataset)
        end
    end
end


"""
In charge of slicing the inputs

"""
function process_cell(
    x, y, strx,
    env_variables, diag,
    biome_var, wdom_var, gdom_var, npp_var, tcm_var, gdd0_var,
    gdd5_var, subpft_var, wetness_var,  model::BiomeModel
)where {T <:Real}

    if biome_var[x, y] != -9999
        println("Cell ($x, $y) already processed, skipping.")
        return
    end

    # FIXME reorder this later after selecting only our pixel
    if  env_variables[:temp][x, y, :] == -9999.0 ||  env_variables[:whc][x, y, :] == -9999.0
        return
    end    

    if haskey(env_variables, :elv)
        elv = env_variables[:elv][x, y]
    else
        elv = 0
    end
    p = P0 * (1.0 - (G * elv) / (CP * T0))^(CP * M / R0) #FIXME: should be in a modular function

    # Add p to env_variables
    p_dims = Dim{:p}([1])
    p_raster = Raster([p], (p_dims,))
    # Add it to your RasterStack
    env_variables = merge(env_variables, (p = p_raster,))

    # Get only the environmental variables for x and y to pass into the model
    # Select X = x and Y = y
    env_variables_pixel = env_variables[X = x, Y = y]


    output = run(model, env_variables_pixel) # Run the model with the provided environmental variables

    # Write results to the output variables
    # use DimensionalData

    biome_var[x_global_index, y_global_index] = output[1] # bad idea to have hardcoded index; abstract if to work with any pft property
    wdom_var[x_global_index, y_global_index] = output[12]
    gdom_var[x_global_index, y_global_index] = output[13]
    npp_var[x_global_index, y_global_index, :] = output[60:72]
    tcm_var[x_global_index, y_global_index] = output[452]
    gdd0_var[x_global_index, y_global_index] = output[453]
    gdd5_var[x_global_index, y_global_index] = output[454]
    subpft_var[x_global_index, y_global_index] = output[455]
    wetness_var[x_global_index, y_global_index] = output[10]

end


function round_to_nearest(value::T, base::T = 0.05) where {T <: AbstractFloat}
    return round(value / base) * base
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
        args["model"]
    )
end

# Make sure main is called
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

end # End of module
