import ArchGDAL
using NCDatasets
using Rasters, Plots, Colors

include("../../src/abstractmodel.jl")

gr(fmt = :svg)    #svg

function plot_biomes(m::BaseModel, filename::String, output_file::String)
    class_names = [
        "No data",
        "Needleleaf Evergreen forest",
        "Broadleaf Evergreen forest",
        "Needleleaf Deciduous forest",
        "Broadleaf Deciduous forest",
        "Mixed Forest",
        "C3 Grassland",
        "C4 Grassland",
        "Hot and Cold Desert"
    ]

    cmap = [
        RGBA(0, 0, 0, 0),                              # 0 → No data (transparent)
        RGB(0.0, 0.27, 0.13),                          # 1 → Needleleaf Evergreen (deep forest green)
        RGB(0.35, 0.2, 0.5),                           # 2 → Broadleaf Evergreen (muted purple)
        RGB(0.54, 0.37, 0.26),                         # 3 → Needleleaf Deciduous (wood brown)
        RGB(0.8, 0.0, 0.0),                            # 4 → Broadleaf Deciduous (earthy red)
        RGB(0.6, 0.6, 0.2),                            # 5 → Mixed Forest (olive green)
        RGB(0.4, 0.6, 0.8),                            # 6 → C3 Grassland (cool bluegrass)
        RGB(0.8, 0.85, 0.2),                           # 7 → C4 Grassland (sunny yellow-green)
        RGB(0.87, 0.76, 0.53),                         # 8 → Desert (pale sand)
    ]
    
    
    # 3. Load the raster
    A = Raster(filename, name="biome", lazy=true)
    data = Int.(A[:, :]) 

    data[data .== -9999] .= 0

    R = Raster(data, dims(A); name="biome")

    p1 = plot(R;
        color = cmap,
        clims = (0,8),              
        legend = false,              
        title = "Biome distribution",
        xlabel = first(dims(A)),
        ylabel = last(dims(A)),
        size = (1800, 1200),
        max_res = 3000,
        right_margin=0Plots.mm
    )

    n_biomes = 8 
    optimal_columns = 2
    
    p_leg = plot(
        xlim=(0,1), ylim=(0,1),
        framestyle=:none,
        xticks=false, yticks=false,
        legend=:left,     # legend inside this panel
        legendfontsize=7,
        legendtitle="Base Model Classes",
        legendtitlefontsize=9,
        legend_background_color=:white,
        legend_columns=optimal_columns,
        legend_column_width=-1,  # Reduce column spacing
        legend_row_gap=0.02,     # Reduce row spacing
        legend_title_gap=0.01,   # Reduce gap after title
        left_margin=0Plots.mm
    )

    # Fill legend with square patches (exclude "No data" class)
    for idx in 1:8
        scatter!(
            p_leg,
            [0.0], [0.0],
            label=class_names[idx+1],   # +1 because names[1] is "No data"
            color=cmap[idx+1],
            shape=:rect,
            markersize=6,
            markerstrokewidth=0
        )
    end

    layout = @layout [a{0.60w} b{0.40w}]
    final_plot = plot(p1, p_leg, layout=layout, size=(1800, 1000))
    
    savefig(final_plot, output_file)
end

filename = ""
output_file = ""
plot_biomes(BaseModel(), filename, output_file)
