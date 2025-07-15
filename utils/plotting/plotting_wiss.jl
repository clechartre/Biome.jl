using Rasters, Plots, Colors, NCDatasets

include("../../src/abstractmodel.jl")

function plot_biomes(m::WissmannModel, filename::String, output_file::String)
    # Define Wissmann climate zone names and their corresponding indices
    wissmann_names = [
        "Rainforest, equatorial", "Rainforest, weak dry period", "Savannah and monsoonal rainforest",
        "Steppe, tropical", "Desert, tropical", "Warm temperate, humid, summer dry",
        "Warm temperate, humid", "Warm temperate, winter dry", "Warm temperate, cool summer",
        "Steppe, warm temperate", "Desert, warm temperate", "Cool temperate, humid",
        "Cool temperate, winter dry", "Cool temperate, summer dry", "Steppe, cool temperate",
        "Desert, cool temperate", "Boreal, humid", "Boreal, winter dry", "Steppe, boreal",
        "Desert, boreal", "Polar tundra", "Polar frost", "Not Classified"
    ]

    # Define a colormap for Wissmann classification
    cmap = [
        RGB(34/255, 139/255, 34/255),   # Rainforest, equatorial
        RGB(50/255, 205/255, 50/255),  # Rainforest, weak dry period
        RGB(154/255, 205/255, 50/255), # Savannah and monsoonal rainforest
        RGB(189/255, 183/255, 107/255),# Steppe, tropical
        RGB(210/255, 180/255, 140/255),# Desert, tropical
        RGB(139/255, 69/255, 19/255),  # Warm temperate, humid, summer dry
        RGB(160/255, 82/255, 45/255),  # Warm temperate, humid
        RGB(205/255, 133/255, 63/255), # Warm temperate, winter dry
        RGB(222/255, 184/255, 135/255),# Warm temperate, cool summer
        RGB(244/255, 164/255, 96/255), # Steppe, warm temperate
        RGB(255/255, 127/255, 80/255), # Desert, warm temperate
        RGB(205/255, 92/255, 92/255),  # Cool temperate, humid
        RGB(178/255, 34/255, 34/255),  # Cool temperate, winter dry
        RGB(139/255, 0/255, 0/255),    # Cool temperate, summer dry
        RGB(165/255, 42/255, 42/255),  # Steppe, cool temperate
        RGB(128/255, 0/255, 0/255),    # Desert, cool temperate
        RGB(70/255, 130/255, 180/255), # Boreal, humid
        RGB(135/255, 206/255, 235/255),# Boreal, winter dry
        RGB(176/255, 224/255, 230/255),# Steppe, boreal
        RGB(175/255, 238/255, 238/255),# Desert, boreal
        RGB(240/255, 248/255, 255/255),# Polar tundra
        RGB(255/255, 255/255, 255/255),# Polar frost
        RGB(245/255, 245/255, 245/255) # NA
    ]

    # Load the NetCDF dataset and extract Wissmann classification data
    A = Raster(filename, name="climate_zone")
    wissmann_data = Int.(A[:, :])  # Convert raster data to integers

    # Replace missing values (assume -9999 is the fill value)
    wissmann_data[wissmann_data .== -9999] .= 23  # NA index

    # Create a new raster with modified Wissmann classification data
    wissmann_raster = Raster(wissmann_data, dims(A); name="climate_zone")

    # Extract longitude and latitude dimensions for axis labels
    lon = dims(A)[1]
    lat = dims(A)[2]

    # Plot the raster with the Wissmann colormap
    p1 = Plots.plot(wissmann_raster; max_res=3000, color=cmap, legend=false, title="Wissmann Climate Zones",
                    xlabel=lon, ylabel=lat, size=(1200, 1000),
                    clims=(1, length(cmap)))

    # Create a dummy plot for the legend
    p2 = Plots.plot(legend=:outerright, xlims=(0, 1), ylims=(0, 1), framestyle=:none, xticks=[], yticks=[])
    for i in 1:length(wissmann_names)
        Plots.scatter!(p2, [0], [0], label=wissmann_names[i], color=cmap[i], markersize=10)
    end

    # Adjust the layout
    l = @layout [a{0.65w} b{0.35w}]
    final_plot = Plots.plot(p1, p2, layout=l)

    # Save the final plot
    savefig(final_plot, output_file)
end

# Example usage
filename = ""
output_file = ""
plot_biomes(WissmannModel(), filename, output_file)
