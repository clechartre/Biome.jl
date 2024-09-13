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
    whcfile::String
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
    
        strx, stry, cntx, cnty = get_array_indices(lon_min, lon_max, lat_min, lat_max)
    
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
    temp = temp_ds["temp"][strx:endx, stry:endy, :][:, end:-1:1, :]
    tmin = tmin_ds["tmin"][strx:endx, stry:endy][:, end:-1:1]
    prec = prec_ds["prec"][strx:endx, stry:endy, :][:, end:-1:1, :]
    cldp = sun_ds["sun"][strx:endx, stry:endy, :][:, end:-1:1, :]
    ksat = ksat_ds["ksat"][strx:endx, stry:endy, :]
    whc = whc_ds["whc"][strx:endx, stry:endy, :]

    # Verify value range
    println("max temp: ", maximum(temp), ", min temp: ", minimum(temp))
    println("max tmin: ", maximum(tmin), ", min tmin: ", minimum(tmin))
    println("max prec: ", maximum(prec), ", min prec: ", minimum(prec))
    println("max cldp: ", maximum(cldp), ", min cldp: ", minimum(cldp))
    println("max ksat: ", maximum(ksat), ", min ksat: ", minimum(ksat))
    println("max whc: ", maximum(whc), ", min whc: ", minimum(whc))

    # Plot variables
    plot_folder = "/home/lechartr/BIOME4Py/variable_plots"
    if !isdir(plot_folder)
        mkdir(plot_folder)
    end
    year = "2005"
    # # Plot input variables
    save_plot("temperature", lon, lat, temp[:, :, 1], "Temperature", (-60, 60), plot_folder, year)
    save_plot("tmin", lon, lat, tmin[:, :], "Min Temperature", (-60, 10), plot_folder, year)
    save_plot("precipitation", lon, lat, prec[:, :, 1], "Precipitation", (0, 400), plot_folder, year)
    save_plot("cloud_cover", lon, lat, cldp[:, :, 1], "Cloud Cover", (0, 100), plot_folder, year)
    save_plot("ksat", lon, lat, ksat[:, :, 1], "Saturated Conductivity", (0, 50), plot_folder, year)
    save_plot("whc", lon, lat, whc[:, :, 1], "Water Holding Capacity", (0, 5000), plot_folder, year)

    close(temp_ds)
    close(tmin_ds)
    close(prec_ds)
    close(sun_ds)
    close(ksat_ds)
    close(whc_ds)

    # Run the prediction
    biome, wdom, gdom, npp, tcm, gdd0, gdd5, subpft, wetness = parallel_process(
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
    )


    # Get the current date and time
    current_datetime = Dates.format(now(), "yyyy-mm-dd_HHMM")
    # Dynamically create the output filename
    outfile = "/home/lechartr/BIOME4Py/output_$(current_datetime).nc"    
    # Prepare output file (creating a new NetCDF file)
    output_dataset = NCDataset(outfile, "c")  # "c" for create

    # Define the dimensions of the dataset based on the biome matrix size
    defDim(output_dataset, "lon", size(biome, 1))
    defDim(output_dataset, "lat", size(biome, 2))
    defDim(output_dataset, "time", llen)
    defDim(output_dataset, "months", size(npp, 3))

    # Define variables with appropriate types and dimensions
    lon_var = defVar(output_dataset, "lon", Float64, ("lon",), attrib = OrderedDict(
        "units" => "degrees_east"
    ))
    lat_var = defVar(output_dataset, "lat", Float64, ("lat",), attrib = OrderedDict(
        "units" => "degrees_north"
    ))
    biome_var = defVar(output_dataset, "biome", Int16, ("lon", "lat"), attrib = OrderedDict(
        "description" => "Biome classification"
    ))
    wdom_var = defVar(output_dataset, "wdom", Float64, ("lon", "lat"), attrib = OrderedDict(
        "description" => "Dominant woody vegetation"
    ))
    gdom_var = defVar(output_dataset, "gdom", Float64, ("lon", "lat"), attrib = OrderedDict(
        "description" => "Dominant grass vegetation"
    ))
    npp_var = defVar(output_dataset, "npp", Float32, ("lon", "lat", "months"), attrib = OrderedDict(
        "units" => "gC/m^2/month",
        "description" => "Net primary productivity"
    ))
    tcm_var = defVar(output_dataset, "tcm", Float64, ("lon", "lat"), attrib = OrderedDict(
        "description" => "tcm"
    ))
    gdd0_var = defVar(output_dataset, "gdd0", Float64, ("lon", "lat"), attrib = OrderedDict(
        "description" => "gdd0"
    ))
    gdd5_var = defVar(output_dataset, "gdd5", Float64, ("lon", "lat"), attrib = OrderedDict(
        "description" => "gdd5"
    ))
    subpft_var = defVar(output_dataset, "subpft", Float64, ("lon", "lat"), attrib = OrderedDict(
        "description" => "subpft"
    ))
    wetness_var = defVar(output_dataset, "wetness", Float64, ("lon", "lat"), attrib = OrderedDict(
        "description" => "wetness"
    ))

    # Write data to variables
    lon_var[:] = lon
    lat_var[:] = lat
    biome_var[:, :] = biome
    wdom_var[:, :] = wdom
    gdom_var[:, :] = gdom
    npp_var[:, :, :] = npp
    tcm_var[:, :] = tcm
    gdd0_var[:, :] = gdd0
    gdd5_var[:, :] = gdd5
    subpft_var[:, :] = subpft
    wetness_var[:, :] = wetness

    # Add global attributes to the dataset
    output_dataset.attrib["title"] = "Biome prediction output"
    output_dataset.attrib["institution"] = "WSL"
    output_dataset.attrib["source"] = "BIOME4 Model"

    # Close the NetCDF file
    close(output_dataset)
