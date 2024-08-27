"""Using tif files for the ksat dataset.
Gupta, S., Lehmann, P., Bonetti, S., Papritz, A., and Or, D., (2020):
Global prediction of soil saturated hydraulic conductivity using random forest in a Covariate-based Geo Transfer Functions (CoGTF) framework.
Journal of Advances in Modeling Earth Systems, 13(4), e2020MS002242. https://agupubs.onlinelibrary.wiley.com/doi/full/10.1029/2020MS002242"""
# Dataset source is: https://zenodo.org/records/3935359

# Open the .tif file
from matplotlib import pyplot as plt
import numpy as np
import xarray as xr
import rasterio
from rasterio.warp import reproject, Resampling
import geopandas as gpd
from rasterio.features import rasterize
from rasterio.transform import from_bounds


def ksat_input(file_path:str, land_mask = None):

    with rasterio.open(file_path) as dataset:
        # Read the file into a numpy array
        data = dataset.read()

        # Get metadata
        metadata = dataset.meta
        src_transform = dataset.transform
        src_crs = dataset.crs
        # Transform the no data into -9999
        nodata = dataset.nodata
        data[data == nodata] = -9999

        # Define the desired output bounds and shape in WGS84
        dst_bounds = (-180, -90, 180, 90)
        dst_shape = (360, 720)  # Target shape (lat, lon)

        # Reproject the data to WGS84
        reprojected_data, dst_transform = reproject_to_wgs84(
            src_array=data,
            src_transform=src_transform,
            src_crs=src_crs,
            dst_bounds=dst_bounds,
            dst_shape=dst_shape
        )

        # Convert from log10 to normal values
        normal_values_cm_per_day = 10 ** reprojected_data

        # Convert from cm/h
        transformed_data = normal_values_cm_per_day / 24

        # Now we need to reshape it into (360,720) lat, lon 
        reshaped_data = reshape_to_target(transformed_data, (360, 720))

        # Apply the land mask (if provided)
        if land_mask is not None:
            reshaped_data[land_mask == 0] = -9999

        # Plot it 
        plot_raster(reshaped_data, 'Transformed and reshaped data')

        return reshaped_data


def save_netcdf(output_path: str, land_mask = None):
        # Save the new values as a .nc dataset with metadata
        lon = np.linspace(-180, 180, 720)
        lat = np.linspace(-90, 90, 360)
        soil_layers = ['0', '30']
        ksat_layers = []

        for depth in soil_layers: 
             input_path = f'/Users/capucine/Documents/PhD/models/BIOME4/code/BIOME4Py/data/downloaded_data/Global_Ksat_1Km_s{depth}....{depth}cm_v1.0.tif'
             dataset = ksat_input(input_path, land_mask=land_mask)
             ksat_layers.append(dataset)
    
        ksat_xr = xr.DataArray(ksat_layers, dims=("soil_layer", "lat", "lon"), coords={"soil_layer": soil_layers, "lat": lat, "lon": lon},
                                attrs={"units": "mm/hr", "description": "Saturated Hydraulic Conductivity", "_FillValue":"-9999" })
        
        ksat_ds = xr.Dataset({"ksat": ksat_xr})
        ksat_ds.to_netcdf(output_path)

def reshape_to_target(data, target_shape):
    original_lat, original_lon = data.shape
    target_lat, target_lon = target_shape
    
    # Create latitude and longitude ranges for the data
    lat = np.linspace(-90, 90, original_lat)
    lon = np.linspace(-180, 180, original_lon)
    
    # Convert the numpy array to an xarray DataArray
    data_xr = xr.DataArray(data, dims=("lat", "lon"), coords={"lat": lat, "lon": lon})

    # Calculate the original grid resolution
    input_grid_resolution_lat = 180.0 / original_lat
    input_grid_resolution_lon = 360.0 / original_lon

    # Desired output resolution
    output_grid_resolution_lat = 180.0 / target_lat
    output_grid_resolution_lon = 360.0 / target_lon

    # Calculate the weights for coarsening
    weight_lat = int(np.ceil(output_grid_resolution_lat / input_grid_resolution_lat))
    weight_lon = int(np.ceil(output_grid_resolution_lon / input_grid_resolution_lon))

    # Coarsen the data using xarray's coarsen method
    reshaped_data_xr = data_xr.coarsen(lat=weight_lat, lon=weight_lon, boundary="pad", coord_func="mean").mean()

    # Interpolate to the target shape
    target_latitudes = np.linspace(-90, 90, target_lat)
    target_longitudes = np.linspace(-180, 180, target_lon)
    reshaped_data_xr = reshaped_data_xr.interp(lat=target_latitudes, lon=target_longitudes)

    # Identify regions outside the bounds of the original data and set them to NaN
    lat_min, lat_max = lat.min(), lat.max()
    out_of_bounds_mask = (reshaped_data_xr.lat < lat_min) | (reshaped_data_xr.lat > lat_max)
    
    # Apply the out_of_bounds_mask to set these regions to NaN
    reshaped_data_xr = reshaped_data_xr.where(~out_of_bounds_mask, np.nan)

    # Convert back to numpy array and handle missing values
    reshaped_data = reshaped_data_xr.values
    reshaped_data[np.isnan(reshaped_data)] = -9999  # Set missing values as -9999 or another designated missing value

    return reshaped_data

# Function to reproject raster data
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

# Function to plot Ksat values on map
def plot_raster(data, title):
    plt.figure(figsize=(10, 5))
    plt.imshow(data, cmap='viridis', vmin=0, vmax=400)
    plt.colorbar(label='Values')
    plt.title(title)
    plt.xlabel('Longitude Index')
    plt.ylabel('Latitude Index')
    plt.show()

def load_land_mask(mask_shape, transform, crs, shapefile_path):
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
    shapefile_path = "data/downloaded_data/countries_shapefile/ne_110m_admin_0_countries.shp"
    land_mask = load_land_mask(
        mask_shape=(360, 720),
        transform=from_bounds(-180, -90, 180, 90, 720, 360),
        crs="EPSG:4326",
        shapefile_path=shapefile_path
    )
    save_netcdf("data/generated_data/ksat_layers.nc", land_mask=land_mask)