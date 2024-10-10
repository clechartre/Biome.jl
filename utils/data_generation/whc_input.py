"""Script to generate Water Holding Capacity (WHC) values.
WHC = (θFC − θWP) * Depth, where θFC is the water content at field capacity 
and θWP is the water content at wilting point.
"""

import click
import geopandas as gpd
import numpy as np
import rasterio
from rasterio.warp import reproject, Resampling
from rasterio.transform import from_bounds
from rasterio.features import rasterize
import xarray as xr

@click.command()
@click.option('--output_path', type=str, required=True, help='Output file path')
@click.option('--resolution', type=click.Choice(['low', 'high']), required=True, help='Resolution to download data at, low = 55km, high = 1km ')
def main(output_path: str, resolution: str) -> None:
    """
    Main function to calculate WHC values and save them to a NetCDF file.

    Parameters:
    output_path (str): The file path where the output NetCDF file will be saved.
    resolution (str): Resolution of the data to be used ('low' or 'high').
    """

    if resolution == "low":
        lon_pixels = 720
        lat_pixels = 360
    elif resolution == "high":
        lon_pixels = 43200
        lat_pixels = 20880

    shapefile_path = "/home/lechartr/BIOME4Py/data/downloaded_data/countries_shapefile/ne_110m_admin_0_countries.shp"
    land_mask = load_land_mask(
        mask_shape=(lat_pixels, lon_pixels),
        transform=from_bounds(-180, -90, 180, 90, lon_pixels, lat_pixels),
        crs="EPSG:4326",
        shapefile_path=shapefile_path
    )

    # Initialize files
    wc_files = {
        # We're using 1 and 15 values to use 
        # in our multiplication with depth to calculate WHC
        '1': (
            "/home/lechartr/BIOME4Py/data/downloaded_data/sol_watercontent_10KPa_0-5cm_mean.tif",
            "/home/lechartr/BIOME4Py/data/downloaded_data/sol_watercontent_33KPa_0-5cm_mean.tif",
            "/home/lechartr/BIOME4Py/data/downloaded_data/sol_watercontent_1500KPa_0-5cm_mean.tif"
        ),
        '15': (
            "/home/lechartr/BIOME4Py/data/downloaded_data/sol_watercontent_10KPa_15-30cm_mean.tif",
            "/home/lechartr/BIOME4Py/data/downloaded_data/sol_watercontent_33KPa_15-30cm_mean.tif",
            "/home/lechartr/BIOME4Py/data/downloaded_data/sol_watercontent_1500KPa_15-30cm_mean.tif"
        ),
        # Add more depth layers as needed
        # Depth here are expressed in mm with one reference
    }

    sandfile_path="/home/lechartr/BIOME4Py/data/downloaded_data/sand_0-5cm_mean_1000.tif"
    clayfile_path="/home/lechartr/BIOME4Py/data/downloaded_data/clay_0-5cm_mean_1000.tif"


    whc_layers = calculate_whc_for_depths(sandfile_path, clayfile_path, wc_files, lon_pixels, lat_pixels, land_mask)

    # Convert the WHC layers to a stacked array
    whc_layers = np.stack(whc_layers, axis=0)

    # Create coordinates and DataArray
    lon = np.linspace(-180, 180, lon_pixels)
    lat = np.linspace(-90, 90, lat_pixels)
    soil_layer = list(wc_files.keys())

    whc_xr = xr.DataArray(whc_layers, dims=("soil_layer", "lat", "lon"),
                          coords={"soil_layer": soil_layer, "lat": lat, "lon": lon},
                          attrs={"units": "mm/mm", "description": "Water Holding Capacity", "_FillValue": "-9999"})

    whc_ds = xr.Dataset({"whc": whc_xr})
    whc_ds.to_netcdf(output_path)

