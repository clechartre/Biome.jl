# tests/runtests.jl
using Test
using BIOME

# include every file in the subfolder
for f in filter(x -> endswith(x, ".jl"), readdir(joinpath(@__DIR__, "test_BIOME")))
    include(joinpath(@__DIR__, "test_BIOME", f))
end