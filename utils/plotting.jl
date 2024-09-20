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
        RGB(0.0, 0.6, 0.0),        # Tropical evergreen forest
        RGB(0.3, 0.8, 0.4),        # Tropical semi-deciduous forest
        RGB(0.8, 0.4, 0.2),        # Tropical deciduous forest/woodland
        RGB(0.0, 0.6, 0.1),        # Temperate deciduous forest
        RGB(0.0, 0.5, 0.2),        # Temperate conifer forest
        RGB(0.3, 0.7, 0.3),        # Warm mixed forest
        RGB(0.1, 0.7, 0.9),        # Cool mixed forest
        RGB(0.0, 0.5, 0.5),        # Cool conifer forest
        RGB(0.4, 0.7, 0.6),        # Cold mixed forest
        RGB(0.0, 0.7, 0.7),        # Evergreen taiga/montane forest
        RGB(0.0, 0.4, 0.7),        # Deciduous taiga/montane forest
        RGB(0.9, 0.8, 0.2),        # Tropical savanna
        RGB(0.8, 0.7, 0.4),        # Tropical xerophytic shrubland
        RGB(0.9, 0.7, 0.6),        # Temperate xerophytic shrubland
        RGB(0.7, 0.4, 0.3),        # Temperate sclerophyll woodland
        RGB(0.5, 0.9, 0.3),        # Temperate broadleaved savanna
        RGB(0.8, 0.6, 0.1),        # Open conifer woodland
        RGB(0.5, 0.6, 0.3),        # Boreal parkland
        RGB(0.9, 0.8, 0.5),        # Tropical grassland
        RGB(0.8, 0.6, 0.6),        # Temperate grassland
        RGB(1.0, 0.8, 0.7),        # Desert
        RGB(0.7, 0.7, 0.9),        # Steppe tundra
        RGB(0.6, 0.5, 0.8),        # Shrub tundra
        RGB(0.5, 0.4, 0.7),        # Dwarf shrub tundra
        RGB(0.4, 0.3, 0.6),        # Prostrate shrub tundra
        RGB(0.3, 0.2, 0.5),        # Cushion-forbs, lichen and moss
        RGB(0.9, 0.9, 0.9),        # Barren
        RGB(1.0, 1.0, 1.0)         # Land ice
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