def calculate_whc_for_depths(
    sandfile_path: str,
    clayfile_path: str,
    wc_files: dict,
    lon_pixels: int,
    lat_pixels: int,
    land_mask: np.ndarray = None
) -> list:
    """
    Calculate WHC for different soil depths based on water content at field capacity and wilting point.

    Parameters:
    sandfile_path (str): File path to the sand proportion raster.
    clayfile_path (str): File path to the clay proportion raster.
    wc_files (dict): Dictionary containing paths to water content files for each soil layer.
    lon_pixels (int): Number of longitude pixels.
    lat_pixels (int): Number of latitude pixels.
    land_mask (np.ndarray): Land mask array.

    Returns:
    list: A list of WHC layers, one for each soil depth.
    """
    # Load the field capacity dataset (remains the same across depths)
    field_capacity, field_capacity_transform, field_capacity_crs = assign_fc(sandfile_path, clayfile_path, lon_pixels, lat_pixels, land_mask)

    whc_layers = []

    for depth, files in wc_files.items():
        wc_10_file, wc_33_file, wc_1500_file = files

        dst_bounds = (-180, -90, 180, 90)
        dst_shape = (lat_pixels, lon_pixels)

        # Reproject each dataset to the same grid
        wc_10_reprojected, wc_10_transform = open_and_reproject(wc_10_file, dst_bounds, dst_shape)
        wc_33_reprojected, wc_33_transform = open_and_reproject(wc_33_file, dst_bounds, dst_shape)
        wc_1500_reprojected, wc_1500_transform = open_and_reproject(wc_1500_file, dst_bounds, dst_shape)

        # Make sure all datasets have the same dimensions
        if field_capacity.shape != wc_10_reprojected.shape or wc_10_reprojected.shape != wc_33_reprojected.shape or \
                wc_33_reprojected.shape != wc_1500_reprojected.shape:
            raise ValueError("Input rasters must have the same dimensions")

        # Get the soil moisture content at field capacity (choose between wc_10 and wc_33)
        water_content = np.full(field_capacity.shape, -9999, dtype=np.float32)
        water_content[field_capacity == 10] = wc_10_reprojected[field_capacity == 10]
        water_content[field_capacity == 33] = wc_33_reprojected[field_capacity == 33]

        # Water Holding Capacity (WHC) = (θFC − θWP)*Depth
        whc = np.full(field_capacity.shape, -9999, dtype=np.float32)
        valid_mask = water_content != -9999
        whc[valid_mask] = water_content[valid_mask] - wc_1500_reprojected[valid_mask]

        # Multiply by depth of interest 
        whc[valid_mask] = whc[valid_mask] * int(depth)

        whc_layers.append(whc)

    return whc_layers


def assign_fc(
    sandfile_path: str,
    clayfile_path: str,
    lon_pixels: int,
    lat_pixels: int,
    land_mask: np.ndarray = None
) -> tuple:
    """
    Assign field capacity values based on sand and clay proportions.

    Parameters:
    sandfile_path (str): File path to the sand proportion raster.
    clayfile_path (str): File path to the clay proportion raster.
    land_mask (np.ndarray): Land mask array.

    Returns:
    tuple: A tuple containing the field capacity array, its transform, and its CRS.
    """
    # Open the sand and clay files
    with rasterio.open(clayfile_path) as src:
        clay = src.read(1)
        meta = src.meta
        nodata = src.nodata
        transform = src.transform
        crs = src.crs
        clay[clay == nodata] = -9999
        clay_reprojected, _ = reproject_to_wgs84(clay, transform, crs, (-180, -90, 180, 90), (lat_pixels, lon_pixels))
    
    with rasterio.open(sandfile_path) as src:
        sand = src.read(1)
        nodata = src.nodata
        transform = src.transform
        crs = src.crs
        sand[sand == nodata] = -9999
        sand_reprojected, _ = reproject_to_wgs84(sand, transform, crs, (-180, -90, 180, 90), (lat_pixels, lon_pixels))

    if clay_reprojected.shape != sand_reprojected.shape:
        raise ValueError("Input rasters must have the same dimensions")

    total_texture = sand_reprojected + clay_reprojected
    sand_proportion = np.divide(sand_reprojected, total_texture, where=(total_texture != 0), out=np.zeros_like(sand_reprojected, dtype=float))
    clay_proportion = np.divide(clay_reprojected, total_texture, where=(total_texture != 0), out=np.zeros_like(clay_reprojected, dtype=float))
    
    field_capacity = np.full_like(sand_reprojected, -9999, dtype=float)

    sandy_mask = sand_proportion >= 0.6
    clayey_mask = clay_proportion >= 0.4
    
    field_capacity[sandy_mask] = 10
    field_capacity[clayey_mask] = 33
    
    mixed_mask = ~sandy_mask & ~clayey_mask & (total_texture != 0)
    field_capacity[mixed_mask] = 10

    # Apply the land mask to assign 10 to any -9999 values within land areas
    land_masked_area = (land_mask == 1) & (field_capacity == -9999)
    field_capacity[land_masked_area] = 10

    return field_capacity, transform, crs


