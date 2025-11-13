push!(LOAD_PATH, "../src/")
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
        "Getting Started" =>  Any["getting-started.md", "model-setup.md",
        "data.md"],
        "Plant Functional Types" => "pfts.md",
        "PFT Database" => "pft_database.md",
        "Biomes" => "biomes.md",
        "Climate Models"  => Any[
            "Koppen-Geiger" => "koppen.md",
            "Thornthwaite" => "thornthwaite.md",
            "Troll-Pfaffen" => "trollpfaffen.md",
            "Wissmann" => "wissmann.md",
            ],
        "Mechanistic Model" => Any[
            "BIOME4" => "biome4.md",]
        ],
        "Examples" => "examples.md",
        "API" => "api.md",
        "Contributing" => "contributing.md",
        
    ]
)

deploydocs(
    repo = "github.com/clechartre/Biome.jl.git"
)