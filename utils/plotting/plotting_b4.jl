import ArchGDAL
using NCDatasets
using Rasters, Plots, Colors

include("../../src/model.jl")

function plot_biomes(m::BIOME4Model, filename::String, output_file::String)
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
        RGBA(0.0, 0.0, 0.0, 0.0),          # Transparent for -9999
        RGB(0.1059, 0.3961, 0.0667),      # Tropical evergreen forest - Rich Dark Green
        RGB(0.3216, 0.4980, 0.0157),      # Tropical semi-deciduous forest - Vivid Light Green
        RGB(0.5765, 0.3961, 0.0275),      # Tropical deciduous forest/woodland - Orange-Red
        RGB(0.2431, 0.7804, 0.0),         # Temperate deciduous forest - Forest Green
        RGB(0.1176, 0.3961, 0.4),         # Temperate conifer forest - Muted Teal
        RGB(0.0510, 0.0980, 0.5098),      # Warm mixed forest - Olive Green
        RGB(0.8196, 1.0, 0.7882),         # Cool mixed forest - Bright Blue
        RGB(0.1804, 0.5961, 0.1529),      # Cool conifer forest - Darker Blue
        RGB(0.4784, 0.1961, 0.3020),      # Cold mixed forest - Soft Cyan
        RGB(0.1608, 0.0863, 0.9216),      # Evergreen taiga/montane forest - Medium Turquoise
        RGB(0.3412, 0.8, 1.0),            # Deciduous taiga/montane forest - Slate Blue
        RGB(0.7137, 0.9020, 0.0),         # Tropical savanna - Bright Yellow
        RGB(0.9725, 0.6980, 0.5843),      # Tropical xerophytic shrubland - Tan
        RGB(0.9843, 0.8510, 0.6863),      # Temperate xerophytic shrubland - Pale Pink
        RGB(0.4157, 0.5961, 0.0),         # Temperate sclerophyll woodland - Brown
        RGB(0.7961, 0.8, 0.0),            # Temperate broadleaved savanna - Fresh Green
        RGB(0.9725, 0.5961, 0.9098),      # Open conifer woodland - Gold
        RGB(0.6039, 0.4941, 1.0),         # Boreal parkland - Khaki
        RGB(0.8824, 0.6980, 0.2510),      # Tropical grassland - Light Yellow
        RGB(0.9882, 0.8980, 0.4627),      # Temperate grassland - Light Mint Green
        RGB(1.0, 1.0, 0.8980),            # Desert - Sand
        RGB(0.8941, 0.9020, 0.0),         # Steppe tundra - Light Purple
        RGB(0.4706, 0.9020, 0.4706),      # Shrub tundra - Violet
        RGB(0.4941, 0.4980, 0.1608),      # Dwarf shrub tundra - Dark Violet
        RGB(0.7843, 0.5961, 0.5922),      # Prostrate shrub tundra - Deep Purple
        RGB(0.6980, 0.5961, 1.0),         # Cushion-forbs, lichen and moss - Melrose
        RGB(0.8, 0.8, 0.6902),            # Barren - Foggy Gray
        RGB(0.8235, 1.0, 1.0)             # Land ice - Oyster Bay
    ]
    
    
    # Load the raster data
    A = Raster(filename, name="biome", lazy=true)

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
    for i in 2:29
        Plots.scatter!(p2, [0], [0], label=biomename[i], color=cmap[i], markersize=10)
    end

    # Adjust the layout to make p1 much larger than p2
    l = @layout [a{0.75w} b{0.25w}]
    final_plot = Plots.plot(p1, p2, layout=l)

    # Save the final plot as a PNG file
    savefig(final_plot, output_file)
end

# Example usage:
filename = "/Users/capucinelechartre/Documents/PhD/BIOME5/output_all_int.nc"
output_file = "/Users/capucinelechartre/Documents/PhD/BIOME5/output_all_int.png"
plot_biomes(BIOME4Model(), filename, output_file)
