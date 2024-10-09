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
    resolution::String
)

    println("Temperature file: $tempfile")
    println("Temperature minimum file: $tminfile")
    println("Precipitation file: $precfile")
    println("Cloud percent file: $sunfile")
    println("Saturated conductivity file: $ksatfile")
    println("Water holding capacity file $whcfile")

    # Open datasets
    temp_ds = NCDataset(tempfile, "a")
    temp_ds = uniform_fill_value(temp_ds)
    lon = temp_ds["lon"][:]
    lat = temp_ds["lat"][:]

    tmin_ds = NCDataset(tminfile, "a")
    tmin_ds = uniform_fill_value(tmin_ds)

    prec_ds = NCDataset(precfile, "a")
    prec_ds = uniform_fill_value(prec_ds)

    sun_ds = NCDataset(sunfile, "a")
    sun_ds = uniform_fill_value(sun_ds)

    ksat_ds = NCDataset(ksatfile, "a")
    ksat_ds = uniform_fill_value(ksat_ds)

    whc_ds = NCDataset(whcfile, "a")
    whc_ds = uniform_fill_value(whc_ds)
    layers = whc_ds["soil_layer"][:]

    xlen = length(lon)
    ylen = length(lat)
    llen = length(layers)
    tlen = 12
    # Set the resolution value based on the flag
    res_value = resolution == "low" ? 0.5 : 0.009

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

    elv = zeros(Float32, (cntx, cnty))
    tmin = zeros(Float32, (cntx, cnty))
    temp = zeros(Float32, (cntx, cnty, tlen))
    prec = zeros(Float32, (cntx, cnty, tlen))
    cldp = zeros(Float32, (cntx, cnty, tlen))

    # Read elevation data if available
    if @isdefined(elv_ds) && elv_ds !== nothing
        elv = getindex.(elv_ds["elv"][strx:endx, stry:endy], :)
    else
        elv = zeros(Float32, (cntx, cnty))
    end

    # Keep lon and lat as they are, cut according to bbox
    lon = lon[strx:endx]
    lat = lat[stry:endy]

    # Flip the data arrays along the latitude axis
    temp = temp_ds["temp"][strx:endx, stry:endy, :][:, :, :]
    tmin = tmin_ds["tmin"][strx:endx, stry:endy][:, :]
    prec = prec_ds["prec"][strx:endx, stry:endy, :][:, :, :]
    cldp = sun_ds["sun"][strx:endx, stry:endy, :][:, :, :]
    ksat = ksat_ds["ksat"][strx:endx, stry:endy, :][:, end:-1:1, :]
    whc = whc_ds["whc"][strx:endx, stry:endy, :][:, end:-1:1, :]


    # Verify value range
    println("max temp: ", maximum(temp), ", min temp: ", minimum(temp))
    println("max tmin: ", maximum(tmin), ", min tmin: ", minimum(tmin))
    println("max prec: ", maximum(prec), ", min prec: ", minimum(prec))
    println("max cldp: ", maximum(cldp), ", min cldp: ", minimum(cldp))
    println("max ksat: ", maximum(ksat), ", min ksat: ", minimum(ksat))
    println("max whc: ", maximum(whc), ", min whc: ", minimum(whc))

    # Plot variables
    plot_folder = "./variable_plots"
    if !isdir(plot_folder)
        mkdir(plot_folder)
    end

    # Plot input variables
    save_plot("temperature", lon, lat, temp[:, :, 1], "Temperature", (-60, 60), plot_folder, year)
    save_plot("tmin", lon, lat, tmin[:, :], "Min Temperature", (-60, 10), plot_folder, year)
    save_plot("precipitation", lon, lat, prec[:, :, 1], "Precipitation", (0, 400), plot_folder, year)
    save_plot("cloud_cover", lon, lat, cldp[:, :, 1], "Cloud Cover", (0, 100), plot_folder, year)
    save_plot("ksat", lon, lat, ksat[:, :, 1], "Saturated Conductivity", (0, 50), plot_folder, year)
    save_plot("whc", lon, lat, whc[:, :, 1], "Water Holding Capacity", (0, 500), plot_folder, year)

    close(temp_ds)
    close(tmin_ds)
    close(prec_ds)
    close(sun_ds)
    close(ksat_ds)
    close(whc_ds)

    # Set up the output

    # Dynamically create the output filename
    outfile = "./output_$(year).nc"
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
        output_dataset = NCDataset(outfile, "c")  # Create a new file
            # Define dimensions and variables here if creating the file
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
        npp_var = defVar(output_dataset, "npp", Float32, ("lon", "lat", "pft"), attrib = OrderedDict("units" => "gC/m^2/month","description" => "Net primary productivity"))
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

    # Find the last processed row
    last_processed_row = 1
    for y in 1:cnty
        if all(biome_var[:, y] .== -9999)
            last_processed_row = y
            break
        end
    end
    println("Resuming from row $last_processed_row.")

    # Write to the dataset
    # Run the prediction
    serial_process(
        cntx,
        cnty,
        temp,
        elv,
        lat,
        co2,
        tmin,
        prec,
        cldp,
        ksat,
        whc,
        lon,
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
        last_processed_row
    )

    # Close the NetCDF file
    close(output_dataset)
end


