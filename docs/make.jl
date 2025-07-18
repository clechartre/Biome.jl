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
        "Getting Started" =>  "getting_started.md",
        "Plant Functional Types" => "pfts.md",
        ],
        "API" => "api.md"
    ]
)

deploydocs(
    repo = "github.com/clechartre/Biome.jl.git"
)