end


function parallel_process(
    cntx, cnty, temp, elv, lat, co2, tmin, prec, cldp, ksat, whc, lon, diag
)
    biome = fill(-9999, cntx, cnty)
    wdom = fill(-9999, cntx, cnty)
    gdom = fill(-9999, cntx, cnty)
    npp = fill(-9999.0f0, cntx, cnty, 13)
    tcm = fill(-9999.0f0, cntx, cnty)
    gdd0 = fill(-9999.0f0, cntx, cnty)
    gdd5 = fill(-9999.0f0, cntx, cnty)
    subpft = fill(-9999.0f0, cntx, cnty)
    wetness = fill(-9999.0f0, cntx, cnty)

    futures = []
    for y in 1:cnty
        println("on row $y")
        push!(futures, Threads.@spawn process_row(y, cntx, temp, elv, lat, co2, tmin, prec, cldp, ksat, whc, lon, diag))
    end

    for future in futures
        y, biome_row, wdom_row, gdom_row, npp_row, tcm_row, gdd0_row, gdd5_row, subpft_row, wetness_row = fetch(future)
        biome[:, y] = biome_row
        wdom[:, y] = wdom_row
        gdom[:, y] = gdom_row
        npp[:, y, :] = npp_row
        tcm[:, y] = tcm_row
        gdd0[:, y] = gdd0_row
        gdd5[:, y] = gdd5_row
        subpft[:, y] = subpft_row
        wetness[:, y] = wetness_row
    end

    return biome, wdom, gdom, npp, tcm, gdd0, gdd5, subpft, wetness
end

