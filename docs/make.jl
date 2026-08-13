# push!(LOAD_PATH, "../src/")

using Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()

# --- Custom step: Generate pfts.json from .toml files ---
try
    using TOML
    using JSON

    pft_dir = joinpath(@__DIR__, "pfts")
    output_json = joinpath(@__DIR__, "src", "assets", "pfts", "pfts.json")

    # Ensure the output directory exists
    mkpath(dirname(output_json))

    pfts_data = Dict{String, Any}()

    if isdir(pft_dir)
        for filename in readdir(pft_dir)
            if endswith(filename, ".toml")
                pft_name = splitext(filename)[1]
                try
                    data = TOML.parsefile(joinpath(pft_dir, filename))
                    pfts_data[pft_name] = data
                catch e
                    @warn "Failed to parse PFT TOML: $filename" exception=e
                end
            end
        end
    end
    open(output_json, "w") do io
        JSON.print(io, pfts_data)
    end
catch e
    @warn "Could not generate pfts.json: $e"
end
# --------------------------------------------------------

using Documenter, Biome

makedocs(
  sitename  = "Biome.jl",
  authors = "Capucine Lechartre and contributors",
  modules   = [Biome],
  format    = Documenter.HTML(;
  assets = [
        "assets/pfts/pfts.css",
        "assets/pfts/pfts.js",
    ],
    ),
  checkdocs = :warn,
  pages = [
        "Home" => "index.md",
        "User Guide" => Any[
        "Getting Started" =>  Any["model-setup.md",
        "data.md"],
        "Plant Functional Types" => "pfts.md",
        "PFT Database" => "pft_database.md",
        "Biomes" => "biomes.md",
        "Climate Models"  => Any[
            "Koppen-Geiger" => "koppen.md",
            "Thornthwaite" => "thornthwaite.md",
            "Troll-Paffen" => "trollpaffen.md",
            "Wissmann" => "wissmann.md",
            ],
        "Mechanistic Model" => Any[
            "BIOME4" => "biome4.md",
            "Custom setup" => "custom_mechanistic_setup.md",
        ],
        "Examples" => "examples.md",
        "API" => "api.md",
        "Contributing" => "contributing.md",
        
    ]
)

deploydocs(
    repo = "github.com/clechartre/Biome.jl.git"
)