def open_and_reproject(
    file_path: str,
    dst_bounds: tuple,
    dst_shape: tuple
) -> tuple:
    """
    Open and reproject a raster file to WGS84.

    Parameters:
    file_path (str): Path to the raster file.
    dst_bounds (tuple): The destination bounds (min_lon, min_lat, max_lon, max_lat).
    dst_shape (tuple): The shape of the output array (lat_pixels, lon_pixels).

    Returns:
    tuple: A tuple containing the reprojected array and its transform.
    """
    with rasterio.open(file_path) as src:
        src_array = src.read(1)
        nodata = src.nodata
        src_array[src_array == nodata] = -9999
        src_transform = src.transform
        src_crs = src.crs

        # Reproject to WGS84
        reprojected_array, reprojected_transform = reproject_to_wgs84(
            src_array, src_transform, src_crs, dst_bounds, dst_shape
        )

    return reprojected_array, reprojected_transform


def reproject_to_wgs84(
    src_array: np.ndarray,
    src_transform: rasterio.transform.Affine,
    src_crs: rasterio.crs.CRS,
    dst_bounds: tuple,
    dst_shape: tuple
) -> tuple:
    """
    Reproject an array to WGS84 coordinates.

    Parameters:
    src_array (np.ndarray): Input array to be reprojected.
    src_transform (rasterio.transform.Affine): Source array's transform.
    src_crs (rasterio.crs.CRS): Source array's coordinate reference system (CRS).
    dst_bounds (tuple): Destination bounds (min_lon, min_lat, max_lon, max_lat).
    dst_shape (tuple): Shape of the destination array (lat_pixels, lon_pixels).

    Returns:
    tuple: The reprojected array and its new transform.
    """
    dst_crs = rasterio.crs.CRS.from_string("+proj=longlat +datum=WGS84 +no_defs")
    
    # Define the destination transform directly
    dst_transform = rasterio.transform.from_bounds(*dst_bounds, dst_shape[1], dst_shape[0])
    dst_array = np.empty(dst_shape, dtype=np.float32)
    
    reproject(
        source=src_array,
        destination=dst_array,
        src_transform=src_transform,
        src_crs=src_crs,
        dst_transform=dst_transform,
        dst_crs=dst_crs,
        resampling=Resampling.nearest
    )

    return dst_array, dst_transform


def load_land_mask(
    mask_shape: tuple,
    transform: rasterio.transform.Affine,
    crs: str,
    shapefile_path: str
) -> np.ndarray:
    """
    Load and rasterize a land mask from a shapefile.

    Parameters:
    mask_shape (tuple): The shape of the output land mask array.
    transform (rasterio.transform.Affine): The affine transform to apply.
    crs (str): The CRS of the land mask.
    shapefile_path (str): Path to the shapefile containing land geometries.

    Returns:
    np.nd
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
    
    return mask

if __name__ == "__main__":
    main()