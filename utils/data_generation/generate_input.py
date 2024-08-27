import os
import requests
import xarray as xr
import numpy as np
from rasterio.transform import from_bounds
import rasterio

from utils.data_generation.ksat_input import load_land_mask
from utils.data_generation.whc_input import reproject_to_wgs84

def download_file(url, filename):
    response = requests.get(url)
    if response.status_code == 200:
        with open(filename, 'wb') as f:
            f.write(response.content)
        print(f"Downloaded {filename}")
    else:
        print(f"Failed to download {filename} from {url}")


# Modified function to resample data and reshape to WGS84
def resample_to_mean(input_cog_path, var, land_mask, target_resolution=0.5):
    with rasterio.open(input_cog_path) as dataset:
        data = dataset.read(1)  # Read the first band
        src_transform = dataset.transform
        src_crs = dataset.crs

        # Reproject to WGS84 with target bounds and shape
        dst_bounds = (-180, -90, 180, 90)
        dst_shape = (360, 720)

        reprojected_data, dst_transform = reproject_to_wgs84(
            src_array=data,
            src_transform=src_transform,
            src_crs=src_crs,
            dst_bounds=dst_bounds,
            dst_shape=dst_shape
        )

        # Apply the land mask to the data
        if land_mask is not None:
            reprojected_data[land_mask == 0] = -9999

    # Convert reprojected data to DataArray
    lon = np.linspace(-180, 180, dst_shape[1])
    lat = np.linspace(-90, 90, dst_shape[0])
    da = xr.DataArray(reprojected_data, dims=("lat", "lon"), coords={"lat": lat, "lon": lon})

    return da

def process_and_save_variable(var, year, land_mask, target_width=720, target_height=360):
    base_url = "https://os.zhdk.cloud.switch.ch/envicloud/chelsa/chelsa_V2/GLOBAL/monthly"
    data_arrays = []

    for month in range(1, 13):
        # Download corresponding file
        month_str = f"{month:02d}"
        filename = f"CHELSA_{var}_{month_str}_{year}_V.2.1.tif"
        url = f"{base_url}/{var}/{filename}"
        download_file(url, filename)

        # Reshape 
        da = resample_to_mean(filename, var, land_mask)
        data_arrays.append(da)
        os.remove(filename)

    lon = np.linspace(-180 + 0.25, 180 - 0.25, target_width)
    lat = np.linspace(-90 + 0.25, 90 - 0.25, target_height)
    ds = xr.Dataset()

    var_map = {
        'tas': ('temp', "monthly mean temperature", "degC", 0.1, -273.15),
        'tasmin': ('tmin', "annual minimum temperature", "degC", 0.1, -273.15),
        'pr': ('prec', "monthly total precipitation", "mm", 0.01, 0),
        'clt': ('sun', "total cloud cover", "percent", 0.01, 0)
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
            "missing_value": -9999,
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
            "missing_value": -9999
        }

    ds.lon.attrs = {
        "long_name": "longitude",
        "units": "degrees_east",
        "missing_value": -9999
    }

    ds.lat.attrs = {
        "long_name": "latitude",
        "units": "degrees_north",
        "missing_value": -9999
    }

    output_nc_path = f"data/generated_data/{var_name}_{year}.nc"
    ds.to_netcdf(output_nc_path)
    print(f"Aggregated data for {var_name} saved to {output_nc_path}")

if __name__ == "__main__":
    shapefile_path = "data/downloaded_data/countries_shapefile/ne_110m_admin_0_countries.shp"
    land_mask = load_land_mask(
        mask_shape=(360, 720),
        transform=from_bounds(-180, -90, 180, 90, 720, 360),
        crs="EPSG:4326",
        shapefile_path=shapefile_path
    )
    
    variables = ['pr', 'tas', 'tasmin', 'clt']
    year = 2013
    for var in variables:
        process_and_save_variable(var, year, land_mask)
