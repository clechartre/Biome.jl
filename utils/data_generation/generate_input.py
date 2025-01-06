import os
import click
import requests
import xarray as xr
import numpy as np
import rasterio
from rasterio.warp import reproject, Resampling
from global_land_mask import globe

def download_file(url: str, filename: str) -> None:
    """
    Download a file from a given URL and saves it to the specified filename.

    Parameters:
    url (str): The URL to download the file from.
    filename (str): The local path where the downloaded file will be saved.
    """
    response = requests.get(url)
    if response.status_code == 200:
        with open(filename, 'wb') as f:
            f.write(response.content)
        print(f"Downloaded {filename}")
    else:
        print(f"Failed to download {filename} from {url}")


def load_land_mask(mask_shape: tuple, fill_value: float = 327.67) -> xr.DataArray:
    """
    Generate a land mask using latitude and longitude grids, reprojects to WGS84.

    Parameters:
    mask_shape (tuple): Shape of the land mask (lat_pixels, lon_pixels).
    fill_value (float): Placeholder value for NaNs in the grid.

    Returns:
    xr.DataArray: A reprojected land mask in xarray DataArray format.
    """
    # Generate longitude and latitude arrays
    lon = np.linspace(-180, 180, mask_shape[1])
    lat = np.linspace(-90, 90, mask_shape[0])
    lon_grid, lat_grid = np.meshgrid(lon, lat)

    # Create a mask for the original NaN or masked values
    nan_mask = (lon_grid == fill_value) | (lat_grid == fill_value)

    # Replace NaN or fill values with a placeholder outside the domain
    lon_clean = np.where(nan_mask, 170, lon_grid)
    lat_clean = np.where(nan_mask, -90, lat_grid)

    # Generate the land mask
    land_mask = globe.is_land(lat_clean, lon_clean)

    # Reapply the original NaN mask
    land_mask = np.where(nan_mask, False, land_mask)

    # Convert the mask to an xarray DataArray
    reprojected_mask_xr = xr.DataArray(land_mask, dims=("lat", "lon"), coords={"lat": lat, "lon": lon})

    return reprojected_mask_xr


def reproject_to_wgs84(
    src_array: np.ndarray, 
    src_transform: rasterio.transform.Affine, 
    src_crs: rasterio.crs.CRS, 
    dst_bounds: tuple, 
    dst_shape: tuple
) -> np.ndarray:
    """
    Reproject a source array to WGS84 coordinates with specified destination bounds and shape.

    Parameters:
    src_array (np.ndarray): Source array to reproject.
    src_transform (rasterio.transform.Affine): Transform of the source array.
    src_crs (rasterio.crs.CRS): Coordinate reference system of the source array.
    dst_bounds (tuple): Destination bounds (min_lon, min_lat, max_lon, max_lat).
    dst_shape (tuple): Shape of the destination array (lat_pixels, lon_pixels).

    Returns:
    np.ndarray: The reprojected array.
    """
    dst_crs = rasterio.crs.CRS.from_string("+proj=longlat +datum=WGS84 +no_defs")
    
    # Define the destination transform directly based on the destination bounds and shape
    dst_transform = rasterio.transform.from_bounds(*dst_bounds, dst_shape[1], dst_shape[0])
    
    # Initialize a destination array for reprojection
    reprojected_data = np.empty(dst_shape, dtype=np.float32)

    # Reproject the array
    reproject(
        source=src_array,
        destination=reprojected_data,
        src_transform=src_transform,
        src_crs=src_crs,
        dst_transform=dst_transform,
        dst_crs=dst_crs,
        resampling=Resampling.nearest
    )

    return reprojected_data


def resample_to_mean(input_cog_path: str, lon_pixels: int, lat_pixels: int) -> xr.DataArray:
    """
    Resample an input raster to the specified resolution, and applies a land mask.

    Parameters:
    input_cog_path (str): Path to the input raster file.
    lon_pixels (int): Number of pixels in the longitude direction.
    lat_pixels (int): Number of pixels in the latitude direction.

    Returns:
    xr.DataArray: The resampled and masked data as an xarray DataArray.
    """
    with rasterio.open(input_cog_path) as dataset:
        data = dataset.read(1)  # Read the first band
        src_transform = dataset.transform
        src_crs = dataset.crs

        # Reproject to WGS84 with target bounds and shape
        dst_bounds = (-180, -90, 180, 90)
        dst_shape =  (lat_pixels, lon_pixels)

        reprojected_data = reproject_to_wgs84(
            src_array=data,
            src_transform=src_transform,
            src_crs=src_crs,
            dst_bounds=dst_bounds,
            dst_shape=dst_shape
        )


    # Convert the reprojected array to an xarray DataArray
    lon = np.linspace(-180, 180, dst_shape[1])
    lat = np.linspace(-90, 90, dst_shape[0])
    reprojected_array = xr.DataArray(reprojected_data, dims=("lat", "lon"), coords={"lat": lat, "lon": lon})

    # Flip into the right direction
    reprojected_array = reprojected_array[::-1, :]

    lon_size = reprojected_array.shape[1]
    lat_size = reprojected_array.shape[0]


    land_mask = load_land_mask(mask_shape=(lat_size, lon_size))

    # Ensure that mask and data array align in terms of dimensions
    if reprojected_array.shape != land_mask.shape:
        raise ValueError(f"Data array shape {reprojected_array.shape} and mask shape {land_mask.shape} do not match.")

    # Check if coordinates are aligned, if not, ensure re-alignment (reproject if needed, here just ensure matching coordinates)
    if not np.array_equal(land_mask.lat, reprojected_array.lat) or not np.array_equal(land_mask.lon, reprojected_array.lon):
        # Assign the coordinates of reprojected_array to land_mask only if they do not match
        land_mask = land_mask.assign_coords(lat=reprojected_array.lat, lon=reprojected_array.lon)

    # Apply the land mask and handle NaNs in the reprojected array
    # Mask where land_mask is 0 (False) or reprojected_array has NaNs
    masked_array = xr.where((land_mask == 0) | np.isnan(reprojected_array), -9999, reprojected_array)


    return masked_array

