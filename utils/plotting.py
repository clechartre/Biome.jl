# Third-party
import cartopy.crs as ccrs
import cartopy.feature as cfeature
import matplotlib.pyplot as plt
import numpy as np
import netCDF4 as nc
import xarray as xr
from matplotlib.colors import ListedColormap


def plot(file_path: str):
    dataset = nc.Dataset(file_path, "r")
    lon = dataset.variables["lon"][:].filled(-9999)
    lat = dataset.variables["lat"][:].filled(-9999)
    biome = dataset.variables["biome"][:].filled(-9999)

    values = np.full((lat.size, lon.size), np.nan)

    # Create a custom color scale
    colors = plt.cm.get_cmap("tab20", 27).colors
    colors = np.array(colors)
    colors[26] = [0, 0, 1, 1]  # Set color for value 27 to blue
    custom_cmap = ListedColormap(colors)

    # Create the plot
    plt.figure(figsize=(10, 6))
    ax = plt.axes(projection=ccrs.PlateCarree())

    # Add features to the map
    ax.add_feature(cfeature.COASTLINE)
    ax.add_feature(cfeature.BORDERS, linestyle=":")
    ax.add_feature(cfeature.LAND)
    ax.add_feature(cfeature.OCEAN)
    ax.add_feature(cfeature.LAKES, alpha=0.5)
    ax.add_feature(cfeature.RIVERS)

    # Calculate the extent of the raster data
    extent = (min(lon), max(lon), min(lat), max(lat))

    # Plot the raster data
    img = ax.imshow(biome, origin='upper', extent=extent, transform=ccrs.PlateCarree(), cmap='viridis')

    # Add colorbar
    cbar = plt.colorbar(img, ax=ax, orientation='horizontal', pad=0.05, fraction=0.05)
    cbar.set_label('biome value')

    # Set labels and title
    plt.title("Biome Values by Longitude and Latitude")
    plt.xlabel("Longitude")
    plt.ylabel("Latitude")
    plt.savefig(
        "/Users/capucine/Documents/PhD/models/BIOME4/code/BIOME4Py/biome_distribution.png",
        bbox_inches="tight",
    )
    plt.show()



def plot_ds_on_map(ds, var_name, month=None):
    fig, ax = plt.subplots(subplot_kw={'projection': ccrs.PlateCarree()})
    if var_name == 'npp':
        ds[var_name].sel(months=month).plot(ax=ax, transform=ccrs.PlateCarree(), cmap='viridis')
    else:
        ds[var_name].plot(ax=ax, transform=ccrs.PlateCarree(), cmap='viridis')
    ax.coastlines()
    plt.title(f"{var_name.capitalize()} for Month {month}")
    plt.show()

if __name__ == "__main__":
    plot(
        file_path="/Users/capucine/Documents/PhD/models/BIOME4/code/BIOME4Py/output_julia.nc"
    )
    # ds = xr.open_dataset('/Users/capucine/Documents/PhD/models/BIOME4/code/BIOME4Py/output/output_julia.nc',  mask_and_scale=True)
    # plot_ds_on_map(ds, 'biome', 1)