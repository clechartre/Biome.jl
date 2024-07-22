# Third-party
import cartopy.crs as ccrs
import cartopy.feature as cfeature
import matplotlib.pyplot as plt
import numpy as np
import xarray as xr
from matplotlib.colors import ListedColormap


def plot(file_path: str):
    # Open the dataset using xarray
    dataset = xr.open_dataset(file_path)

    # Select all latitude indices
    lat_indices = np.arange(len(dataset.coords["lat"]))

    # Select the corresponding biome data for all latitudes
    biome_subset = dataset["gdom"].isel(lat=lat_indices)
    biome_subset = biome_subset.values.T

    # Extract the coordinates and values
    lon = dataset.coords["lon"].values
    lat = dataset.coords["lat"].values
    values = np.full((lat.size, lon.size), np.nan)

    # Fill the values for all latitudes
    for i, lat_idx in enumerate(lat_indices):
        values[lat_idx, :] = biome_subset[i, :]

    # Mask the values where we don't have data
    masked_values = np.ma.masked_where(np.isnan(values), values)

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

    # Set extent of the map
    ax.set_extent([lon.min(), lon.max(), lat.min(), lat.max()])

    # Plot the data using pcolormesh
    lon_grid, lat_grid = np.meshgrid(lon, lat)
    pcm = ax.pcolormesh(
        lon_grid,
        lat_grid,
        masked_values,
        cmap=custom_cmap,
        transform=ccrs.PlateCarree(),
        shading="auto",
    )

    # Add colorbar
    cbar = plt.colorbar(pcm, label="Values", ticks=np.arange(1, 28))
    cbar.ax.set_yticklabels(np.arange(1, 28))

    # Set labels and title
    plt.title("Biome Values by Longitude and Latitude")
    plt.xlabel("Longitude")
    plt.ylabel("Latitude")
    plt.savefig(
        "/Users/capucine/Documents/PhD/models/BIOME4/code/BIOME4Py/biome_distribution.png",
        bbox_inches="tight",
    )
    plt.show()


if __name__ == "__main__":
    plot(
        file_path="/Users/capucine/Documents/PhD/models/BIOME4/code/BIOME4Py/outputfilefull.nc"
    )
