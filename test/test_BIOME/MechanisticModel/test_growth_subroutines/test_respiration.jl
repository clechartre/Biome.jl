using Test

@testset "New Assign Biome Tests" begin
    
    @testset "Mock Assign Biome Test" begin
        # Create PFT classification with default constructor
        pft_classification = PFTClassification()
        
        # Test the mock function
        result = mock_assign_biome(nothing, nothing, nothing, 0.0, 0.0, 0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, pft_classification)
        @test result == 1
        @test typeof(result) == Int
    end
    
    @testset "Tropical Evergreen Assignment Tests" begin
        # Create test PFTs and biome classification
        biome_pfts = PFTClassification()
        tropical_evergreen = TropicalEvergreen()
        
        # Test with high NPP - should return TropicalEvergreenForest
        tropical_evergreen.characteristics.npp = 500.0
        result = assign_biome(tropical_evergreen, Default(), Default(), 2000.0, 3000.0, 25.0, 15.0, biome_pfts)
        @test isa(result, TropicalEvergreenForest)
        
        # Test with low NPP - should return Desert
        tropical_evergreen.characteristics.npp = 50.0
        result_low = assign_biome(tropical_evergreen, Default(), Default(), 2000.0, 3000.0, 25.0, 15.0, biome_pfts)
        @test isa(result_low, Desert)
    end
    
    @testset "Tropical Drought Deciduous Assignment Tests" begin
        biome_pfts = PFTClassification()
        tropical_drought = TropicalDroughtDeciduous()
        
        # Test with high NPP and long green season
        tropical_drought.characteristics.npp = 400.0
        tropical_drought.characteristics.greendays = 320
        result_long = assign_biome(tropical_drought, Default(), Default(), 1800.0, 2500.0, 22.0, 12.0, biome_pfts)
        @test isa(result_long, TropicalEvergreenForest)
        
        # Test with medium green season
        tropical_drought.characteristics.greendays = 280
        result_medium = assign_biome(tropical_drought, Default(), Default(), 1800.0, 2500.0, 22.0, 12.0, biome_pfts)
        @test isa(result_medium, TropicalSemiDeciduousForest)
        
        # Test with short green season
        tropical_drought.characteristics.greendays = 200
        result_short = assign_biome(tropical_drought, Default(), Default(), 1800.0, 2500.0, 22.0, 12.0, biome_pfts)
        @test isa(result_short, TropicalDeciduousForestWoodland)
        
        # Test with low NPP
        tropical_drought.characteristics.npp = 80.0
        result_low_npp = assign_biome(tropical_drought, Default(), Default(), 1800.0, 2500.0, 22.0, 12.0, biome_pfts)
        @test isa(result_low_npp, Desert)
    end
    
    @testset "Temperate Broadleaved Evergreen Assignment Tests" begin
        biome_pfts = PFTClassification()
        temperate_be = TemperateBroadleavedEvergreen()
        
        # Test with high NPP
        temperate_be.characteristics.npp = 300.0
        result_high = assign_biome(temperate_be, Default(), Default(), 1500.0, 2000.0, 5.0, -5.0, biome_pfts)
        @test isa(result_high, WarmMixedForest)
        
        # Test with low NPP
        temperate_be.characteristics.npp = 80.0
        result_low = assign_biome(temperate_be, Default(), Default(), 1500.0, 2000.0, 5.0, -5.0, biome_pfts)
        @test isa(result_low, Desert)
    end
    
    @testset "Temperate Deciduous Assignment Tests" begin
        biome_pfts = PFTClassification()
        temperate_dec = TemperateDeciduous()
        
        # Test with high NPP and boreal evergreen present
        temperate_dec.characteristics.npp = 250.0
        
        # Set boreal evergreen as present
        boreal_idx = findfirst(pft -> pft.characteristics.name == "BorealEvergreen", biome_pfts.pft_list)
        if boreal_idx !== nothing
            biome_pfts.pft_list[boreal_idx].characteristics.present = true
        end
        
        # Test cold conditions
        result_cold = assign_biome(temperate_dec, Default(), Default(), 1200.0, 1800.0, -20.0, -25.0, biome_pfts)
        @test isa(result_cold, ColdMixedForest)
        
        # Test warmer conditions
        result_warm = assign_biome(temperate_dec, Default(), Default(), 1200.0, 1800.0, -10.0, -15.0, biome_pfts)
        @test isa(result_warm, CoolMixedForest)
        
        # Test with temperate broadleaved evergreen present and high GDD5
        tbe_idx = findfirst(pft -> pft.characteristics.name == "TemperateBroadleavedEvergreen", biome_pfts.pft_list)
        if tbe_idx !== nothing && boreal_idx !== nothing
            biome_pfts.pft_list[tbe_idx].characteristics.present = true
            biome_pfts.pft_list[boreal_idx].characteristics.present = false
        end
        result_tbe = assign_biome(temperate_dec, Default(), Default(), 1200.0, 3500.0, 5.0, 0.0, biome_pfts)
        @test isa(result_tbe, WarmMixedForest)
        
        # Test fallback to temperate deciduous forest
        if tbe_idx !== nothing && boreal_idx !== nothing
            biome_pfts.pft_list[tbe_idx].characteristics.present = false
            biome_pfts.pft_list[boreal_idx].characteristics.present = false
        end
        result_fallback = assign_biome(temperate_dec, Default(), Default(), 1200.0, 2000.0, 0.0, -5.0, biome_pfts)
        @test isa(result_fallback, TemperateDeciduousForest)
        
        # Test with low NPP
        temperate_dec.characteristics.npp = 70.0
        result_low_npp = assign_biome(temperate_dec, Default(), Default(), 1200.0, 2000.0, 0.0, -5.0, biome_pfts)
        @test isa(result_low_npp, Desert)
    end
    
    @testset "Cool Conifer Assignment Tests" begin
        biome_pfts = PFTClassification()
        cool_conifer = CoolConifer()
        
        # Test with high NPP and temperate broadleaved evergreen present
        cool_conifer.characteristics.npp = 200.0
        tbe_idx = findfirst(pft -> pft.characteristics.name == "TemperateBroadleavedEvergreen", biome_pfts.pft_list)
        if tbe_idx !== nothing
            biome_pfts.pft_list[tbe_idx].characteristics.present = true
        end
        
        result_tbe = assign_biome(cool_conifer, Default(), Default(), 1000.0, 1500.0, 2.0, -3.0, biome_pfts)
        @test isa(result_tbe, WarmMixedForest)
        
        # Test with temperate deciduous subdominant
        if tbe_idx !== nothing
            biome_pfts.pft_list[tbe_idx].characteristics.present = false
        end
        temperate_dec = TemperateDeciduous()
        result_temp_dec = assign_biome(cool_conifer, temperate_dec, Default(), 1000.0, 1500.0, 2.0, -3.0, biome_pfts)
        @test isa(result_temp_dec, TemperateConiferForest)
        
        # Test with boreal deciduous subdominant
        boreal_dec = BorealDeciduous()
        result_boreal_dec = assign_biome(cool_conifer, boreal_dec, Default(), 1000.0, 1500.0, -5.0, -10.0, biome_pfts)
        @test isa(result_boreal_dec, ColdMixedForest)
        
        # Test fallback
        result_fallback = assign_biome(cool_conifer, Default(), Default(), 1000.0, 1500.0, 2.0, -3.0, biome_pfts)
        @test isa(result_fallback, TemperateConiferForest)
        
        # Test with low NPP
        cool_conifer.characteristics.npp = 60.0
        result_low_npp = assign_biome(cool_conifer, Default(), Default(), 1000.0, 1500.0, 2.0, -3.0, biome_pfts)
        @test isa(result_low_npp, Desert)
    end
    
    @testset "Boreal Evergreen Assignment Tests" begin
        biome_pfts = PFTClassification()
        boreal_evergreen = BorealEvergreen()
        
        # Test warm conditions with temperate deciduous present
        temperate_dec_idx = findfirst(pft -> pft.characteristics.name == "TemperateDeciduous", biome_pfts.pft_list)
        if temperate_dec_idx !== nothing
            biome_pfts.pft_list[temperate_dec_idx].characteristics.present = true
        end
        
        result_warm = assign_biome(boreal_evergreen, Default(), Default(), 800.0, 1200.0, -10.0, -15.0, biome_pfts)
        @test isa(result_warm, CoolMixedForest)
        
        # Test warm conditions without temperate deciduous
        if temperate_dec_idx !== nothing
            biome_pfts.pft_list[temperate_dec_idx].characteristics.present = false
        end
        result_warm_no_td = assign_biome(boreal_evergreen, Default(), Default(), 800.0, 1200.0, -10.0, -15.0, biome_pfts)
        @test isa(result_warm_no_td, CoolConiferForest)
        
        # Test cold conditions with temperate deciduous present
        if temperate_dec_idx !== nothing
            biome_pfts.pft_list[temperate_dec_idx].characteristics.present = true
        end
        result_cold = assign_biome(boreal_evergreen, Default(), Default(), 600.0, 800.0, -25.0, -30.0, biome_pfts)
        @test isa(result_cold, ColdMixedForest)
        
        # Test cold conditions without temperate deciduous
        if temperate_dec_idx !== nothing
            biome_pfts.pft_list[temperate_dec_idx].characteristics.present = false
        end
        result_cold_no_td = assign_biome(boreal_evergreen, Default(), Default(), 600.0, 800.0, -25.0, -30.0, biome_pfts)
        @test isa(result_cold_no_td, EvergreenTaigaMontaneForest)
    end
    
    @testset "Boreal Deciduous Assignment Tests" begin
        biome_pfts = PFTClassification()
        boreal_deciduous = BorealDeciduous()
        
        # Test with temperate deciduous subdominant
        temperate_dec = TemperateDeciduous()
        result_temp_dec = assign_biome(boreal_deciduous, temperate_dec, Default(), 700.0, 1000.0, -8.0, -12.0, biome_pfts)
        @test isa(result_temp_dec, TemperateDeciduousForest)
        
        # Test with cool conifer subdominant
        cool_conifer = CoolConifer()
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
        biome_pfts = PFTClassification()
        woody_desert = WoodyDesert()
        
        # Test with high NPP and high LAI subdominant
        woody_desert.characteristics.npp = 150.0
        subdominant = Default()
        subdominant.characteristics.lai = 2.0
        
        # Test warm conditions (tmin >= 0)
        result_warm = assign_biome(woody_desert, subdominant, Default(), 400.0, 600.0, 20.0, 5.0, biome_pfts)
        @test isa(result_warm, TropicalXerophyticShrubland)
        
        # Test cold conditions (tmin < 0)
        result_cold = assign_biome(woody_desert, subdominant, Default(), 400.0, 600.0, -5.0, -10.0, biome_pfts)
        @test isa(result_cold, TemperateXerophyticShrubland)
        
        # Test with low LAI subdominant
        subdominant.characteristics.lai = 0.5
        result_low_lai = assign_biome(woody_desert, subdominant, Default(), 400.0, 600.0, 20.0, 5.0, biome_pfts)
        @test isa(result_low_lai, Desert)
        
        # Test with low NPP
        woody_desert.characteristics.npp = 80.0
        result_low_npp = assign_biome(woody_desert, subdominant, Default(), 400.0, 600.0, 20.0, 5.0, biome_pfts)
        @test isa(result_low_npp, Desert)
    end
    
    @testset "Grass PFT Assignment Tests" begin
        biome_pfts = PFTClassification()
        
        # Test C3C4 Temperate Grass
        temperate_grass = C3C4TemperateGrass()
        
        # Test with low NPP and suitable subdominant
        temperate_grass.characteristics.npp = 80.0
        subdominant = Default()
        result_low_npp = assign_biome(temperate_grass, subdominant, Default(), 600.0, 900.0, 10.0, 5.0, biome_pfts)
        @test isa(result_low_npp, Desert)
        
        # Test with boreal subdominant
        boreal_evergreen = BorealEvergreen()
        result_boreal = assign_biome(temperate_grass, boreal_evergreen, Default(), 600.0, 900.0, 10.0, 5.0, biome_pfts)
        @test isa(result_boreal, SteppeTundra)
        
        # Test with sufficient NPP and high GDD0
        temperate_grass.characteristics.npp = 150.0
        result_high_gdd = assign_biome(temperate_grass, Default(), Default(), 1000.0, 1200.0, 15.0, 10.0, biome_pfts)
        @test isa(result_high_gdd, TemperateGrassland)
        
        # Test with sufficient NPP and low GDD0
        result_low_gdd = assign_biome(temperate_grass, Default(), Default(), 600.0, 900.0, 5.0, 0.0, biome_pfts)
        @test isa(result_low_gdd, SteppeTundra)
        
        # Test C4 Tropical Grass
        tropical_grass = C4TropicalGrass()
        
        # Test with high NPP
        tropical_grass.characteristics.npp = 200.0
        result_tropical = assign_biome(tropical_grass, Default(), Default(), 2000.0, 2500.0, 22.0, 18.0, biome_pfts)
        @test isa(result_tropical, TropicalGrassland)
        
        # Test with low NPP
        tropical_grass.characteristics.npp = 80.0
        result_tropical_low = assign_biome(tropical_grass, Default(), Default(), 2000.0, 2500.0, 22.0, 18.0, biome_pfts)
        @test isa(result_tropical_low, Desert)
    end
    
    @testset "Tundra PFT Assignment Tests" begin
        biome_pfts = PFTClassification()
        
        # Test Lichen Forb
        lichen_forb = LichenForb()
        result_lichen = assign_biome(lichen_forb, Default(), Default(), 100.0, 150.0, -25.0, -30.0, biome_pfts)
        @test isa(result_lichen, Barren)
        
        # Test Tundra Shrubs
        tundra_shrubs = TundraShrubs()
        
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
        cold_herbaceous = ColdHerbaceous()
        result_cold_herb = assign_biome(cold_herbaceous, Default(), Default(), 200.0, 300.0, -25.0, -30.0, biome_pfts)
        @test isa(result_cold_herb, SteppeTundra)
    end
    
    @testset "Default and None PFT Assignment Tests" begin
        biome_pfts = PFTClassification()
        
        # Test Default PFT with different woody dominants
        default_pft = Default()
        
        # Test with tropical woody dominant and high LAI
        tropical_evergreen = TropicalEvergreen()
        tropical_evergreen.characteristics.lai = 5.0
        result_tropical_high_lai = assign_biome(default_pft, Default(), tropical_evergreen, 1500.0, 2000.0, 25.0, 20.0, biome_pfts)
        @test isa(result_tropical_high_lai, TropicalSavanna)
        
        # Test with tropical woody dominant and low LAI
        tropical_evergreen.characteristics.lai = 2.0
        result_tropical_low_lai = assign_biome(default_pft, Default(), tropical_evergreen, 1500.0, 2000.0, 25.0, 20.0, biome_pfts)
        @test isa(result_tropical_low_lai, TropicalXerophyticShrubland)
        
        # Test with temperate broadleaved evergreen
        temperate_be = TemperateBroadleavedEvergreen()
        result_tbe = assign_biome(default_pft, Default(), temperate_be, 1200.0, 1800.0, 10.0, 5.0, biome_pfts)
        @test isa(result_tbe, TemperateSclerophyllWoodland)
        
        # Test with temperate deciduous
        temperate_dec = TemperateDeciduous()
        result_td = assign_biome(default_pft, Default(), temperate_dec, 1200.0, 1800.0, 5.0, 0.0, biome_pfts)
        @test isa(result_td, TemperateBroadleavedSavanna)
        
        # Test with cool conifer
        cool_conifer = CoolConifer()
        result_cc = assign_biome(default_pft, Default(), cool_conifer, 1000.0, 1500.0, 2.0, -3.0, biome_pfts)
        @test isa(result_cc, OpenConiferWoodland)
        
        # Test with boreal evergreen
        boreal_evergreen = BorealEvergreen()
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
        biome_pfts = PFTClassification()
        tropical_evergreen = TropicalEvergreen()
        tropical_evergreen.characteristics.npp = 300.0
        
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
        biome_pfts = PFTClassification()
        
        # Test NPP threshold boundary (100.0)
        temperate_dec = TemperateDeciduous()
        
        # Exactly at threshold
        temperate_dec.characteristics.npp = 100.0
        result_at_threshold = assign_biome(temperate_dec, Default(), Default(), 1200.0, 1800.0, 0.0, -5.0, biome_pfts)
        @test isa(result_at_threshold, Desert)
        
        # Just above threshold
        temperate_dec.characteristics.npp = 100.1
        result_above_threshold = assign_biome(temperate_dec, Default(), Default(), 1200.0, 1800.0, 0.0, -5.0, biome_pfts)
        @test isa(result_above_threshold, CoolMixedForest)
        
        # Just below threshold
        temperate_dec.characteristics.npp = 99.9
        result_below_threshold = assign_biome(temperate_dec, Default(), Default(), 1200.0, 1800.0, 0.0, -5.0, biome_pfts)
        @test isa(result_below_threshold, Desert)
        
        # Test GDD thresholds for boreal evergreen
        boreal_evergreen = BorealEvergreen()
        
        # At GDD5 threshold (900.0) and TCM threshold (-19.0)
        result_gdd_threshold = assign_biome(boreal_evergreen, Default(), Default(), 800.0, 1200.0, -19.0, -15.0, biome_pfts)
        @test isa(result_gdd_threshold, ColdMixedForest) # Above threshold
        
        result_gdd_below = assign_biome(boreal_evergreen, Default(), Default(), 800.0, 700.0, -18.9, -25.0, biome_pfts)
        @test isa(result_gdd_below, ColdMixedForest) # Below threshold
    end
    
    @testset "Edge Cases and Error Handling" begin
        biome_pfts = PFTClassification()
        
        # Test with extreme climate values
        tropical_evergreen = TropicalEvergreen()
        tropical_evergreen.characteristics.npp = 300.0
        
        # Extreme cold
        result_extreme_cold = assign_biome(tropical_evergreen, Default(), Default(), 
                                         -1000.0, -500.0, -50.0, -60.0, biome_pfts)
        @test isa(result_extreme_cold, TropicalEvergreenForest) # Should still work based on NPP
        
        # Extreme hot
        result_extreme_hot = assign_biome(tropical_evergreen, Default(), Default(), 
                                        5000.0, 8000.0, 50.0, 40.0, biome_pfts)
        @test isa(result_extreme_hot, TropicalEvergreenForest)
        
        # Test with Default PFTs in subdominant positions (should work)
        result_default_subdominant = assign_biome(tropical_evergreen, Default(), Default(), 
                                                2000.0, 3000.0, 25.0, 15.0, biome_pfts)
        @test isa(result_default_subdominant, TropicalEvergreenForest)
    end
end