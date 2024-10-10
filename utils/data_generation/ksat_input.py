"""
Generating a Saturated Conductivity Dataset (Ksat) from downloaded tif files.

Gupta, S., Lehmann, P., Bonetti, S., Papritz, A., and Or, D., (2020):
Global prediction of soil saturated hydraulic conductivity using random forest in a Covariate-based Geo Transfer Functions (CoGTF) framework.
Journal of Advances in Modeling Earth Systems, 13(4), e2020MS002242. https://agupubs.onlinelibrary.wiley.com/doi/full/10.1029/2020MS002242

Dataset source is: https://zenodo.org/records/3935359
"""

import click
import geopandas as gpd
from matplotlib import pyplot as plt
import numpy as np
import rasterio
from rasterio.warp import reproject, Resampling
from rasterio.features import rasterize
from rasterio.transform import from_bounds
import xarray as xr

@click.command()
@click.option('--output_path', type=str, required=True, help='Output file path')
@click.option('--resolution', type=click.Choice(['low', 'high']), required=True, help='Resolution to download data at, low = 55km, high = 1km ')
def save_netcdf(output_path: str, resolution: str) -> None:
    """
    Save a NetCDF dataset containing soil saturated hydraulic conductivity (Ksat) values.

    Parameters:
    - output_path (str): Path where the NetCDF file will be saved.
    - resolution (str): Resolution of the dataset to be downloaded. 'low' for 55km resolution, 'high' for 1km resolution.
    """
        
    if resolution == "low":
        lon_pixels = 720
        lat_pixels = 360
    elif resolution == "high":
        lon_pixels =  43200
        lat_pixels = 20880

    # Save the new values as a .nc dataset with metadata
    lon = np.linspace(-180, 180, lon_pixels)
    lat = np.linspace(-90, 90, lat_pixels)
    soil_layers = ['0', '30']
    ksat_layers = []

    shapefile_path = "/home/lechartr/BIOME4Py/data/downloaded_data/countries_shapefile/ne_110m_admin_0_countries.shp"
    dst_bounds = (-180, -90, 180, 90)
    dst_shape = (lat_pixels, lon_pixels)

    land_mask = load_land_mask(
        mask_shape=(lat_pixels, lon_pixels),  # Initial shape before reprojection
        transform=from_bounds(-180, -90, 180, 90, lon_pixels, lat_pixels),  # Initial transform before reprojection
        crs="EPSG:4326",
        shapefile_path=shapefile_path,
        dst_bounds=dst_bounds,
        dst_shape=dst_shape
    )

    for depth in soil_layers: 
            input_path = f'/home/lechartr/BIOME4Py/data/downloaded_data/ksat_{depth}.tif'
            dataset = ksat_input(input_path, lon_pixels, lat_pixels, land_mask=land_mask)
            ksat_layers.append(dataset)

    ksat_xr = xr.DataArray(ksat_layers, dims=("soil_layer", "lat", "lon"), coords={"soil_layer": soil_layers, "lat": lat, "lon": lon},
                            attrs={"units": "mm/hr", "description": "Saturated Hydraulic Conductivity", "_FillValue":"-9999" })
    
    ksat_ds = xr.Dataset({"ksat": ksat_xr})
    ksat_ds.to_netcdf(output_path)

def ksat_input(file_path: str, lon_pixels: int, lat_pixels: int, land_mask: xr.DataArray = None) -> xr.DataArray:
    """
    Read and process a Ksat dataset from a .tif file, reprojects it, and applies a land mask if provided.

    Parameters:
    - file_path (str): Path to the Ksat .tif file.
    - lon_pixels (int): Number of longitude pixels in the target dataset.
    - lat_pixels (int): Number of latitude pixels in the target dataset.
    - land_mask (xr.DataArray, optional): Land mask to apply, defaults to None.

    Returns:
    - xr.DataArray: Processed Ksat dataset.
    """
    with rasterio.open(file_path) as dataset:
        # Read the file into a numpy array
        data = dataset.read(1)  # Read only the first band

        # Get metadata
        metadata = dataset.meta
        src_transform = dataset.transform
        src_crs = dataset.crs
        # Transform the no data into -9999
        nodata = dataset.nodata
        data[data == nodata] = -9999

        # Define the desired output bounds and shape in WGS84
        dst_bounds = (-180, -90, 180, 90)
        dst_shape = (lat_pixels, lon_pixels)  # Target shape (lat, lon)

        # Reproject the data to WGS84
        reprojected_data = reproject_to_wgs84(
            src_array=data,
            src_transform=src_transform,
            src_crs=src_crs,
            dst_bounds=dst_bounds,
            dst_shape=dst_shape
        )

        # Convert from log10 to normal values
        normal_values_cm_per_day = 10 ** reprojected_data[0]  # Access the first band

        # Convert from cm/h
        transformed_data = normal_values_cm_per_day / 24

        # Apply the land mask (if provided)
        if land_mask is not None:
            transformed_data = transformed_data.where(land_mask == 1, -9999)


        return transformed_data

