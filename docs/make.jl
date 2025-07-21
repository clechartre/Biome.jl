push!(LOAD_PATH, "../src/")
using Documenter, Biome

__precompile__(false)

makedocs(
  sitename  = "Biome.jl",
  authors = "Capucine Lechartre and contributors",
  modules   = [Biome],
  format    = Documenter.HTML(),
  checkdocs = :warn,
  pages = [
        "Home" => "index.md",
        "User Guide" => Any[
        "Getting Started" =>  Any["install.md",
        "data.md"],
        "Plant Functional Types" => "pfts.md",
        "Climate Models"  => Any[
            "Koppen-Geiger" => "koppen.md",
            "Thornthwaite" => "thornthwaite.md",
            "Troll-Pfaffen" => "trollpfaffen.md",
            "Wissmann" => "wissmann.md",
            ],
        "Mechanistic Model" => Any[
            "BIOME4" => "biome4.md",]
        ],
        "API" => "api.md",
        
    ]
)

deploydocs(
    repo = "github.com/clechartre/Biome.jl.git"
)