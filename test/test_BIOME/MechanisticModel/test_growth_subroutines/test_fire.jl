using Test
using Biome

@testset "Fire Tests" begin
    
    @testset "Positive Test - Normal fire conditions" begin
        # Create PFTs with different fire thresholds
        # Assuming these PFTs have threshold characteristics defined
        pftlist = BIOME4.PFTClassification()

        set_characteristic!(pftlist, "TropicalEvergreen", :threshold, 0.25)
        set_characteristic!(pftlist, "C3C4TemperateGrass", :threshold, 0.33)
        set_characteristic!(pftlist, "C3C4WoodyDesert", :threshold, 0.4)

        tropical_forest = pftlist.pft_list[findfirst(pft -> pft.characteristics.name == "TropicalEvergreen", pftlist.pft_list)]
        temperate_grass = pftlist.pft_list[findfirst(pft -> pft.characteristics.name == "C3C4TemperateGrass", pftlist.pft_list)]
        desert_shrub = pftlist.pft_list[findfirst(pft -> pft.characteristics.name == "C3C4WoodyDesert", pftlist.pft_list)]  
        
        # Test with typical seasonal wetness pattern (wet winter, dry summer)
        wet_seasonal = vcat(
            fill(0.6, 90),   # Jan-Mar: wet season
            fill(0.4, 90),   # Apr-Jun: moderate
            fill(0.1, 90),   # Jul-Sep: dry season
            fill(0.5, 95)    # Oct-Dec: recovery
        )
        
        lai_typical = 3.0
        npp_typical = 1500.0
        
        # Test tropical forest (high threshold = less fire-prone)
        firedays_tropical = fire(wet_seasonal, tropical_forest, lai_typical, npp_typical)
        @test firedays_tropical >= 0.0
        @test firedays_tropical <= 365.0
        @test isfinite(firedays_tropical)
        
        # Test temperate grassland (moderate threshold)
        firedays_grass = fire(wet_seasonal, temperate_grass, lai_typical, npp_typical)
        @test firedays_grass >= 0.0
        @test firedays_grass <= 365.0
        @test isfinite(firedays_grass)
        
        # Grassland should have more fire days than forest (lower threshold)
        @test firedays_grass >= firedays_tropical
        
        # Test desert (low threshold = more fire-prone)
        firedays_desert = fire(wet_seasonal, desert_shrub, lai_typical, npp_typical)
        @test firedays_desert >= 0.0
        @test firedays_desert <= 365.0
        @test isfinite(firedays_desert)
        
        # Desert should have most fire days (lowest threshold)
        @test firedays_desert >= firedays_grass
    end
    
    @testset "Mathematical Correctness Tests" begin
        # Create test PFT with known threshold
        pftlist = BIOME4.PFTClassification()
        set_characteristic!(pftlist, "C3C4WoodyDesert", :threshold, 0.3)
        test_pft = pftlist.pft_list[findfirst(pft -> pft.characteristics.name == "C3C4WoodyDesert", pftlist.pft_list)]
        
        lai_test = 2.0
        npp_test = 1200.0
        
        # Test with wetness all below threshold (should be max fire days)
        wet_dry = fill(0.1, 365)  # All days below threshold
        firedays_dry = fire(wet_dry, test_pft, lai_test, npp_test)
        
        @test firedays_dry ≈ 365.0 atol=1e-10  # All days should be fire days
        
        # Test with wetness all above threshold + 0.05 (should be no fire days)
        wet_wet = fill(0.4, 365)  # All days above threshold + 0.05
        firedays_wet = fire(wet_wet, test_pft, lai_test, npp_test)
        
        @test firedays_wet ≈ 0.0 atol=1e-10  # No fire days
        
        # Test with wetness exactly at threshold
        wet_threshold = fill(0.3, 365)  # All days at threshold
        firedays_threshold = fire(wet_threshold, test_pft, lai_test, npp_test)
        
        @test firedays_threshold ≈ 365.0 atol=1e-10  # At threshold = fire days
        
        # Test with wetness in the exponential decay range
        wet_decay = fill(0.32, 365)  # Between threshold and threshold + 0.05
        firedays_decay = fire(wet_decay, test_pft, lai_test, npp_test)
        
        # Should be between 0 and 365, calculated as 1.0 / exp(0.32 - 0.3) per day
        expected_burn_per_day = 1.0 / exp(0.32 - 0.3)
        expected_firedays = 365.0 * expected_burn_per_day
        @test firedays_decay ≈ expected_firedays atol=1e-10
        
        # Test NPP adjustment for low productivity
        npp_low = 500.0  # Below 1000 threshold
        firedays_low_npp = fire(wet_dry, test_pft, lai_test, npp_low)
        
        # Should be scaled by npp/1000
        expected_firedays_scaled = 365.0 * (npp_low / 1000.0)
        @test firedays_low_npp ≈ expected_firedays_scaled atol=1e-10
    end
    
    @testset "Wetday and Dryday Tests" begin
        # These tests would need the function to return these values
        # Since the current function only returns the modified PFT,
        # we'll test the internal logic by creating specific patterns
        
        pftlist = BIOME4.PFTClassification()
        set_characteristic!(pftlist, "TemperateDeciduous", :threshold, 0.25)
        test_pft = pftlist.pft_list[findfirst(pft -> pft.characteristics.name == "TemperateDeciduous", pftlist.pft_list)]
        
        # Test with known min/max wetness
        wet_range = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0] 
        wet_pattern = repeat(wet_range, 37)[1:365]  # Cycle through range
        
        # Function should handle the full range without errors
        firedays_range = fire(wet_pattern, test_pft, 2.5, 1500.0)
        @test isfinite(firedays_range)
        @test firedays_range >= 0.0
        @test firedays_range <= 365.0
    end
    
    @testset "Edge Cases" begin
        pftlist = BIOME4.PFTClassification()
        # Change the characteristic
        set_characteristic!(pftlist, "TemperateDeciduous", :threshold, 0.35)
        test_pft = pftlist.pft_list[findfirst(pft -> pft.characteristics.name == "TemperateDeciduous", pftlist.pft_list)]
        
        # Test with zero LAI
        wet_normal = fill(0.2, 365)
        firedays_zero_lai = fire(wet_normal, test_pft, 0.0, 1000.0)
        
        @test isfinite(firedays_zero_lai)
        @test firedays_zero_lai >= 0.0
        
        # Test with very high LAI
        firedays_high_lai = fire(wet_normal, test_pft, 20.0, 1000.0)
        
        @test isfinite(firedays_high_lai)
        @test firedays_high_lai >= 0.0
        
        # Test with zero NPP
        firedays_zero_npp = fire(wet_normal, test_pft, 3.0, 0.0)
        
        @test firedays_zero_npp ≈ 0.0 atol=1e-10  # Zero NPP should result in zero fire days
        
        # Test with very high NPP
        firedays_high_npp = fire(wet_normal, test_pft, 3.0, 5000.0)
        
        @test isfinite(firedays_high_npp)
        @test firedays_high_npp >= 0.0
        
        # Test with extreme wetness values
        wet_extreme_dry = fill(-0.1, 365)  # Negative wetness
        firedays_extreme_dry = fire(wet_extreme_dry, test_pft, 3.0, 1200.0)
        
        @test firedays_extreme_dry ≈ 365.0 atol=1e-10  # All days should be fire days
        
        wet_extreme_wet = fill(2.0, 365)  # Very high wetness
        firedays_extreme_wet = fire(wet_extreme_wet, test_pft, 3.0, 1200.0)
        
        @test firedays_extreme_wet ≈ 0.0 atol=1e-10  # No fire days
    end
    
    @testset "Realistic Scenarios" begin
        # Test drought year scenario
        pftlist = BIOME4.PFTClassification()
        # Change the characteristic
        set_characteristic!(pftlist, "C3C4TemperateGrass", :threshold, 0.28)
        grassland = pftlist.pft_list[findfirst(pft -> pft.characteristics.name == "C3C4TemperateGrass", pftlist.pft_list)]
        
        # Drought year: mostly dry with occasional wet spells
        wet_drought = vcat(
            fill(0.1, 120),  # Extended dry period
            fill(0.6, 30),   # Brief wet period
            fill(0.15, 150), # More dry
            fill(0.4, 65)    # Moderate end
        )
        
        firedays_drought = fire(wet_drought, grassland, 1.5, 800.0)
        
        @test firedays_drought > 200.0  # Should have many fire days
        @test firedays_drought <= 365.0
        
        # Test wet year scenario
        wet_wet_year = vcat(
            fill(0.8, 100),  # Very wet start
            fill(0.5, 165),  # Moderate middle
            fill(0.7, 100)   # Wet end
        )
        
        firedays_wet_year = fire(wet_wet_year, grassland, 1.5, 800.0)
        
        @test firedays_wet_year < 50.0  # Should have few fire days
        @test firedays_wet_year >= 0.0
        
        # Drought year should have more fire days than wet year
        @test firedays_drought > firedays_wet_year
    end
    
    @testset "Error Conditions" begin
        pftlist = BIOME4.PFTClassification()
        # Change the characteristic
        set_characteristic!(pftlist, "BorealEvergreen", :threshold, 0.32)
        test_pft = pftlist.pft_list[findfirst(pft -> pft.characteristics.name == "BorealEvergreen", pftlist.pft_list)]
        
        # Test with wrong wetness: too short, too long is fine, we only take the first 365
        @test_throws BoundsError fire(fill(0.3, 300), test_pft, 2.0, 1000.0)  
        # Test with empty vector
        @test_throws BoundsError fire(Float64[], test_pft, 2.0, 1000.0)
    end
    
    @testset "Type Consistency Tests" begin
        pftlist = BIOME4.PFTClassification()
        # Change the characteristic
        set_characteristic!(pftlist, "CoolConifer", :threshold, 0.3)
        test_pft = pftlist.pft_list[findfirst(pft -> pft.characteristics.name == "CoolConifer", pftlist.pft_list)]
        
        # Test with Float64
        wet_f64 = fill(Float64(0.25), 365)
        lai_f64 = Float64(2.5)
        npp_f64 = Float64(1100.0)
        firedays_f64 = fire(wet_f64, test_pft, lai_f64, npp_f64)
        @test typeof(firedays_f64) == Float64
        @test isfinite(firedays_f64)
        
    end
    
    @testset "Fire Fraction and Burn Fraction Logic" begin
        # Test the internal calculations for fire fraction and burn fraction
        pftlist = BIOME4.PFTClassification()
        # Change the characteristic
        set_characteristic!(pftlist, "TropicalDroughtDeciduous", :threshold, 0.25)
        test_pft = pftlist.pft_list[findfirst(pft -> pft.characteristics.name == "TropicalDroughtDeciduous", pftlist.pft_list)]

        # Create pattern with known fire days
        wet_half_fire = vcat(fill(0.1, 182), fill(0.5, 183))  # Half dry, half wet
        
        result_half = fire(wet_half_fire, test_pft, 4.0, 2000.0)
        
        # Should be approximately 182 fire days (half the year)
        @test result_half ≈ 182.0 atol=1.0
        
        # Test that the function is deterministic
        result_half2 = fire(wet_half_fire, test_pft, 4.0, 2000.0)
        
        @test result_half == result_half2
    end
end