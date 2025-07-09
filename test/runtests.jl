using Test
using BIOME

@testset "BIOME.jl Tests" begin
    @testset "MechanisticModel Tests" begin
        include("test_BIOME/MechanisticModel/test_climdata.jl")
        include("test_BIOME/MechanisticModel/test_constraints.jl")
        include("test_BIOME/MechanisticModel/test_phenology.jl")
        include("test_BIOME/MechanisticModel/test_snow.jl")
        include("test_BIOME/MechanisticModel/test_soiltemp.jl")
        include("test_BIOME/MechanisticModel/test_ppeett.jl")
        include("test_BIOME/MechanisticModel/test_table.jl")
        include("test_BIOME/MechanisticModel/test_newassignbiome.jl")
        include("test_BIOME/MechanisticModel/test_growth.jl")
        
        @testset "Growth Subroutines Tests" begin
            include("test_BIOME/MechanisticModel/test_growth_subroutines/test_c4photo.jl")
            # Add other growth subroutine tests here
        end
    end
end