def reproject_to_wgs84(
    src_array: np.ndarray, 
    src_transform: rasterio.Affine, 
    src_crs: rasterio.crs.CRS, 
    dst_bounds: tuple, 
    dst_shape: tuple
) -> tuple:
    """
    Reproject an array from a source CRS to WGS84 and resamples to the target shape.

    Parameters:
    - src_array (np.ndarray): Source array to be reprojected.
    - src_transform (rasterio.Affine): Affine transformation of the source array.
    - src_crs (rasterio.crs.CRS): Source Coordinate Reference System.
    - dst_bounds (tuple): Destination bounds (min_lon, min_lat, max_lon, max_lat).
    - dst_shape (tuple): Shape of the destination array (lat_pixels, lon_pixels).

    Returns:
    - tuple: Reprojected array and the corresponding destination transform.
    """

    dst_crs = rasterio.crs.CRS.from_string("+proj=longlat +datum=WGS84 +no_defs")
    
    # Define the destination transform directly based on the destination bounds and shape
    dst_transform = rasterio.transform.from_bounds(*dst_bounds, dst_shape[1], dst_shape[0])
    
    # Determine the size of the source array compared to the destination shape
    src_shape = src_array.shape[1:]  # Assuming src_array is of shape (band, height, width)
    
    # Initialize a destination array for reprojection
    src_array_resampled = np.empty(dst_shape, dtype=np.float32)

    if src_shape < dst_shape:
        # Generate the source coordinates from the source transform
        src_height, src_width = src_shape
        src_lon, src_lat = np.meshgrid(
            np.linspace(src_transform.c, src_transform.c + src_transform.a * src_width, src_width),
            np.linspace(src_transform.f + src_transform.e * src_height, src_transform.f, src_height)
        )
        
        # Convert the source array into an xarray DataArray
        src_xr = xr.DataArray(src_array[0], dims=["lat", "lon"], coords={"lat": src_lat[:, 0], "lon": src_lon[0, :]})
        
        # Perform interpolation to match the destination's lat/lon grid
        dst_lat = np.linspace(dst_bounds[1], dst_bounds[3], dst_shape[0])
        dst_lon = np.linspace(dst_bounds[0], dst_bounds[2], dst_shape[1])
        src_array_resampled = src_xr.interp(lat=dst_lat, lon=dst_lon).values
        
        # After interpolation, use the new destination transform
        src_transform_resampled = dst_transform

    elif src_shape > dst_shape:
        # If the original array is larger, reproject and resample
        reproject(
            source=src_array,
            destination=src_array_resampled,
            src_transform=src_transform,
            src_crs=src_crs,
            dst_transform=dst_transform,
            dst_crs=dst_crs,
            resampling=Resampling.bilinear  # Using bilinear resampling for better quality
        )
        src_transform_resampled = dst_transform
            # Convert the reprojected array to an xarray DataArray
        lon = np.linspace(-180, 180, dst_shape[1])
        lat = np.linspace(-90, 90, dst_shape[0])
        src_array_resampled = xr.DataArray(src_array_resampled, dims=("lat", "lon"), coords={"lat": lat, "lon": lon})

    else:
        # If the array is the same size, use the array and transform as is
        src_array_resampled = src_array
        lon = np.linspace(-180, 180, dst_shape[1])
        lat = np.linspace(-90, 90, dst_shape[0])
        src_array_resampled = xr.DataArray(src_array_resampled, dims=("lat", "lon"), coords={"lat": lat, "lon": lon})

        src_transform_resampled = src_transform

    # Return the resampled or reprojected array and the corresponding transform
    return src_array_resampled, src_transform_resampled


def load_land_mask(
    mask_shape: tuple, 
    transform: rasterio.Affine, 
    crs: str, 
    shapefile_path: str, 
    dst_bounds: tuple, 
    dst_shape: tuple
) -> xr.DataArray:
    """
    Load and rasterize a shapefile to create a land mask, then reprojects it to WGS84.

    Parameters:
    - mask_shape (tuple): Shape of the rasterized mask before reprojection.
    - transform (rasterio.Affine): Affine transformation of the rasterized mask.
    - crs (str): Coordinate Reference System of the shapefile.
    - shapefile_path (str): Path to the shapefile used to create the land mask.
    - dst_bounds (tuple): Destination bounds for reprojection.
    - dst_shape (tuple): Shape of the destination mask after reprojection.

    Returns:
    - xr.DataArray: Reprojected land mask.
    """
    # Load the world shapefile from the provided path
    world = gpd.read_file(shapefile_path)
    
    # Ensure the shapefile's CRS matches the desired CRS
    if world.crs != crs:
        world = world.to_crs(crs)
    
    # Rasterize the land mask ensuring it covers the entire globe
    mask = rasterize(
        [(geom, 1) for geom in world.geometry],
        out_shape=mask_shape,
        transform=transform,
        fill=0,  # Fill oceans with 0
        dtype=np.uint8
    )
    
    # Reproject the mask to WGS84 with the target shape
    dst_crs = rasterio.crs.CRS.from_string("+proj=longlat +datum=WGS84 +no_defs")
    dst_transform = rasterio.transform.from_bounds(*dst_bounds, dst_shape[1], dst_shape[0])

    reprojected_mask = np.empty(dst_shape, dtype=np.uint8)
    reproject(
        source=mask,
        destination=reprojected_mask,
        src_transform=transform,
        src_crs=crs,
        dst_transform=dst_transform,
        dst_crs=dst_crs,
        resampling=Resampling.nearest  # Use nearest-neighbor to keep mask values intact
    )

    # Convert the reprojected mask to an xarray DataArray
    lon = np.linspace(-180, 180, dst_shape[1])
    lat = np.linspace(-90, 90, dst_shape[0])
    reprojected_mask_xr = xr.DataArray(reprojected_mask, dims=("lat", "lon"), coords={"lat": lat, "lon": lon})

    return reprojected_mask_xr

if __name__ == "__main__":
    save_netcdf()