function parallel_process(
    cntx, cnty, temp, elv, lat, co2, tmin, prec, cldp, ksat, whc, lon, diag,
    biome_var, wdom_var, gdom_var, npp_var, tcm_var, gdd0_var, gdd5_var, subpft_var, wetness_var, output_dataset, last_processed_row
)

    futures = []
    for y in last_processed_row:cnty
        println("on row $y")
        push!(futures, Threads.@spawn process_row(y, cntx, temp, elv, lat, co2, tmin, prec, cldp, ksat, whc, lon, diag,
                                                biome_var, wdom_var, gdom_var, npp_var, tcm_var, gdd0_var, gdd5_var, subpft_var, wetness_var, output_dataset))
    end

    for future in futures
        fetch(future)

    end

end

function serial_process(
    cntx, cnty, temp, elv, lat, co2, tmin, prec, cldp, ksat, whc, lon, diag,
    biome_var, wdom_var, gdom_var, npp_var, tcm_var, gdd0_var, gdd5_var, subpft_var, wetness_var, output_dataset, last_processed_row
)
    for y in last_processed_row:cnty
        println("on row $y")
        process_row(y, cntx, temp, elv, lat, co2, tmin, prec, cldp, ksat, whc, lon, diag,
                    biome_var, wdom_var, gdom_var, npp_var, tcm_var, gdd0_var, gdd5_var, subpft_var, wetness_var, output_dataset)

    end

end

function process_row(y, cntx, temp, elv, lat, co2, tmin, prec, cldp, ksat, whc, lon, diag,
                    biome_var, wdom_var, gdom_var, npp_var, tcm_var, gdd0_var, gdd5_var, subpft_var, wetness_var, output_dataset)
    # Constants
    p0 = 101325.0  # sea level standard atmospheric pressure (Pa)
    cp = 1004.68506  # constant-pressure specific heat (J kg-1 K-1)
    T0 = 288.16  # sea level standard temperature (K)
    g = 9.80665  # earth surface gravitational acceleration (m s-1)
    M = 0.02896968  # molar mass of dry air (kg mol-1)
    R0 = 8.314462618  # universal gas constant (J mol-1 K-1)

    for x in 1:cntx

        if biome_var[x, y] != -9999
            println("Row $y already processed, skipping.")
            continue
        end

        input = zeros(Float32, 50)
        output = zeros(Float32, 500)

        if temp[x, y, 1] == -9999.0
            continue
        end

        p = p0 * (1.0 - (g * elv[x, y]) / (cp * T0))^(cp * M / R0)

        input[1] = lat[y]
        input[2] = co2
        input[3] = p
        input[4] = tmin[x, y]
        input[5:16] = temp[x, y, :]
        input[17:28] = prec[x, y, :]
        input[29:40] = cldp[x, y, :]
        input[41] = coalesce(mean(ksat[x, y, 1:2]), -9999.0f0)
        input[42] = coalesce(mean(ksat[x, y, 1:2]), -9999.0f0)
        input[43] = coalesce(whc[x, y, 1]/10, -9999.0f0)
        input[44] = coalesce(whc[x, y, 2]/10, -9999.0f0)
        input[49] = lon[x]

        input[46] = diag ? 1.0 : 0.0  # diagnostic mode

        output = BIOME4.biome4(input, output)

        biome_var[x, y] = output[1]
        wdom_var[x, y] = output[12]
        gdom_var[x, y] = output[13]
        npp_var[x, y, :] = output[60:72]
        tcm_var[x, y] = output[452]
        gdd0_var[x, y] = output[453]
        gdd5_var[x, y] = output[454]
        subpft_var[x, y] = output[455]
        wetness_var[x, y] = output[10]
    end

    # Only sync every 10 rows for performance
    if y % 10 == 0
        sync(output_dataset)
    end

    println("Row $y processed and written.")

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
    strx = Int((lon_min + 180) / resolution)
    endx = Int((lon_max + 180) / resolution)
    stry = Int((lat_min + 90) / resolution)
    endy = Int((lat_max + 90) / resolution)

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
    closeall()  # Clears any previous plots to avoid duplication

    # Create the plot
    p = heatmap(lon, lat, data, xlabel = "Longitude", ylabel = "Latitude", title = title, clims = clims)

    # Define the output file path
    filepath = joinpath(plot_folder, @sprintf("%s_%s.png", plot_name, year))

    # Save the plot
    println("Saving plot to $filepath")
    savefig(p, filepath)

end


function uniform_fill_value(ds::NCDataset; fill_value=-9999)
    for varname in keys(ds)  # Iterate through all variable names in the dataset
        var = ds[varname]  # Access the variable by its name

        # Check if the variable has a _FillValue attribute
        if haskey(var.attrib, "_FillValue")
            original_fill_value = var.attrib["_FillValue"]
            data = Array(var)  # Convert the variable to a regular Julia array

            # Replace _FillValue and Missing with the specified fill value
            data[(data .== original_fill_value) .| ismissing.(data)] .= fill_value

            # Ensure the data type matches the variable's expected type
            try
                var[:] = data  # Write the modified data back to the variable
            catch e
                println("Error writing data back to variable $varname: ", e)
            end
        end
    end
    return ds
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
        args["resolution"] 
    )
end

# Make sure main is called
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

end # End of module
