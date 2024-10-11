import numpy as np
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap
import netCDF4 as nc

def main():
    filename = "/home/lechartr/BIOME4Py/output_2005-1k_chunky.nc"
    output_file = "/home/lechartr/BIOME4Py/output_2005-1k_biggerchunks.png"

    # Define the biome names and their corresponding index
    biomename = [
        "   ",
        "Tropical evergreen forest",
        "Tropical semi-deciduous forest",
        "Tropical deciduous forest/woodland",
        "Temperate deciduous forest",
        "Temperate conifer forest",
        "Warm mixed forest",
        "Cool mixed forest",
        "Cool conifer forest",
        "Cold mixed forest",
        "Evergreen taiga/montane forest",
        "Deciduous taiga/montane forest",
        "Tropical savanna",
        "Tropical xerophytic shrubland",
        "Temperate xerophytic shrubland",
        "Temperate sclerophyll woodland",
        "Temperate broadleaved savanna",
        "Open conifer woodland",
        "Boreal parkland",
        "Tropical grassland",
        "Temperate grassland",
        "Desert",
        "Steppe tundra",
        "Shrub tundra",
        "Dwarf shrub tundra",
        "Prostrate shrub tundra",
        "Cushion-forbs, lichen and moss",
        "Barren",
        "Land ice"
    ]

    # Define the color map with a transparent color for -9999
    cmap = ListedColormap([
        (0, 0, 0, 0),            # Transparent for -9999
        (0.0, 0.6, 0.0),         # Tropical evergreen forest
        (0.3, 0.8, 0.4),         # Tropical semi-deciduous forest
        (0.8, 0.4, 0.2),         # Tropical deciduous forest/woodland
        (0.0, 0.6, 0.1),         # Temperate deciduous forest
        (0.0, 0.5, 0.2),         # Temperate conifer forest
        (0.3, 0.7, 0.3),         # Warm mixed forest
        (0.1, 0.7, 0.9),         # Cool mixed forest
        (0.0, 0.5, 0.5),         # Cool conifer forest
        (0.4, 0.7, 0.6),         # Cold mixed forest
        (0.0, 0.7, 0.7),         # Evergreen taiga/montane forest
        (0.0, 0.4, 0.7),         # Deciduous taiga/montane forest
        (0.9, 0.8, 0.2),         # Tropical savanna
        (0.8, 0.7, 0.4),         # Tropical xerophytic shrubland
        (0.9, 0.7, 0.6),         # Temperate xerophytic shrubland
        (0.7, 0.4, 0.3),         # Temperate sclerophyll woodland
        (0.5, 0.9, 0.3),         # Temperate broadleaved savanna
        (0.8, 0.6, 0.1),         # Open conifer woodland
        (0.5, 0.6, 0.3),         # Boreal parkland
        (0.9, 0.8, 0.5),         # Tropical grassland
        (0.8, 0.6, 0.6),         # Temperate grassland
        (1.0, 0.8, 0.7),         # Desert
        (0.7, 0.7, 0.9),         # Steppe tundra
        (0.6, 0.5, 0.8),         # Shrub tundra
        (0.5, 0.4, 0.7),         # Dwarf shrub tundra
        (0.4, 0.3, 0.6),         # Prostrate shrub tundra
        (0.3, 0.2, 0.5),         # Cushion-forbs, lichen and moss
        (0.9, 0.9, 0.9),         # Barren
        (1.0, 1.0, 1.0)          # Land ice
    ])

    # Load the netCDF data
    dataset = nc.Dataset(filename)
    biome_data = dataset.variables['biome'][:]

    # Replace -9999 with 0 for visualization purposes
    biome_data = np.where(biome_data == -9999, 0, biome_data)

    # Plot the biome data
    fig, ax = plt.subplots(figsize=(12, 10))
    cax = ax.imshow(biome_data, cmap=cmap, vmin=0, vmax=28)
    ax.set_title("Biome Distribution")
    ax.set_xlabel("Longitude")
    ax.set_ylabel("Latitude")

    # Create colorbar with custom ticks and labels
    cbar = fig.colorbar(cax, ticks=np.arange(0.5, 28.5, 1), boundaries=np.arange(0, 29, 1))
    cbar.ax.set_yticklabels(biomename[1:], fontsize=8)

    # Save the final plot as a PNG file
    plt.savefig(output_file, dpi=300)

if __name__ == "__main__":
    main()
