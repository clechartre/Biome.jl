using Test
using Biome

@testset "Bione.jl Tests" begin
    @testset "MechanisticModel Tests" begin
        include("test_BIOME/MechanisticModel/test_climdata.jl")
        include("test_BIOME/MechanisticModel/test_constraints.jl")
        include("test_BIOME/MechanisticModel/test_phenology.jl")
        include("test_BIOME/MechanisticModel/test_snow.jl")
        include("test_BIOME/MechanisticModel/test_soiltemp.jl")
        include("test_BIOME/MechanisticModel/test_ppeett.jl")
        include("test_BIOME/MechanisticModel/test_table.jl")
        include("test_BIOME/MechanisticModel/test_assignbiome.jl")
        include("test_BIOME/MechanisticModel/test_growth.jl")
        
        @testset "Growth Subroutines Tests" begin
            include("test_BIOME/MechanisticModel/test_growth_subroutines/test_c4photo.jl")
            include("test_BIOME/MechanisticModel/test_growth_subroutines/test_calcphi.jl")
            include("test_BIOME/MechanisticModel/test_growth_subroutines/test_daily.jl")
            include("test_BIOME/MechanisticModel/test_growth_subroutines/test_fire.jl")
            include("test_BIOME/MechanisticModel/test_growth_subroutines/test_hetresp.jl")
            include("test_BIOME/MechanisticModel/test_growth_subroutines/test_hydrology.jl")
            include("test_BIOME/MechanisticModel/test_growth_subroutines/test_isotope.jl")
            include("test_BIOME/MechanisticModel/test_growth_subroutines/test_photosynthesis.jl")
            include("test_BIOME/MechanisticModel/test_growth_subroutines/test_respiration.jl")
        end
    end
end