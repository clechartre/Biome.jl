# Standard library
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

# Third-party
import netCDF4 as nc
import numpy as np

# First-party
from BIOME4Py.biome4 import biome4


def main(
    climatefile: str,
    soilfile: str,
    coordstring: str,
    outfile: str,
    co2: float,
    diagnosticmode: bool,
):

    print("Climate file:", climatefile)
    print("Soil file:", soilfile)

    # Open climate file
    dataset = nc.Dataset(climatefile, "r")

    # Filled ensures we are dealing with an unmasked array
    lon = dataset.variables["lon"][:].filled(-9999)
    lat = dataset.variables["lat"][:].filled(-9999)
    xlen = len(lon)
    ylen = len(lat)
    tlen = len(dataset.variables["time"][:])

    if coordstring == "alldata":
        srtx = 0
        srty = 0
        cntx = xlen
        cnty = ylen
        endx = srtx + cntx
        endy = srty + cnty
    else:
        boundingbox = [float(x) for x in coordstring.split("/")]
        lon_min = boundingbox[0]
        lon_max = boundingbox[1]
        lat_min = boundingbox[2]
        lat_max = boundingbox[3]

        srtx, srty, cntx, cnty = get_array_indices(lon_min, lon_max, lat_min, lat_max)

        endx = srtx + cntx
        endy = srty + cnty

    print("Bounding box:", srtx, srty, endx, endy)

    elv = np.zeros((cntx, cnty), dtype=np.float32)
    tmin = np.zeros((cntx, cnty), dtype=np.float32)

    temp = np.zeros((tlen, cntx, cnty), dtype=np.float32)
    prec = np.zeros((tlen, cntx, cnty), dtype=np.float32)
    cldp = np.zeros((tlen, cntx, cnty), dtype=np.float32)

    # Read elevation data
    if "elv" in dataset.variables:
        elv = dataset.variables["elv"][srtx:endx, srty:endy].filled(-9999)
    else:
        elv = np.zeros((cntx, cnty), dtype=np.float32)

    # Read temperature data
    if "temp" in dataset.variables:
        # FIXME this is still experimental
        # Find a waz to flip the axes of all of the data and make it conditional
        # so that it can handle multiple data shapes
        ivar = np.swapaxes(dataset.variables["temp"][:], 1, 2)
        ivar = ivar[:, srtx:endx, srty:endy].filled(-9999)
        scale_factor = (
            dataset.variables["temp"].scale_factor
            if "scale_factor" in dataset.variables["temp"].ncattrs()
            else 1.0
        )
        add_offset = (
            dataset.variables["temp"].add_offset
            if "add_offset" in dataset.variables["temp"].ncattrs()
            else 0.0
        )
        missing = (
            dataset.variables["temp"].missing_value
            if "missing_value" in dataset.variables["temp"].ncattrs()
            else -9999
        )
        # If value is not missing, scale and offset. 
        # Else replace with matching value from original temp (0)
        temp = np.where(ivar != missing, ivar * scale_factor + add_offset, temp)

    # Read precipitation data
    if "prec" in dataset.variables:
        ivar = np.swapaxes(dataset.variables["prec"][:], 1, 2)
        ivar = ivar[:, srtx:endx, srty:endy].filled(-9999)
        scale_factor = (
            dataset.variables["prec"].scale_factor
            if "scale_factor" in dataset.variables["prec"].ncattrs()
            else 1.0
        )
        add_offset = (
            dataset.variables["prec"].add_offset
            if "add_offset" in dataset.variables["prec"].ncattrs()
            else 0.0
        )
        missing = (
            dataset.variables["prec"].missing_value
            if "missing_value" in dataset.variables["prec"].ncattrs()
            else missing
        )
        prec = np.where(ivar != missing, ivar * scale_factor + add_offset, prec)

    # Read cloud percent data
    if "sun" in dataset.variables:
        ivar = np.swapaxes(dataset.variables["sun"][:], 1, 2)
        ivar = ivar[:, srtx:endx, srty:endy].filled(-9999)
        scale_factor = (
            dataset.variables["sun"].scale_factor
            if "scale_factor" in dataset.variables["sun"].ncattrs()
            else 1.0
        )
        add_offset = (
            dataset.variables["sun"].add_offset
            if "add_offset" in dataset.variables["sun"].ncattrs()
            else 0.0
        )
        missing = (
            dataset.variables["sun"].missing_value
            if "missing_value" in dataset.variables["sun"].ncattrs()
            else -9999
        )
        cldp = np.where(ivar != missing, ivar * scale_factor + add_offset, cldp)

    # Read minimum temperature data or estimate it
    if "tmin" in dataset.variables:
        ivar = np.swapaxes(dataset.variables["tmin"][:], 0, 1)
        ivar = ivar[srtx:endx, srty:endy].filled(-9999)
        scale_factor = (
            dataset.variables["tmin"].scale_factor
            if "scale_factor" in dataset.variables["tmin"].ncattrs()
            else 1.0
        )
        add_offset = (
            dataset.variables["tmin"].add_offset
            if "add_offset" in dataset.variables["tmin"].ncattrs()
            else 0.0
        )
        missing = (
            dataset.variables["tmin"].missing_value
            if "missing_value" in dataset.variables["tmin"].ncattrs()
            else -9999
        )
        tmin = np.where(ivar != missing, ivar * scale_factor + add_offset, tmin)
    else:
        tmin = np.min(temp, axis=2)
        tmin = np.where(tmin != -9999.0, 0.006 * tmin**2 + 1.316 * tmin - 21.9, tmin)

    dataset.close()

    # Open soil file and read variables
    dataset = nc.Dataset(soilfile, "r")
    llen = len(dataset.dimensions["soil_layer"])

    whc = np.zeros((endx, endy, llen), dtype=np.float32)
    ksat = np.zeros((endx, endy, llen), dtype=np.float32)

    if "whc" in dataset.variables:
        whc = dataset.variables["whc"][srtx:endx, srty:endy, :].filled(-9999)
        whc = np.moveaxis(whc, 2, 1)

    if "perc" in dataset.variables:
        ksat = dataset.variables["perc"][srtx:endx, srty:endy, :].filled(-9999)
        ksat = np.moveaxis(ksat, 2, 1)

    dataset.close()

    # Run the prediction
    biome, wdom, gdom, npp = serial_process(
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

    # Prepare output file
    output_dataset = nc.Dataset(outfile, "w", format="NETCDF4")
    # need to make this the dimension of biome
    output_dataset.createDimension("lon", biome.shape[0])
    output_dataset.createDimension("lat", biome.shape[1])
    output_dataset.createDimension("time", llen)
    output_dataset.createDimension("months", npp.shape[2])

    # Define output variables
    lon_var = output_dataset.createVariable("lon", np.float64, ("lon",))
    lat_var = output_dataset.createVariable("lat", np.float64, ("lat",))
    biome_var = output_dataset.createVariable("biome", np.int16, ("lon", "lat"))
    wdom_var = output_dataset.createVariable("wdom", np.int16, ("lon", "lat"))
    gdom_var = output_dataset.createVariable("gdom", np.int16, ("lon", "lat"))
    npp_var = output_dataset.createVariable("npp", np.float32, ("lon", "lat", "months"))

    # Write variables to the output file
    lon_var[:] = lon[srtx:endx]
    lat_var[:] = lat[srty:endy]
    biome_var[:, :] = biome
    wdom_var[:, :] = wdom
    gdom_var[:, :] = gdom
    npp_var[:, :, :] = npp

    output_dataset.close()


def parallel_process(
    cntx, cnty, temp, elv, lat, co2, tmin, prec, cldp, ksat, whc, lon, diag
):
    biome = np.full((cntx, cnty), -9999, dtype=np.int16)
    wdom = np.full((cntx, cnty), -9999, dtype=np.int16)
    gdom = np.full((cntx, cnty), -9999, dtype=np.int16)
    npp = np.full((cntx, cnty, 13), -9999.0, dtype=np.float32)

    futures = []
    with ThreadPoolExecutor() as executor:
        for y in range(cnty):
            print(f"on row {y}")
            futures.append(
                executor.submit(
                    process_row,
                    y,
                    cntx,
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
                    diag,
                )
            )

        for future in as_completed(futures):
            y, biome_row, wdom_row, gdom_row, npp_row = future.result()
            biome[:, y] = biome_row
            wdom[:, y] = wdom_row
            gdom[:, y] = gdom_row
            npp[:, y, :] = npp_row

    return biome, wdom, gdom, npp


def serial_process(
    cntx, cnty, temp, elv, lat, co2, tmin, prec, cldp, ksat, whc, lon, diag
):
    biome = np.full((cntx, cnty), -9999, dtype=np.int16)
    wdom = np.full((cntx, cnty), -9999, dtype=np.int16)
    gdom = np.full((cntx, cnty), -9999, dtype=np.int16)
    npp = np.full((cntx, cnty, 13), -9999.0, dtype=np.float32)

    for y in range(cnty):
        print(f"on row {y}")
        y, biome_row, wdom_row, gdom_row, npp_row = process_row(
            y, cntx, temp, elv, lat, co2, tmin, prec, cldp, ksat, whc, lon, diag
        )
        biome[:, y] = biome_row
        wdom[:, y] = wdom_row
        gdom[:, y] = gdom_row
        npp[:, y, :] = npp_row

    return biome, wdom, gdom, npp


def process_row(y, cntx, temp, elv, lat, co2, tmin, prec, cldp, ksat, whc, lon, diag):
    # Constants
    p0 = 101325.0  # sea level standard atmospheric pressure (Pa)
    cp = 1004.68506  # constant-pressure specific heat (J kg-1 K-1)
    T0 = 288.16  # sea level standard temperature (K)
    g = 9.80665  # earth surface gravitational acceleration (m s-1)
    M = 0.02896968  # molar mass of dry air (kg mol-1)
    R0 = 8.314462618  # universal gas constant (J mol-1 K-1)

    biome_row = np.full(cntx, -9999, dtype=np.int16)
    wdom_row = np.full(cntx, -9999, dtype=np.int16)
    gdom_row = np.full(cntx, -9999, dtype=np.int16)
    npp_row = np.full((cntx, 13), -9999.0, dtype=np.float32)

    for x in range(cntx):
        input = np.zeros(50, dtype=np.float32)
        output = np.zeros(500, dtype=np.float32)

        if temp[0, x, y] == -9999.0:
            continue

        p = p0 * (1.0 - (g * elv[x, y]) / (cp * T0)) ** (cp * M / R0)

        input[0] = lat[y]
        input[1] = co2
        input[2] = p
        input[3] = tmin[x, y]
        input[4:16] = temp[:, x, y]
        input[16:28] = prec[:, x, y]
        input[28:40] = cldp[:, x, y]
        input[40] = np.mean(ksat[0:2, x, y])
        # FIXME this is the RuntimeWarning: mean of empty slice
        # Ksat only has 2 dimensions
        # for now I will reuse ksat[0:2] same for whc
        input[41] = np.mean(ksat[0:2, x, y])
        input[42] = np.sum(whc[0:2, x, y])
        input[43] = np.sum(whc[0:2, x, y])
        input[48] = lon[x]

        if diag:
            input[45] = 1.0  # diagnostic mode on
        else:
            input[45] = 0.0  # diagnostic mode off

        output = biome4(input, output)

        biome_row[x] = int(output[0])
        wdom_row[x] = int(output[11])
        gdom_row[x] = int(output[12])
        npp_row[x, :] = output[59:72]

    print(f"row {y} processed")

    return y, biome_row, wdom_row, gdom_row, npp_row


def get_array_indices(lon_min, lon_max, lat_min, lat_max, resolution=0.5):
    """
    Get array indices for a given bounding box with specified resolution.

    Parameters:
    - lon_min: Minimum longitude
    - lon_max: Maximum longitude
    - lat_min: Minimum latitude
    - lat_max: Maximum latitude
    - resolution: Resolution of the array (default is 0.5 degrees)

    Returns:
    - strx, srty: Start coordinates in the array
    - cntx, cnty: Count of tiles in the array
    """
    # Define the array dimensions based on resolution
    # Right now we define these values based on the input data but
    # we could change them if we want to increase the resolution
    lon_range = 360  # Longitude range from -180 to 180
    lat_range = 180  # Latitude range from -90 to 90

    array_height = int(lon_range / resolution)
    array_width = int(lat_range / resolution)

    # Calculate the indices
    strx = int((lon_min + 180) / resolution)
    srty = int((90 - lat_max) / resolution)
    endx = int((lon_max + 180) / resolution)
    endy = int((90 - lat_min) / resolution)

    # Calculate the counts
    cntx = endx - strx + 1
    cnty = endy - srty + 1

    return strx, srty, cntx, cnty


def handle_err(status):
    if status != 0:
        print("NetCDF Error:", status)
        sys.exit(1)


if __name__ == "__main__":
    main()
