using Test

include("../../../src/abstractmodel.jl")
include("../../../src/pfts.jl")
include("../../../src/biomes.jl")
include("../../../src/models/MechanisticModel/pfts.jl")
include("../../../src/models/MechanisticModel/newassignbiome.jl")

@testset "New Assign Biome Tests" begin
    
    @testset "Mock Assign Biome Test" begin
        # Test the mock function
        result = mock_assign_biome(nothing, nothing, nothing, 0.0, 0.0, 0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, BiomeClassification(50.0, 100.0, 15.0))
        @test result == 1
        @test typeof(result) == Int
    end
    
    @testset "Tropical Evergreen Assignment Tests" begin
        # Create test PFTs and biome classification
        biome_pfts = BiomeClassification(50.0, 1500.0, 26.0)
        tropical_evergreen = TropicalEvergreen(50.0, 1500.0, 26.0)
        
        # Test with high NPP - should return TropicalEvergreenForest
        set_characteristic(tropical_evergreen, :npp, 500.0)
        result = assign_biome(tropical_evergreen, Default(), Default(), 2000.0, 3000.0, 25.0, 15.0, biome_pfts)
        @test isa(result, TropicalEvergreenForest)
        
        # Test with low NPP - should return Desert
        set_characteristic(tropical_evergreen, :npp, 50.0)
        result_low = assign_biome(tropical_evergreen, Default(), Default(), 2000.0, 3000.0, 25.0, 15.0, biome_pfts)
        @test isa(result_low, Desert)
    end
    
    @testset "Tropical Drought Deciduous Assignment Tests" begin
        biome_pfts = BiomeClassification(40.0, 1200.0, 24.0)
        tropical_drought = TropicalDroughtDeciduous(40.0, 1200.0, 24.0)
        
        # Test with high NPP and long green season
        set_characteristic(tropical_drought, :npp, 400.0)
        set_characteristic(tropical_drought, :greendays, 320)
        result_long = assign_biome(tropical_drought, Default(), Default(), 1800.0, 2500.0, 22.0, 12.0, biome_pfts)
        @test isa(result_long, TropicalEvergreenForest)
        
        # Test with medium green season
        set_characteristic(tropical_drought, :greendays, 280)
        result_medium = assign_biome(tropical_drought, Default(), Default(), 1800.0, 2500.0, 22.0, 12.0, biome_pfts)
        @test isa(result_medium, TropicalSemiDeciduousForest)
        
        # Test with short green season
        set_characteristic(tropical_drought, :greendays, 200)
        result_short = assign_biome(tropical_drought, Default(), Default(), 1800.0, 2500.0, 22.0, 12.0, biome_pfts)
        @test isa(result_short, TropicalDeciduousForestWoodland)
        
        # Test with low NPP
        set_characteristic(tropical_drought, :npp, 80.0)
        result_low_npp = assign_biome(tropical_drought, Default(), Default(), 1800.0, 2500.0, 22.0, 12.0, biome_pfts)
        @test isa(result_low_npp, Desert)
    end
    
    @testset "Temperate Broadleaved Evergreen Assignment Tests" begin
        biome_pfts = BiomeClassification(35.0, 1000.0, 18.0)
        temperate_be = TemperateBroadleavedEvergreen(35.0, 1000.0, 18.0)
        
        # Test with high NPP
        set_characteristic(temperate_be, :npp, 300.0)
        result_high = assign_biome(temperate_be, Default(), Default(), 1500.0, 2000.0, 5.0, -5.0, biome_pfts)
        @test isa(result_high, WarmMixedForest)
        
        # Test with low NPP
        set_characteristic(temperate_be, :npp, 80.0)
        result_low = assign_biome(temperate_be, Default(), Default(), 1500.0, 2000.0, 5.0, -5.0, biome_pfts)
        @test isa(result_low, Desert)
    end
    
    @testset "Temperate Deciduous Assignment Tests" begin
        biome_pfts = BiomeClassification(40.0, 800.0, 10.0)
        temperate_dec = TemperateDeciduous(40.0, 800.0, 10.0)
        
        # Test with high NPP and boreal evergreen present
        set_characteristic(temperate_dec, :npp, 250.0)
        
        # Set boreal evergreen as present
        boreal_idx = findfirst(pft -> get_characteristic(pft, :name) == "BorealEvergreen", biome_pfts.pft_list)
        set_characteristic(biome_pfts.pft_list[boreal_idx], :present, true)
        
        # Test cold conditions
        result_cold = assign_biome(temperate_dec, Default(), Default(), 1200.0, 1800.0, -20.0, -25.0, biome_pfts)
        @test isa(result_cold, ColdMixedForest)
        
        # Test warmer conditions
        result_warm = assign_biome(temperate_dec, Default(), Default(), 1200.0, 1800.0, -10.0, -15.0, biome_pfts)
        @test isa(result_warm, CoolMixedForest)
        
        # Test with temperate broadleaved evergreen present and high GDD5
        tbe_idx = findfirst(pft -> get_characteristic(pft, :name) == "TemperateBroadleavedEvergreen", biome_pfts.pft_list)
        set_characteristic(biome_pfts.pft_list[tbe_idx], :present, true)
        set_characteristic(biome_pfts.pft_list[boreal_idx], :present, false)
        result_tbe = assign_biome(temperate_dec, Default(), Default(), 1200.0, 3500.0, 5.0, 0.0, biome_pfts)
        @test isa(result_tbe, WarmMixedForest)
        
        # Test fallback to temperate deciduous forest
        set_characteristic(biome_pfts.pft_list[tbe_idx], :present, false)
        set_characteristic(biome_pfts.pft_list[boreal_idx], :present, false)
        result_fallback = assign_biome(temperate_dec, Default(), Default(), 1200.0, 2000.0, 0.0, -5.0, biome_pfts)
        @test isa(result_fallback, TemperateDeciduousForest)
        
        # Test with low NPP
        set_characteristic(temperate_dec, :npp, 70.0)
        result_low_npp = assign_biome(temperate_dec, Default(), Default(), 1200.0, 2000.0, 0.0, -5.0, biome_pfts)
        @test isa(result_low_npp, Desert)
    end
    
    @testset "Cool Conifer Assignment Tests" begin
        biome_pfts = BiomeClassification(30.0, 600.0, 12.0)
        cool_conifer = CoolConifer(30.0, 600.0, 12.0)
        
        # Test with high NPP and temperate broadleaved evergreen present
        set_characteristic(cool_conifer, :npp, 200.0)
        tbe_idx = findfirst(pft -> get_characteristic(pft, :name) == "TemperateBroadleavedEvergreen", biome_pfts.pft_list)
        set_characteristic(biome_pfts.pft_list[tbe_idx], :present, true)
        
        result_tbe = assign_biome(cool_conifer, Default(), Default(), 1000.0, 1500.0, 2.0, -3.0, biome_pfts)
        @test isa(result_tbe, WarmMixedForest)
        
        # Test with temperate deciduous subdominant
        set_characteristic(biome_pfts.pft_list[tbe_idx], :present, false)
        temperate_dec = TemperateDeciduous(40.0, 800.0, 10.0)
        result_temp_dec = assign_biome(cool_conifer, temperate_dec, Default(), 1000.0, 1500.0, 2.0, -3.0, biome_pfts)
        @test isa(result_temp_dec, TemperateConiferForest)
        
        # Test with boreal deciduous subdominant
        boreal_dec = BorealDeciduous(45.0, 600.0, -2.0)
        result_boreal_dec = assign_biome(cool_conifer, boreal_dec, Default(), 1000.0, 1500.0, -5.0, -10.0, biome_pfts)
        @test isa(result_boreal_dec, ColdMixedForest)
        
        # Test fallback
        result_fallback = assign_biome(cool_conifer, Default(), Default(), 1000.0, 1500.0, 2.0, -3.0, biome_pfts)
        @test isa(result_fallback, TemperateConiferForest)
        
        # Test with low NPP
        set_characteristic(cool_conifer, :npp, 60.0)
        result_low_npp = assign_biome(cool_conifer, Default(), Default(), 1000.0, 1500.0, 2.0, -3.0, biome_pfts)
        @test isa(result_low_npp, Desert)
    end
    
    @testset "Boreal Evergreen Assignment Tests" begin
        biome_pfts = BiomeClassification(50.0, 500.0, -3.0)
        boreal_evergreen = BorealEvergreen(50.0, 500.0, -3.0)
        
        # Test warm conditions with temperate deciduous present
        temperate_dec_idx = findfirst(pft -> get_characteristic(pft, :name) == "TemperateDeciduous", biome_pfts.pft_list)
        set_characteristic(biome_pfts.pft_list[temperate_dec_idx], :present, true)
        
        result_warm = assign_biome(boreal_evergreen, Default(), Default(), 800.0, 1200.0, -10.0, -15.0, biome_pfts)
        @test isa(result_warm, CoolMixedForest)
        
        # Test warm conditions without temperate deciduous
        set_characteristic(biome_pfts.pft_list[temperate_dec_idx], :present, false)
        result_warm_no_td = assign_biome(boreal_evergreen, Default(), Default(), 800.0, 1200.0, -10.0, -15.0, biome_pfts)
        @test isa(result_warm_no_td, CoolConiferForest)
        
        # Test cold conditions with temperate deciduous present
        set_characteristic(biome_pfts.pft_list[temperate_dec_idx], :present, true)
        result_cold = assign_biome(boreal_evergreen, Default(), Default(), 600.0, 800.0, -25.0, -30.0, biome_pfts)
        @test isa(result_cold, ColdMixedForest)
        
        # Test cold conditions without temperate deciduous
        set_characteristic(biome_pfts.pft_list[temperate_dec_idx], :present, false)
        result_cold_no_td = assign_biome(boreal_evergreen, Default(), Default(), 600.0, 800.0, -25.0, -30.0, biome_pfts)
        @test isa(result_cold_no_td, EvergreenTaigaMontaneForest)
    end
    
    @testset "Boreal Deciduous Assignment Tests" begin
        biome_pfts = BiomeClassification(48.0, 550.0, -5.0)
        boreal_deciduous = BorealDeciduous(48.0, 550.0, -5.0)
        
        # Test with temperate deciduous subdominant
        temperate_dec = TemperateDeciduous(40.0, 800.0, 10.0)
        result_temp_dec = assign_biome(boreal_deciduous, temperate_dec, Default(), 700.0, 1000.0, -8.0, -12.0, biome_pfts)
        @test isa(result_temp_dec, TemperateDeciduousForest)
        
        # Test with cool conifer subdominant
        cool_conifer = CoolConifer(30.0, 600.0, 12.0)
        result_cool_con = assign_biome(boreal_deciduous, cool_conifer, Default(), 700.0, 1000.0, -8.0, -12.0, biome_pfts)
        @test isa(result_cool_con, CoolConiferForest)
        
        # Test warm conditions
        result_warm = assign_biome(boreal_deciduous, Default(), Default(), 800.0, 1200.0, -10.0, -15.0, biome_pfts)
        @test isa(result_warm, CoolConiferForest)
        
        # Test cold conditions
        result_cold = assign_biome(boreal_deciduous, Default(), Default(), 600.0, 800.0, -25.0, -30.0, biome_pfts)
        @test isa(result_cold, DeciduousTaigaMontaneForest)
    end
    
    @testset "Woody Desert Assignment Tests" begin
        biome_pfts = BiomeClassification(15.0, 200.0, 25.0)
        woody_desert = WoodyDesert(15.0, 200.0, 25.0)
        
        # Test with high NPP and high LAI subdominant
        set_characteristic(woody_desert, :npp, 150.0)
        subdominant = Default()
        set_characteristic(subdominant, :lai, 2.0)
        
        # Test warm conditions (tmin >= 0)
        result_warm = assign_biome(woody_desert, subdominant, Default(), 400.0, 600.0, 20.0, 5.0, biome_pfts)
        @test isa(result_warm, TropicalXerophyticShrubland)
        
        # Test cold conditions (tmin < 0)
        result_cold = assign_biome(woody_desert, subdominant, Default(), 400.0, 600.0, -5.0, -10.0, biome_pfts)
        @test isa(result_cold, TemperateXerophyticShrubland)
        
        # Test with low LAI subdominant
        set_characteristic(subdominant, :lai, 0.5)
        result_low_lai = assign_biome(woody_desert, subdominant, Default(), 400.0, 600.0, 20.0, 5.0, biome_pfts)
        @test isa(result_low_lai, Desert)
        
        # Test with low NPP
        set_characteristic(woody_desert, :npp, 80.0)
        result_low_npp = assign_biome(woody_desert, subdominant, Default(), 400.0, 600.0, 20.0, 5.0, biome_pfts)
        @test isa(result_low_npp, Desert)
    end
    
    @testset "Grass PFT Assignment Tests" begin
        biome_pfts = BiomeClassification(20.0, 400.0, 18.0)
        
        # Test C3C4 Temperate Grass
        temperate_grass = C3C4TemperateGrass(20.0, 400.0, 18.0)
        
        # Test with low NPP and suitable subdominant
        set_characteristic(temperate_grass, :npp, 80.0)
        subdominant = Default()
        result_low_npp = assign_biome(temperate_grass, subdominant, Default(), 600.0, 900.0, 10.0, 5.0, biome_pfts)
        @test isa(result_low_npp, Desert)
        
        # Test with boreal subdominant
        boreal_evergreen = BorealEvergreen(50.0, 500.0, -3.0)
        result_boreal = assign_biome(temperate_grass, boreal_evergreen, Default(), 600.0, 900.0, 10.0, 5.0, biome_pfts)
        @test isa(result_boreal, SteppeTundra)
        
        # Test with sufficient NPP and high GDD0
        set_characteristic(temperate_grass, :npp, 150.0)
        result_high_gdd = assign_biome(temperate_grass, Default(), Default(), 1000.0, 1200.0, 15.0, 10.0, biome_pfts)
        @test isa(result_high_gdd, TemperateGrassland)
        
        # Test with sufficient NPP and low GDD0
        result_low_gdd = assign_biome(temperate_grass, Default(), Default(), 600.0, 900.0, 5.0, 0.0, biome_pfts)
        @test isa(result_low_gdd, SteppeTundra)
        
        # Test C4 Tropical Grass
        tropical_grass = C4TropicalGrass(10.0, 800.0, 24.0)
        
        # Test with high NPP
        set_characteristic(tropical_grass, :npp, 200.0)
        result_tropical = assign_biome(tropical_grass, Default(), Default(), 2000.0, 2500.0, 22.0, 18.0, biome_pfts)
        @test isa(result_tropical, TropicalGrassland)
        
        # Test with low NPP
        set_characteristic(tropical_grass, :npp, 80.0)
        result_tropical_low = assign_biome(tropical_grass, Default(), Default(), 2000.0, 2500.0, 22.0, 18.0, biome_pfts)
        @test isa(result_tropical_low, Desert)
    end
    
    @testset "Tundra PFT Assignment Tests" begin
        biome_pfts = BiomeClassification(60.0, 300.0, -15.0)
        
        # Test Lichen Forb
        lichen_forb = LichenForb(60.0, 300.0, -15.0)
        result_lichen = assign_biome(lichen_forb, Default(), Default(), 100.0, 150.0, -25.0, -30.0, biome_pfts)
        @test isa(result_lichen, Barren)
        
        # Test Tundra Shrubs
        tundra_shrubs = TundraShrubs(60.0, 300.0, -15.0)
        
        # Test very low GDD0
        result_very_cold = assign_biome(tundra_shrubs, Default(), Default(), 150.0, 200.0, -30.0, -35.0, biome_pfts)
        @test isa(result_very_cold, CushionForbsLichenMoss)
        
        # Test medium GDD0
        result_medium = assign_biome(tundra_shrubs, Default(), Default(), 350.0, 450.0, -20.0, -25.0, biome_pfts)
        @test isa(result_medium, ProstateShrubTundra)
        
        # Test higher GDD0
        result_higher = assign_biome(tundra_shrubs, Default(), Default(), 600.0, 750.0, -15.0, -20.0, biome_pfts)
        @test isa(result_higher, DwarfShrubTundra)
        
        # Test Cold Herbaceous
        cold_herbaceous = ColdHerbaceous(60.0, 300.0, -15.0)
        result_cold_herb = assign_biome(cold_herbaceous, Default(), Default(), 200.0, 300.0, -25.0, -30.0, biome_pfts)
        @test isa(result_cold_herb, SteppeTundra)
    end
    
    @testset "Default and None PFT Assignment Tests" begin
        biome_pfts = BiomeClassification(30.0, 500.0, 15.0)
        
        # Test Default PFT with different woody dominants
        default_pft = Default()
        
        # Test with tropical woody dominant and high LAI
        tropical_evergreen = TropicalEvergreen(50.0, 1500.0, 26.0)
        set_characteristic(tropical_evergreen, :lai, 5.0)
        result_tropical_high_lai = assign_biome(default_pft, Default(), tropical_evergreen, 1500.0, 2000.0, 25.0, 20.0, biome_pfts)
        @test isa(result_tropical_high_lai, TropicalSavanna)
        
        # Test with tropical woody dominant and low LAI
        set_characteristic(tropical_evergreen, :lai, 2.0)
        result_tropical_low_lai = assign_biome(default_pft, Default(), tropical_evergreen, 1500.0, 2000.0, 25.0, 20.0, biome_pfts)
        @test isa(result_tropical_low_lai, TropicalXerophyticShrubland)
        
        # Test with temperate broadleaved evergreen
        temperate_be = TemperateBroadleavedEvergreen(35.0, 1000.0, 18.0)
        result_tbe = assign_biome(default_pft, Default(), temperate_be, 1200.0, 1800.0, 10.0, 5.0, biome_pfts)
        @test isa(result_tbe, TemperateSclerophyllWoodland)
        
        # Test with temperate deciduous
        temperate_dec = TemperateDeciduous(40.0, 800.0, 10.0)
        result_td = assign_biome(default_pft, Default(), temperate_dec, 1200.0, 1800.0, 5.0, 0.0, biome_pfts)
        @test isa(result_td, TemperateBroadleavedSavanna)
        
        # Test with cool conifer
        cool_conifer = CoolConifer(30.0, 600.0, 12.0)
        result_cc = assign_biome(default_pft, Default(), cool_conifer, 1000.0, 1500.0, 2.0, -3.0, biome_pfts)
        @test isa(result_cc, OpenConiferWoodland)
        
        # Test with boreal evergreen
        boreal_evergreen = BorealEvergreen(50.0, 500.0, -3.0)
        result_be = assign_biome(default_pft, Default(), boreal_evergreen, 600.0, 800.0, -15.0, -20.0, biome_pfts)
        @test isa(result_be, BorealParkland)
        
        # Test with no woody dominant
        result_no_woody = assign_biome(default_pft, Default(), Default(), 800.0, 1200.0, 10.0, 5.0, biome_pfts)
        @test isa(result_no_woody, Barren)
        
        # Test None PFT
        none_pft = None()
        result_none = assign_biome(none_pft, Default(), Default(), 1000.0, 1500.0, 15.0, 10.0, biome_pfts)
        @test isa(result_none, Barren)
    end
    
    @testset "Type Consistency Tests" begin
        biome_pfts = BiomeClassification(40.0, 800.0, 15.0)
        tropical_evergreen = TropicalEvergreen(50.0, 1500.0, 26.0)
        set_characteristic(tropical_evergreen, :npp, 300.0)
        
        # Test with Float32 parameters
        result_f32 = assign_biome(tropical_evergreen, Default(), Default(), 
                                 Float32(2000.0), Float32(3000.0), Float32(25.0), Float32(15.0), biome_pfts)
        @test isa(result_f32, AbstractBiome)
        @test isa(result_f32, TropicalEvergreenForest)
        
        # Test with Float64 parameters (default)
        result_f64 = assign_biome(tropical_evergreen, Default(), Default(), 
                                 2000.0, 3000.0, 25.0, 15.0, biome_pfts)
        @test isa(result_f64, AbstractBiome)
        @test isa(result_f64, TropicalEvergreenForest)
        
        # Results should be the same type of biome regardless of input numeric type
        @test typeof(result_f32) == typeof(result_f64)
    end
    
    @testset "Threshold Boundary Tests" begin
        biome_pfts = BiomeClassification(40.0, 800.0, 15.0)
        
        # Test NPP threshold boundary (100.0)
        temperate_dec = TemperateDeciduous(40.0, 800.0, 10.0)
        
        # Exactly at threshold
        set_characteristic(temperate_dec, :npp, 100.0)
        result_at_threshold = assign_biome(temperate_dec, Default(), Default(), 1200.0, 1800.0, 0.0, -5.0, biome_pfts)
        @test isa(result_at_threshold, Desert)
        
        # Just above threshold
        set_characteristic(temperate_dec, :npp, 100.1)
        result_above_threshold = assign_biome(temperate_dec, Default(), Default(), 1200.0, 1800.0, 0.0, -5.0, biome_pfts)
        @test isa(result_above_threshold, CoolMixedForest)
        
        # Just below threshold
        set_characteristic(temperate_dec, :npp, 99.9)
        result_below_threshold = assign_biome(temperate_dec, Default(), Default(), 1200.0, 1800.0, 0.0, -5.0, biome_pfts)
        @test isa(result_below_threshold, Desert)
        
        # Test GDD thresholds for boreal evergreen
        boreal_evergreen = BorealEvergreen(50.0, 500.0, -3.0)
        
        # At GDD5 threshold (900.0) and TCM threshold (-19.0)
        result_gdd_threshold = assign_biome(boreal_evergreen, Default(), Default(), 800.0, 1200.0, -19.0, -15.0, biome_pfts)
        @test isa(result_gdd_threshold, ColdMixedForest) # Above threshold
        
        result_gdd_below = assign_biome(boreal_evergreen, Default(), Default(), 800.0, 700.0, -18.9, -25.0, biome_pfts)
        @test isa(result_gdd_below, ColdMixedForest) # Below threshold
    end
    
    @testset "Edge Cases and Error Handling" begin
        biome_pfts = BiomeClassification(40.0, 800.0, 15.0)
        
        # Test with extreme climate values
        tropical_evergreen = TropicalEvergreen(50.0, 1500.0, 26.0)
        set_characteristic(tropical_evergreen, :npp, 300.0)
        
        # Extreme cold
        result_extreme_cold = assign_biome(tropical_evergreen, Default(), Default(), 
                                         -1000.0, -500.0, -50.0, -60.0, biome_pfts)
        @test isa(result_extreme_cold, TropicalEvergreenForest) # Should still work based on NPP
        
        # Extreme hot
        result_extreme_hot = assign_biome(tropical_evergreen, Default(), Default(), 
                                        5000.0, 8000.0, 50.0, 40.0, biome_pfts)
        @test isa(result_extreme_hot, TropicalEvergreenForest)
        
        # Test with nothing/missing PFTs in subdominant positions
        @test_throws MethodError assign_biome(tropical_evergreen, nothing, nothing, 
        2000.0, 3000.0, 25.0, 15.0, biome_pfts)
    end
end