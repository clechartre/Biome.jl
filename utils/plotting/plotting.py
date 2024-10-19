import numpy as np
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap
import netCDF4 as nc

def main():
    filename = "/home/lechartr/BIOME4Py/output_whc_jed.nc"
    output_file = "/home/lechartr/BIOME4Py/output_whc_jed.png"

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
        (0.0, 0.5, 0.0),         # Tropical evergreen forest - Green
        (0.2, 0.7, 0.3),         # Tropical semi-deciduous forest - Light Green
        (0.9, 0.3, 0.1),         # Tropical deciduous forest/woodland - Orange-Red
        (0.1, 0.6, 0.1),         # Temperate deciduous forest - Dark Green
        (0.0, 0.4, 0.2),         # Temperate conifer forest - Dark Cyan
        (0.6, 0.7, 0.2),         # Warm mixed forest - Olive
        (0.0, 0.5, 0.9),         # Cool mixed forest - Blue
        (0.1, 0.3, 0.5),         # Cool conifer forest - Dark Blue
        (0.4, 0.8, 0.8),         # Cold mixed forest - Light Cyan
        (0.1, 0.8, 0.7),         # Evergreen taiga/montane forest - Turquoise
        (0.2, 0.4, 0.7),         # Deciduous taiga/montane forest - Dark Blue
        (1.0, 0.8, 0.1),         # Tropical savanna - Bright Yellow
        (0.9, 0.6, 0.3),         # Tropical xerophytic shrubland - Tan
        (0.8, 0.6, 0.6),         # Temperate xerophytic shrubland - Pale Pink
        (0.7, 0.5, 0.3),         # Temperate sclerophyll woodland - Brown
        (0.4, 0.9, 0.2),         # Temperate broadleaved savanna - Lime Green
        (0.9, 0.7, 0.1),         # Open conifer woodland - Gold
        (0.6, 0.6, 0.3),         # Boreal parkland - Khaki
        (0.9, 0.9, 0.5),         # Tropical grassland - Light Yellow
        (0.7, 0.7, 0.4),         # Temperate grassland - Pale Yellow-Green
        (1.0, 0.7, 0.5),         # Desert - Sand
        (0.5, 0.6, 0.8),         # Steppe tundra - Light Purple
        (0.7, 0.5, 0.9),         # Shrub tundra - Violet
        (0.6, 0.4, 0.7),         # Dwarf shrub tundra - Dark Violet
        (0.5, 0.3, 0.6),         # Prostrate shrub tundra - Deep Purple
        (0.6, 0.2, 0.4),         # Cushion-forbs, lichen and moss - Burgundy
        (0.8, 0.8, 0.8),         # Barren - Light Grey
        (1.0, 1.0, 1.0)          # Land ice - White
    ])


    # Load the netCDF data
    dataset = nc.Dataset(filename)
    biome_data = dataset.variables['biome'][:]
    biome_data = np.flipud(biome_data)

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