@click.command()
@click.option('--var', type=str, required=True, help='Variable to process (e.g., pr, tas, tasmin, clt)')
@click.option('--year', type=str, required=True, help='Year to process (e.g., 2013)')
@click.option('--resolution', type=click.Choice(['low', 'high']), required=True, help='Resolution to download data at, low = 55km, high = 1km ')
def process_and_save_variable(var: str, year: int, resolution: str) -> None:
    """
    Download, process, and save climate variable data at the specified resolution.

    Parameters:
    var (str): Climate variable to process (e.g., pr, tas, tasmin, clt).
    year (int): Year of data to process.
    resolution (str): Resolution for the data ('low' = 55km, 'high' = 1km).
    """
    base_url = "https://os.zhdk.cloud.switch.ch/chelsav2/GLOBAL/climatologies"
    data_arrays = []

    if resolution == "low":
        lon_pixels = 720
        lat_pixels = 360
    elif resolution == "high":
        lon_pixels =  43200
        lat_pixels = 21600

    dst_bounds = (-180, -90, 180, 90)
    dst_shape = (lat_pixels, lon_pixels)


    for month in range(1, 13):
        # Download corresponding file
        month_str = f"{month:02d}"
        filename = f"CHELSA_{var}_{month_str}_{year}_V.2.1.tif"
        url = f"{base_url}/{year}/{var}/{filename}"
        download_file(url, filename)

        # Reshape 
        da = resample_to_mean(filename, lon_pixels, lat_pixels)

        data_arrays.append(da)
        os.remove(filename)

    lon = np.linspace(-180 + 0.25, 180 - 0.25, lon_pixels)
    lat = np.linspace(-90 + 0.25, 90 - 0.25, lat_pixels)
    ds = xr.Dataset()

    var_map = {
        'tas': ('temp', "monthly mean temperature", "degC", 0.1, -273.15),
        'tasmin': ('tmin', "annual minimum temperature", "degC", 0.1, -273.15),
        'pr': ('prec', "monthly total precipitation", "mm", 0.01, 0),
        'clt': ('sun', "total cloud cover", "percent", 0.01, 0),
        'cmi': ('cmi', "climate moisture index", "kg m-2 month-1", 0.1, 0)
    }

    if var in var_map:
        var_name, long_name, units, scale_factor, add_offset = var_map[var]
        if var == 'tasmin':
            da = xr.concat(data_arrays, dim='time').min(dim='time')
            da = da.assign_coords(lon=('lon', lon), lat=('lat', lat))
        else:
            da = xr.concat(data_arrays, dim='time')
            da = da.assign_coords(
                lon=('lon', lon),
                lat=('lat', lat),
                time=('time', np.arange(1, len(data_arrays) + 1))
            )
        da.name = var_name
        da.attrs.update({
            "long_name": long_name,
            "units": units,
            "_FillValue": -9999,
            "scale_factor": scale_factor,
            "add_offset": add_offset
        })
        ds[var_name] = da

    ds['lon'] = lon
    ds['lat'] = lat

    if 'time' in ds.coords:
        ds['time'] = np.arange(1, len(data_arrays) + 1)
        ds.time.attrs = {
            "long_name": "time",
            "units": "month",
            "_FillValue": -9999
        }

    ds.lon.attrs = {
        "long_name": "longitude",
        "units": "degrees_east",
        "_FillValue": -9999
    }

    ds.lat.attrs = {
        "long_name": "latitude",
        "units": "degrees_north",
        "_FillValue": -9999
    }

    output_nc_path = f"/Users/capucinelechartre/Documents/PhD/BIOME4Py/data/generated_data/1k/{var_name}_{year}_new.nc"
    ds.to_netcdf(output_nc_path)
    print(f"Aggregated data for {var_name} saved to {output_nc_path}")


if __name__ == "__main__":
        process_and_save_variable()