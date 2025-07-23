import ArchGDAL
using NCDatasets
using Rasters, Plots, Colors

include("../../src/abstractmodel.jl")

function plot_biomes(m::BaseModel, filename::String, output_file::String)
    # 1. Define your class names (we’ll ignore index 0, which is "no data")
    class_names = [
        "No data",
        "Evergreen forest",
        "Deciduous forest",
        "Mixed forest",
        "Grassland",
        "Tundra",
        "Desert",
    ]

    # 2. Define one color per index 0–6
    cmap = [
        RGBA(0,0,0,0),                              # 0 → transparent
        RGB(0.1059, 0.3961, 0.0667),                # 1 → Evergreen
        RGB(0.3216, 0.4980, 0.0157),                # 2 → Deciduous
        RGB(0.5765, 0.3961, 0.0275),                # 3 → Mixed
        RGB(0.2431, 0.7804, 0.0),                   # 4 → Grassland
        RGB(0.8941, 0.9020, 0.0),                   # 5 → Tundra
        RGB(1.0, 1.0, 0.8980),                      # 6 → Desert
    ]

    # 3. Load the raster
    A = Raster(filename, name="biome", lazy=true)
    data = Int.(A[:, :])                         # grab the raw integer codes

    # 4. First, turn any netCDF nodata (–9999) into 0
    data[data .== -9999] .= 0

    # 5. Now remap the “21” desert code into our slot 6
    data[data .== 21] .= 6

    # 6. (All your other values 1–5 remain as-is.)

    # 7. Build a new Raster with the cleaned-up indices
    R = Raster(data, dims(A); name="biome")

    # 8. Plot the main map
    p1 = plot(R;
        color = cmap,
        clims = (0,6),               # so each integer picks its color
        legend = false,
        title = "Biome distribution",
        xlabel = first(dims(A)),     # longitude axis
        ylabel = last(dims(A)),      # latitude axis
        size = (1200,1000),
        max_res = 3000,
    )

    # 9. Build a separate legend panel
    p2 = plot(legend = :outerright, framestyle = :none,
              xlims = (0,1), ylims = (0,1), xticks = [], yticks = [])
    for idx in 1:6
        scatter!(p2, [0], [0];
            label = class_names[idx+1],   # +1 because names[1] is “No data”
            color = cmap[idx+1],
            markersize = 8,
        )
    end

    # 10. Compose and save
    l = @layout [a{0.75w} b{0.25w}]
    final = plot(p1, p2, layout = l)
    savefig(final, output_file)
end

# Example usage:
filename = ""
output_file = ""
plot_biomes(BaseModel(), filename, output_file)
