using Rasters, Plots, Colors, NCDatasets

include("../../src/model.jl")

function plot_biomes(m::KoppenModel, filename::String, output_file::String, pftdict::none)
    # Define Köppen-Geiger biome names and their corresponding indices
    biome_names = [ 
        "Equatorial fully humid (Af)", "Equatorial monsoonal (Am)", "Equatorial summer dry (As)",
        "Equatorial winter dry (Aw)", "Hot desert (BWh)", "Cold desert (BWk)",
        "Hot steppe (BSh)", "Cold steppe (BSk)", "Warm temperate fully humid hot summer (Cfa)",
        "Warm temperate fully humid warm summer (Cfb)", "Warm temperate fully humid cool summer (Cfc)",
        "Warm temperate summer dry hot summer (Csa)", "Warm temperate summer dry warm summer (Csb)",
        "Warm temperate summer dry cool summer (Csc)", "Warm temperate, winter dry, hot summer (Cwa)",
         "Warm temperate, winter dry, warm summer (Cwb)", "Warm temperate, winter dry, cool summer (Cwc)", "Snow fully humid hot summer (Dfa)",
        "Snow fully humid warm summer (Dfb)", "Snow fully humid cool summer (Dfc)",
        "Snow fully humid extremely continental (Dfd)", "Snow summer dry hot summer (Dsa)",
        "Snow summer dry warm summer (Dsb)", "Snow summer dry cool summer (Dsc)",
        "Snow summer dry extremely continental (Dsd)", "Snow winter dry hot summer (Dwa)",
        "Snow winter dry warm summer (Dwb)", "Snow winter dry cool summer (Dwc)",
        "Snow winter dry extremely continental (Dwd)", "Polar tundra (ET)", "Polar frost (EF)", ""
    ]

    # Define a colormap for Köppen-Geiger classes
    cmap = [
        # RGBA(0, 0, 0, 0),           # Transparent for -9999
        RGB(19/255, 0/255, 252/255),  # Af
        RGB(14/255, 115/255, 252/255),          # Am
        RGB(58/255, 170/255, 252/255),  # As - Not on Wikipedia?
        RGB(58/255, 170/255, 252/255),  # Aw
        RGB(254/255, 149/255, 148/255),  # BWk
        RGB(253/255, 0, 0),        # BWh
        RGB(253/255, 218/255, 98/255),   # BSk
        RGB(246/255, 162/255, 0),   # Bsh
        RGB(197/255, 254/255, 75/255),   # Cfa
        RGB(99/255, 253/255, 50/255),       # Cfb
        RGB(40/255, 150/255, 0),              # Cfc
        RGB(250/255, 254/255, 4/255),    # Csa
        RGB(206/255, 204/255, 8/255),        # Csb
        RGB(203/255, 255/255, 0),        # Csc
        RGB(148/255, 254/255, 151/255),        # Cwa
        RGB(95/255, 199/255, 101/255),    # Cwb
        RGB(54/255, 150/255, 51/255),      # Cwc
        RGB(0, 252/255, 253/255),          # Dfa
        RGB(61/255, 198/255, 250/255),        # Dfb
        RGB(0, 126/255, 126/255),        # Dfc
        RGB(0, 70/255, 96/255),   # Dfd
        RGB(252/255, 0, 251/255),  # Dsa
        RGB(201/255, 0, 196/255),  # Dsb
        RGB(152/255, 51/255, 150/255),  # Dsc
        RGB(142/255, 93/255, 146/255),  # Dsd
        RGB(165/255, 175/255, 255/255),  # Dwa
        RGB(74/255, 120/255, 227/255),  # Dwb
        RGB(72/255, 78/255, 180/255),   # Dwc
        RGB(48/255, 0, 138/255),   # Dwd
        RGB(174/255, 176/255, 173/255),  # ET
        RGB(104/255, 105/255, 103/255),  # EF
        RGB(245/255, 245/255, 245/255),   # NA
        RGBA(0, 0, 0, 0) # out

    ]

    # Load the NetCDF dataset and extract biome data
    A = Raster(filename, name="biome")
    biome_data = Int.(A[:, :])  # Convert raster data to integers

    # Replace missing values (assume -9999 is the fill value)
    biome_data[biome_data .== -9999] .= 100000
    biome_data[biome_data .== -1] .= 100000

    # Create a new raster with modified biome data
    biome_raster = Raster(biome_data, dims(A); name="biome")

    # Extract longitude and latitude dimensions for axis labels
    lon = dims(A)[1]
    lat = dims(A)[2]

    # Plot the raster with the Köppen-Geiger colormap
    p1 = Plots.plot(biome_raster; max_res=3000, color=cmap, legend=false, title="Köppen-Geiger Biome Distribution",
                    xlabel=lon, ylabel=lat, size=(1200, 1000),
                    clims=(1, length(cmap)-1))

    # Create a dummy plot for the legend
    p2 = Plots.plot(legend=:outerright, xlims=(0, 1), ylims=(0, 1), framestyle=:none, xticks=[], yticks=[])
    for i in 1:length(biome_names)-1
        Plots.scatter!(p2, [0], [0], label=biome_names[i], color=cmap[i], markersize=10)
    end

    # Adjust the layout
    l = @layout [a{0.75w} b{0.25w}]
    final_plot = Plots.plot(p1, p2, layout=l)

    # Save the final plot
    savefig(final_plot, output_file)
end

# Example usage
filename = "/Users/capucinelechartre/Documents/PhD/BIOME4Py/output_koppengeiger.nc"
output_file = "/Users/capucinelechartre/Documents/PhD/BIOME4Py/output_koppengeiger.png"
plot_biomes(KoppenModel(), filename, output_file)
