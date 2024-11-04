import ArchGDAL
using NCDatasets
using Rasters, Plots, Colors

function plot_biome_distribution(filename::String, output_file::String)
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
    cmap = [
        RGBA(0, 0, 0, 0),          # Transparent for -9999
        RGB(0.0, 0.3, 0.0),        # Tropical evergreen forest - Rich Dark Green
        RGB(0.2, 0.8, 0.2),        # Tropical semi-deciduous forest - Vivid Light Green
        RGB(0.9, 0.3, 0.1),        # Tropical deciduous forest/woodland - Orange-Red
        RGB(0.1, 0.5, 0.1),        # Temperate deciduous forest - Forest Green
        RGB(0.0, 0.4, 0.3),        # Temperate conifer forest - Muted Teal
        RGB(0.5, 0.6, 0.2),        # Warm mixed forest - Olive Green
        RGB(0.0, 0.5, 0.9),        # Cool mixed forest - Bright Blue
        RGB(0.1, 0.3, 0.6),        # Cool conifer forest - Darker Blue
        RGB(0.3, 0.8, 0.8),        # Cold mixed forest - Soft Cyan
        RGB(0.0, 0.7, 0.5),        # Evergreen taiga/montane forest - Medium Turquoise
        RGB(0.1, 0.4, 0.7),        # Deciduous taiga/montane forest - Slate Blue
        RGB(1.0, 0.8, 0.1),        # Tropical savanna - Bright Yellow
        RGB(0.9, 0.6, 0.3),        # Tropical xerophytic shrubland - Tan
        RGB(0.8, 0.6, 0.6),        # Temperate xerophytic shrubland - Pale Pink
        RGB(0.7, 0.5, 0.3),        # Temperate sclerophyll woodland - Brown
        RGB(0.3, 0.9, 0.3),        # Temperate broadleaved savanna - Fresh Green
        RGB(0.9, 0.7, 0.1),        # Open conifer woodland - Gold
        RGB(0.6, 0.6, 0.3),        # Boreal parkland - Khaki
        RGB(0.9, 0.9, 0.5),        # Tropical grassland - Light Yellow
        RGB(0.6, 0.8, 0.5),        # Temperate grassland - Light Mint Green
        RGB(1.0, 0.7, 0.5),        # Desert - Sand
        RGB(0.5, 0.6, 0.8),        # Steppe tundra - Light Purple
        RGB(0.7, 0.5, 0.9),        # Shrub tundra - Violet
        RGB(0.6, 0.4, 0.7),        # Dwarf shrub tundra - Dark Violet
        RGB(0.5, 0.3, 0.6),        # Prostrate shrub tundra - Deep Purple
        RGB(0.6, 0.2, 0.4),        # Cushion-forbs, lichen and moss - Burgundy
        RGB(0.8, 0.8, 0.8),        # Barren - Light Grey
        RGB(1.0, 1.0, 1.0)         # Land ice - White
    ]
    
    # Load the raster data
    A = Raster(filename, name="biome")

    # Convert the raster data to integers
    int_data = Int.(A[:, :])

    # Replace 0 with -9999 (to represent "Nothing")
    int_data[int_data .== -9999] .= 0

    # Create a new Raster with the modified integer data
    int_raster = Raster(int_data, dims(A); name="biome")

    # Extract longitude and latitude dimensions for axis labels
    lon = dims(A)[1]
    lat = dims(A)[2]

    # Plot the raster with correct axis labels and a larger size
    p1 = Plots.plot(int_raster; max_res=3000, color=cmap, legend=false, title="Biome Distribution",
                    xlabel=lon, ylabel=lat, size=(1200, 1000),
                    clims=(0, 28))

    # Create a dummy plot for the legend
    p2 = Plots.plot(legend=:outerright, xlims=(0, 1), ylims=(0, 1), framestyle=:none, xticks=[], yticks=[])
    for i in 1:28
        Plots.scatter!(p2, [0], [0], label=biomename[i], color=cmap[i], markersize=10)
    end

    # Adjust the layout to make p1 much larger than p2
    l = @layout [a{0.75w} b{0.25w}]
    final_plot = Plots.plot(p1, p2, layout=l)

    # Save the final plot as a PNG file
    savefig(final_plot, output_file)
end

# Example usage:
filename = ""
output_file = ""
plot_biome_distribution(filename, output_file)