function serial_process(
    cntx, cnty, temp, elv, lat, co2, tmin, prec, cldp, ksat, whc, lon, diag
)
    biome = fill(-9999, cntx, cnty)
    wdom = fill(-9999, cntx, cnty)
    gdom = fill(-9999, cntx, cnty)
    npp = fill(-9999.0f0, cntx, cnty, 13)
    tcm = fill(-9999.0f0, cntx, cnty)
    gdd0 = fill(-9999.0f0, cntx, cnty)
    gdd5 = fill(-9999.0f0, cntx, cnty)
    subpft = fill(-9999.0f0, cntx, cnty)
    wetness = fill(-9999.0f0, cntx, cnty)

    for y in 1:cnty
        println("on row $y")
        y, biome_row, wdom_row, gdom_row, npp_row, tcm_row, gdd0_row, gdd5_row, subpft_row, wetness_row = process_row(y, cntx, temp, elv, lat, co2, tmin, prec, cldp, ksat, whc, lon, diag)
        biome[:, y] = biome_row
        wdom[:, y] = wdom_row
        gdom[:, y] = gdom_row
        npp[:, y, :] = npp_row
        tcm[:, y] = tcm_row
        gdd0[:, y] = gdd0_row
        gdd5[:, y] = gdd5_row
        subpft[:, y] = subpft_row
        wetness[:, y] = wetness_row
    end

    return biome, wdom, gdom, npp, tcm, gdd0, gdd5, subpft, wetness
end

function process_row(y, cntx, temp, elv, lat, co2, tmin, prec, cldp, ksat, whc, lon, diag)
    # Constants
    p0 = 101325.0  # sea level standard atmospheric pressure (Pa)
    cp = 1004.68506  # constant-pressure specific heat (J kg-1 K-1)
    T0 = 288.16  # sea level standard temperature (K)
    g = 9.80665  # earth surface gravitational acceleration (m s-1)
    M = 0.02896968  # molar mass of dry air (kg mol-1)
    R0 = 8.314462618  # universal gas constant (J mol-1 K-1)

    biome_row = fill(-9999, cntx)
    wdom_row = fill(-9999, cntx)
    gdom_row = fill(-9999, cntx)
    npp_row = fill(-9999.0f0, cntx, 13)
    tcm_row = fill(-9999.0f0, cntx)
    gdd0_row = fill(-9999.0f0, cntx)
    gdd5_row = fill(-9999.0f0, cntx)
    subpft_row = fill(-9999.0f0, cntx)
    wetness_row = fill(-9999.0f0, cntx)

    for x in 1:cntx
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
        input[43] = coalesce(sum(whc[x, y, 1:2]), -9999.0f0)
        input[44] = coalesce(sum(whc[x, y, 1:2]), -9999.0f0)
        input[49] = lon[x]

        input[46] = diag ? 1.0 : 0.0  # diagnostic mode

        output = BIOME4.biome4(input, output)

        biome_row[x] = output[1]
        wdom_row[x] = output[12]
        gdom_row[x] = output[13]
        npp_row[x, :] = output[60:72]
        tcm_row[x] = output[452]
        gdd0_row[x] = output[453]
        gdd5_row[x] = output[454]
        subpft_row[x] = output[455]
        wetness_row[x] = output[10]
    end

    println("row $y processed")

    return y, biome_row, wdom_row, gdom_row, npp_row, tcm_row, gdd0_row, gdd5_row, subpft_row, wetness_row
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
    - lon_min: Minimum longitude
    - lon_max: Maximum longitude
    - lat_min: Minimum latitude
    - lat_max: Maximum latitude
    - resolution: Resolution of the array (default is 0.5 degrees)
    Returns:
    - strx, stry: Start coordinates in the array
    - cntx, cnty: Count of tiles in the array
    """
    # Define the array dimensions based on resolution
    lon_range = 360  # Longitude range from -180 to 180
    lat_range = 180  # Latitude range from -90 to 90

    array_height = Int(lon_range / resolution)
    array_width = Int(lat_range / resolution)

    # Calculate the indices
    strx = Int((lon_min + 180) / resolution)
    stry = Int((90 - lat_max) / resolution)
    endx = Int((lon_max + 180) / resolution)
    endy = Int((90 - lat_min) / resolution)

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
    end
    return parse_args(s)
end

end # End of module