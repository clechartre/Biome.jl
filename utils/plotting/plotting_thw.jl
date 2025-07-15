using Rasters, Plots, Colors, NCDatasets

include("../../src/abstractmodel.jl")

function plot_biomes(m::ThornthwaiteModel, filename::String, output_file::String)
    # Define Thornthwaite climate categories
    THORN_LABELS = ["Wet", "Humid", "Subhumid", "Semiarid", "Arid"]
    THORN_TEMP_LABELS = ["Tropical", "Mesothermal", "Microthermal", "Taiga", "Tundra", "Frost"]

    # Define distinct colors for each moisture-temperature combination
    colormap = [
        RGB(0.0, 0.5, 1.0),  # Wet / Tropical (Blue)
        RGB(0.0, 0.7, 0.7),  # Wet / Mesothermal (Teal)
        RGB(0.0, 0.9, 0.5),  # Wet / Microthermal (Green)
        RGB(0.5, 0.9, 0.0),  # Wet / Taiga (Light Green)
        RGB(0.9, 0.9, 0.0),  # Wet / Tundra (Yellow)
        RGB(1.0, 0.6, 0.0),  # Wet / Frost (Orange)
        
        RGB(0.2, 0.4, 1.0),  # Humid / Tropical (Deep Blue)
        RGB(0.2, 0.6, 0.8),  # Humid / Mesothermal (Sea Blue)
        RGB(0.2, 0.8, 0.5),  # Humid / Microthermal (Emerald Green)
        RGB(0.6, 0.8, 0.0),  # Humid / Taiga (Lime)
        RGB(0.9, 0.8, 0.2),  # Humid / Tundra (Golden Yellow)
        RGB(1.0, 0.5, 0.2),  # Humid / Frost (Dark Orange)
        
        RGB(0.4, 0.4, 1.0),  # Subhumid / Tropical (Indigo)
        RGB(0.4, 0.6, 0.8),  # Subhumid / Mesothermal (Sky Blue)
        RGB(0.4, 0.8, 0.4),  # Subhumid / Microthermal (Light Green)
        RGB(0.7, 0.7, 0.0),  # Subhumid / Taiga (Yellow-Green)
        RGB(0.9, 0.7, 0.3),  # Subhumid / Tundra (Orange-Yellow)
        RGB(1.0, 0.4, 0.4),  # Subhumid / Frost (Coral)

        RGB(0.6, 0.3, 1.0),  # Semiarid / Tropical (Purple)
        RGB(0.6, 0.5, 0.9),  # Semiarid / Mesothermal (Lavender)
        RGB(0.6, 0.7, 0.6),  # Semiarid / Microthermal (Pale Green)
        RGB(0.8, 0.6, 0.2),  # Semiarid / Taiga (Golden Brown)
        RGB(0.9, 0.5, 0.5),  # Semiarid / Tundra (Pink)
        RGB(1.0, 0.2, 0.6),  # Semiarid / Frost (Magenta)

        RGB(0.8, 0.0, 1.0),  # Arid / Tropical (Violet)
        RGB(0.8, 0.2, 0.8),  # Arid / Mesothermal (Pink-Purple)
        RGB(0.8, 0.4, 0.6),  # Arid / Microthermal (Rose)
        RGB(0.8, 0.6, 0.4),  # Arid / Taiga (Beige)
        RGB(0.9, 0.4, 0.3),  # Arid / Tundra (Brick Red)
        RGB(1.0, 0.0, 0.0)   # Arid / Frost (Red)
    ]

    # Add "NA" color
    na_color = RGB(0.9, 0.9, 0.9)  # Light gray for NA
    push!(colormap, na_color)

    # Generate labels for each class
    biome_labels = [ "$(THORN_LABELS[m]) / $(THORN_TEMP_LABELS[t])" for m in 1:5, t in 1:6 ]
    # push!(biome_labels, "NA")  # Add NA label

    # Order the colors and labels by gradient
    legend_order = [(m, t) for m in 1:5 for t in 1:6]  # Moisture from Wet to Arid, Temp from Tropical to Frost
    ordered_labels = [ "$(THORN_LABELS[m]) / $(THORN_TEMP_LABELS[t])" for (m, t) in legend_order ]
    ordered_colors = [colormap[(m - 1) * 6 + t] for (m, t) in legend_order]
    ordered_colors = vcat(ordered_colors, na_color)  # Add NA color at the end

    # Load the NetCDF dataset and extract biome data
    A_moisture = Raster(filename, name="moisture_zone")
    A_temperature = Raster(filename, name="temperature_zone")

    moisture_data = Int.(A_moisture[:, :])  # Convert raster data to integers
    temperature_data = Int.(A_temperature[:, :])

    # Check data integrity
    valid_moisture = (moisture_data .>= 1) .& (moisture_data .<= 5)
    valid_temperature = (temperature_data .>= 1) .& (temperature_data .<= 6)
    valid_data = valid_moisture .& valid_temperature

    # Reorder raster indices to match the gradient order
    reordered_indices = Dict((m, t) => i for (i, (m, t)) in enumerate(legend_order))
    combined_data = zeros(Int, size(moisture_data))
    for i in 1:size(moisture_data, 1), j in 1:size(moisture_data, 2)
        if valid_data[i, j]
            m = moisture_data[i, j]
            t = temperature_data[i, j]
            combined_data[i, j] = reordered_indices[(m, t)]
        else
            combined_data[i, j] = length(ordered_labels)  # NA index
        end
    end

    # Create a new raster with reordered biome data
    biome_raster = Raster(combined_data, dims(A_moisture); name="biome_combined")

    # Plot the raster with the Thornthwaite colormap
    p1 = plot(
        biome_raster; 
        color=ordered_colors, 
        title="Thornthwaite Climate Classification",
        xlabel="Longitude", 
        ylabel="Latitude", 
        size=(1200, 1000),
        legend=false
    )

    # Create a dummy plot for the legend
    p2 = plot(legend=:outerright, framestyle=:none, xticks=[], yticks=[])
    for i in 1:length(ordered_labels)
        scatter!(p2, [0], [0], label=ordered_labels[i], color=ordered_colors[i], markersize=10)
    end

    # Combine plots
    final_plot = plot(p1, p2, layout = @layout [a b{0.2w}])

    # Save the final plot
    savefig(final_plot, output_file)
end

# Run the plotting function
filename = ""
output_file = ""
plot_biomes(ThornthwaiteModel(), filename, output_file)
