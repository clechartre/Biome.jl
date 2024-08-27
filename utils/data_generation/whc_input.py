"""Script to generate the WHC values. 
Water Holding Capacity (WHC) = (θFC − θWP)*Depth."""

import xarray as xr
import numpy as np
import rasterio
from rasterio.warp import reproject, Resampling
from rasterio.transform import from_bounds

from utils.data_generation.ksat_input import load_land_mask

def calculate_whc_for_depths(sandfile_path: str, clayfile_path: str, wc_files: dict, land_mask=None):
    # Load the field capacity dataset (remains the same across depths)
    field_capacity, field_capacity_transform, field_capacity_crs = assign_fc(sandfile_path, clayfile_path, land_mask)

    whc_layers = []

    for depth, files in wc_files.items():
        wc_10_file, wc_33_file, wc_1500_file = files

        dst_bounds = (-180, -90, 180, 90)
        dst_shape = (360, 720)

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


def process_and_save_whc_netcdf(sandfile_path, clayfile_path, wc_files, output_path, land_mask):
    whc_layers = calculate_whc_for_depths(sandfile_path, clayfile_path, wc_files, land_mask)

    # Convert the WHC layers to a stacked array
    whc_layers = np.stack(whc_layers, axis=0)

    # Create coordinates and DataArray
    lon = np.linspace(-180, 180, 720)
    lat = np.linspace(-90, 90, 360)
    soil_layer = list(wc_files.keys())

    whc_xr = xr.DataArray(whc_layers, dims=("soil_layer", "lat", "lon"),
                          coords={"soil_layer": soil_layer, "lat": lat, "lon": lon},
                          attrs={"units": "mm/mm", "description": "Water Holding Capacity", "_FillValue": "-9999"})

    whc_ds = xr.Dataset({"whc": whc_xr})
    whc_ds.to_netcdf(output_path)


def assign_fc(sandfile_path: str, clayfile_path: str, land_mask=None):
    # Open the sand and clay files
    with rasterio.open(clayfile_path) as src:
        clay = src.read(1)
        meta = src.meta
        nodata = src.nodata
        transform = src.transform
        crs = src.crs
        clay[clay == nodata] = -9999
        clay_reprojected, _ = reproject_to_wgs84(clay, transform, crs, (-180, -90, 180, 90), (360, 720))
    
    with rasterio.open(sandfile_path) as src:
        sand = src.read(1)
        nodata = src.nodata
        transform = src.transform
        crs = src.crs
        sand[sand == nodata] = -9999
        sand_reprojected, _ = reproject_to_wgs84(sand, transform, crs, (-180, -90, 180, 90), (360, 720))

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


def open_and_reproject(file_path, dst_bounds, dst_shape):
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


def reproject_to_wgs84(src_array, src_transform, src_crs, dst_bounds, dst_shape):
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

if __name__ == "__main__":
    shapefile_path = "data/downloaded_data/countries_shapefile/ne_110m_admin_0_countries.shp"
    land_mask = load_land_mask(
        mask_shape=(360, 720),
        transform=from_bounds(-180, -90, 180, 90, 720, 360),
        crs="EPSG:4326",
        shapefile_path=shapefile_path
    )
    wc_files = {
        # We're using 10 and 150 as intermediate values in mm to use 
        # in our multiplication with depth to calculate WHC
        '10': (
            "data/downloaded_data/sol_watercontent_10KPa_0-5cm_mean.tif",
            "data/downloaded_data/sol_watercontent_33Kpa_0-5cm_mean.tif",
            "data/downloaded_data/sol_watercontent_1500Kpa_0-5cm_mean.tif"
        ),
        '150': (
            "data/downloaded_data/sol_watercontent_10Kpa_15-30cm_mean.tif",
            "data/downloaded_data/sol_watercontent_33Kpa_15-30cm_mean.tif",
            "data/downloaded_data/sol_watercontent_1500Kpa_15-30cm_mean.tif"
        ),
        # Add more depth layers as needed
        # Depth here are expressed in mm with one reference
    }

    process_and_save_whc_netcdf(
        sandfile_path="data/downloaded_data/sand_0-5cm_mean_1000.tif",
        clayfile_path="data/downloaded_data/clay_0-5cm_mean_1000.tif",
        wc_files=wc_files,
        output_path="data/generated_data/whc_layers.nc",
        land_mask=land_mask
    )
