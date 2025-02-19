using Rasters, Plots, Colors, NCDatasets

include("../../src/model.jl")

function plot_biomes(m::TrollPfaffenModel, filename::String, output_file::String, pftdict::none)
    # Define Troll-Paffen biome names and their corresponding indices
    biome_names = [
        "Polar ice-deserts", "Polar frost-debris belt", "Tundra", 
        "Sub-polar tussock grassland and moors", "Oceanic humid coniferous woods",
        "Continental coniferous woods", "Highly continental dry coniferous woods",
        "Evergreen broad-leaved and mixed woods", "Oceanic deciduous broad-leaved and mixed woods",
        "Sub-oceanic deciduous broad-leaved and mixed woods", "Sub-continental deciduous broad-leaved and mixed woods",
        "Continental deciduous broad-leaved-\nand mixed woods as well as wooded steppe",
        "Highly continental deciduous broad-leaved-\nand mixed woods as well as wooded steppe",
        "Deciduous broad-leaved and mixed-\nwood and wooded steppe", 
        "Thermophile dry wood and wooded steppe", "Humid deciduous broad-leaved and mixed wood",
        "High grass-steppe with perennial herbs", "Humid steppe with mild winters",
        "Short grass-, dwarf shrub-, or thorn-steppe", "Steppe with short grass, dwarf shrubs and thorns",
        "Central and East-Asian grass and dwarf shrub steppe", "Semi-desert and desert with cold winters",
        "Semi-desert and desert with mild winters", "Sub-tropical hard-leaved and coniferous wood",
        "Sub-tropical grass and shrub-steppe", "Sub-tropical thorn- and succulents-steppe",
        "Sub-tropical steppe with short grass", "Sub-tropical semi-deserts and deserts",
        "Sub-tropical high-grassland", "Sub-tropical humid forests",
        "Evergreen tropical rain forest", "Rain-green humid forest",
        "Half-deciduous transition wood", "Rain-green dry wood and savannah",
        "Tropical thorn-succulent wood and savannah", "Tropical dry climates with humid months in winter",
        "Tropical semi-deserts and deserts", "Not Classified"
    ]

    # Define a colormap for Troll-Paffen classes
    cmap = [
        RGB(230/255, 250/255, 250/255), # TP_I_1
        RGB(216/255, 245/255, 250/255), # TP_I_2
        RGB(185/255, 224/255, 250/255), # TP_I_3
        RGB(156/255, 205/255, 240/255), # TP_I_4
        RGB(190/255, 170/255, 214/255), # TP_II_1
        RGB(215/255, 201/255, 229/255), # TP_II_2
        RGB(234/255, 225/255, 238/255), # TP_II_3
        RGB(145/255, 116/255, 90/255),  # TP_III_1
        RGB(170/255, 152/255, 106/255), # TP_III_2
        RGB(193/255, 164/255, 123/255), # TP_III_3
        RGB(210/255, 180/255, 140/255), # TP_III_4
        RGB(226/255, 220/255, 177/255), # TP_III_5
        RGB(242/255, 235/255, 220/255), # TP_III_6
        RGB(233/255, 226/255, 150/255), # TP_III_7
        RGB(223/255, 216/255, 140/255), # TP_III_7a
        RGB(218/255, 200/255, 100/255), # TP_III_8
        RGB(234/255, 207/255, 80/255),  # TP_III_9
        RGB(224/255, 197/255, 70/255),  # TP_III_9a
        RGB(244/255, 236/255, 88/255),  # TP_III_10
        RGB(234/255, 226/255, 78/255),  # TP_III_10a
        RGB(241/255, 239/255, 112/255), # TP_III_11
        RGB(245/255, 245/255, 200/255), # TP_III_12
        RGB(235/255, 235/255, 190/255), # TP_III_12a
        RGB(201/255, 138/255, 110/255), # TP_IV_1
        RGB(227/255, 158/255, 110/255), # TP_IV_2
        RGB(241/255, 195/255, 143/255), # TP_IV_3
        RGB(235/255, 175/255, 80/255),  # TP_IV_4
        RGB(255/255, 219/255, 109/255), # TP_IV_5
        RGB(251/255, 172/255, 100/255), # TP_IV_6
        RGB(229/255, 157/255, 90/255),  # TP_IV_7
        RGB(77/255, 117/255, 77/255),   # TP_V_1
        RGB(117/255, 152/255, 77/255),  # TP_V_2
        RGB(107/255, 142/255, 67/255),  # TP_V_2a
        RGB(150/255, 180/255, 80/255),  # TP_V_3
        RGB(192/255, 211/255, 106/255), # TP_V_4
        RGB(182/255, 201/255, 96/255),  # TP_V_4a
        RGB(212/255, 228/255, 181/255), # TP_V_5
        RGB(245/255, 245/255, 245/255)  # NA
    ]

    # Load the NetCDF dataset and extract biome data
    A = Raster(filename, name="biome")
    biome_data = Int.(A[:, :])  # Convert raster data to integers

    # Replace missing values (assume -9999 is the fill value)
    biome_data[biome_data .== -9999] .= 38  # NA index

    # Create a new raster with modified biome data
    biome_raster = Raster(biome_data, dims(A); name="biome")

    # Extract longitude and latitude dimensions for axis labels
    lon = dims(A)[1]
    lat = dims(A)[2]

    # Plot the raster with the Troll-Paffen colormap
    p1 = Plots.plot(biome_raster; max_res=3000, color=cmap, legend=false, title="Troll-Paffen Biome Distribution",
                    xlabel=lon, ylabel=lat, size=(1200, 1000),
                    clims=(1, length(cmap)))

    # Create a dummy plot for the legend
    p2 = Plots.plot(legend=:outerright, xlims=(0, 1), ylims=(0, 1), framestyle=:none, xticks=[], yticks=[])
    for i in 1:length(biome_names)
        Plots.scatter!(p2, [0], [0], label=biome_names[i], color=cmap[i], markersize=10)
    end

    # Adjust the layout
    l = @layout [a{0.65w} b{0.35w}]
    final_plot = Plots.plot(p1, p2, layout=l)

    # Save the final plot
    savefig(final_plot, output_file)
end

# Example usage
filename = "/Users/capucinelechartre/Documents/PhD/BIOME4Py/output_trollpfaffen.nc"
output_file = "/Users/capucinelechartre/Documents/PhD/BIOME4Py/output_trollpfaffen.png"
plot_biomes(TrollPfaffenModel(), filename, output_file)
