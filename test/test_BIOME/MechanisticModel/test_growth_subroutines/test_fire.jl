using Test

@testset "Fire Tests" begin
    
    @testset "Positive Test - Normal fire conditions" begin
        # Create PFTs with different fire thresholds
        # Assuming these PFTs have threshold characteristics defined
        tropical_forest = TropicalEvergreen(10.0, 2000.0, 25.0)
        temperate_grass = C3C4TemperateGrass(5.0, 800.0, 15.0)
        desert_shrub = WoodyDesert(15.0, 200.0, 20.0)
        
        # Set fire thresholds
        set_characteristic(tropical_forest, :threshold, 0.25)
        set_characteristic(temperate_grass, :threshold, 0.33)
        set_characteristic(desert_shrub, :threshold, 0.4)
        
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
        result_tropical = fire(wet_seasonal, tropical_forest, lai_typical, npp_typical)
        
        firedays_tropical = get_characteristic(result_tropical, :firedays)
        @test firedays_tropical >= 0.0
        @test firedays_tropical <= 365.0
        @test isfinite(firedays_tropical)
        
        # Test temperate grassland (moderate threshold)
        result_grass = fire(wet_seasonal, temperate_grass, lai_typical, npp_typical)
        
        firedays_grass = get_characteristic(result_grass, :firedays)
        @test firedays_grass >= 0.0
        @test firedays_grass <= 365.0
        @test isfinite(firedays_grass)
        
        # Grassland should have more fire days than forest (lower threshold)
        @test firedays_grass >= firedays_tropical
        
        # Test desert (low threshold = more fire-prone)
        result_desert = fire(wet_seasonal, desert_shrub, lai_typical, npp_typical)
        
        firedays_desert = get_characteristic(result_desert, :firedays)
        @test firedays_desert >= 0.0
        @test firedays_desert <= 365.0
        @test isfinite(firedays_desert)
        
        # Desert should have most fire days (lowest threshold)
        @test firedays_desert >= firedays_grass
    end
    
    @testset "Mathematical Correctness Tests" begin
        # Create test PFT with known threshold
        test_pft = WoodyDesert(10.0, 500.0, 20.0)
        set_characteristic(test_pft, :threshold, 0.3)
        
        lai_test = 2.0
        npp_test = 1200.0
        
        # Test with wetness all below threshold (should be max fire days)
        wet_dry = fill(0.1, 365)  # All days below threshold
        result_dry = fire(wet_dry, test_pft, lai_test, npp_test)
        firedays_dry = get_characteristic(result_dry, :firedays)
        
        @test firedays_dry ≈ 365.0 atol=1e-10  # All days should be fire days
        
        # Test with wetness all above threshold + 0.05 (should be no fire days)
        wet_wet = fill(0.4, 365)  # All days above threshold + 0.05
        result_wet = fire(wet_wet, test_pft, lai_test, npp_test)
        firedays_wet = get_characteristic(result_wet, :firedays)
        
        @test firedays_wet ≈ 0.0 atol=1e-10  # No fire days
        
        # Test with wetness exactly at threshold
        wet_threshold = fill(0.3, 365)  # All days at threshold
        result_threshold = fire(wet_threshold, test_pft, lai_test, npp_test)
        firedays_threshold = get_characteristic(result_threshold, :firedays)
        
        @test firedays_threshold ≈ 365.0 atol=1e-10  # At threshold = fire days
        
        # Test with wetness in the exponential decay range
        wet_decay = fill(0.32, 365)  # Between threshold and threshold + 0.05
        result_decay = fire(wet_decay, test_pft, lai_test, npp_test)
        firedays_decay = get_characteristic(result_decay, :firedays)
        
        # Should be between 0 and 365, calculated as 1.0 / exp(0.32 - 0.3) per day
        expected_burn_per_day = 1.0 / exp(0.32 - 0.3)
        expected_firedays = 365.0 * expected_burn_per_day
        @test firedays_decay ≈ expected_firedays atol=1e-10
        
        # Test NPP adjustment for low productivity
        npp_low = 500.0  # Below 1000 threshold
        result_low_npp = fire(wet_dry, test_pft, lai_test, npp_low)
        firedays_low_npp = get_characteristic(result_low_npp, :firedays)
        
        # Should be scaled by npp/1000
        expected_firedays_scaled = 365.0 * (npp_low / 1000.0)
        @test firedays_low_npp ≈ expected_firedays_scaled atol=1e-10
    end
    
    @testset "Wetday and Dryday Tests" begin
        # These tests would need the function to return these values
        # Since the current function only returns the modified PFT,
        # we'll test the internal logic by creating specific patterns
        
        test_pft = C4TropicalGrass(8.0, 1000.0, 25.0)
        set_characteristic(test_pft, :threshold, 0.25)
        
        # Test with known min/max wetness
        wet_range = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0] 
        wet_pattern = repeat(wet_range, 37)[1:365]  # Cycle through range
        
        result_range = fire(wet_pattern, test_pft, 2.5, 1500.0)
        
        # Function should handle the full range without errors
        firedays_range = get_characteristic(result_range, :firedays)
        @test isfinite(firedays_range)
        @test firedays_range >= 0.0
        @test firedays_range <= 365.0
    end
    
    @testset "Edge Cases" begin
        test_pft = TemperateDeciduous(12.0, 800.0, 18.0)
        set_characteristic(test_pft, :threshold, 0.35)
        
        # Test with zero LAI
        wet_normal = fill(0.2, 365)
        result_zero_lai = fire(wet_normal, test_pft, 0.0, 1000.0)
        firedays_zero_lai = get_characteristic(result_zero_lai, :firedays)
        
        @test isfinite(firedays_zero_lai)
        @test firedays_zero_lai >= 0.0
        
        # Test with very high LAI
        result_high_lai = fire(wet_normal, test_pft, 20.0, 1000.0)
        firedays_high_lai = get_characteristic(result_high_lai, :firedays)
        
        @test isfinite(firedays_high_lai)
        @test firedays_high_lai >= 0.0
        
        # Test with zero NPP
        result_zero_npp = fire(wet_normal, test_pft, 3.0, 0.0)
        firedays_zero_npp = get_characteristic(result_zero_npp, :firedays)
        
        @test firedays_zero_npp ≈ 0.0 atol=1e-10  # Zero NPP should result in zero fire days
        
        # Test with very high NPP
        result_high_npp = fire(wet_normal, test_pft, 3.0, 5000.0)
        firedays_high_npp = get_characteristic(result_high_npp, :firedays)
        
        @test isfinite(firedays_high_npp)
        @test firedays_high_npp >= 0.0
        
        # Test with extreme wetness values
        wet_extreme_dry = fill(-0.1, 365)  # Negative wetness
        result_extreme_dry = fire(wet_extreme_dry, test_pft, 3.0, 1200.0)
        firedays_extreme_dry = get_characteristic(result_extreme_dry, :firedays)
        
        @test firedays_extreme_dry ≈ 365.0 atol=1e-10  # All days should be fire days
        
        wet_extreme_wet = fill(2.0, 365)  # Very high wetness
        result_extreme_wet = fire(wet_extreme_wet, test_pft, 3.0, 1200.0)
        firedays_extreme_wet = get_characteristic(result_extreme_wet, :firedays)
        
        @test firedays_extreme_wet ≈ 0.0 atol=1e-10  # No fire days
    end
    
    @testset "Realistic Scenarios" begin
        # Test drought year scenario
        grassland = C3C4TemperateGrass(8.0, 400.0, 20.0)
        set_characteristic(grassland, :threshold, 0.28)
        
        # Drought year: mostly dry with occasional wet spells
        wet_drought = vcat(
            fill(0.1, 120),  # Extended dry period
            fill(0.6, 30),   # Brief wet period
            fill(0.15, 150), # More dry
            fill(0.4, 65)    # Moderate end
        )
        
        result_drought = fire(wet_drought, grassland, 1.5, 800.0)
        firedays_drought = get_characteristic(result_drought, :firedays)
        
        @test firedays_drought > 200.0  # Should have many fire days
        @test firedays_drought <= 365.0
        
        # Test wet year scenario
        wet_wet_year = vcat(
            fill(0.8, 100),  # Very wet start
            fill(0.5, 165),  # Moderate middle
            fill(0.7, 100)   # Wet end
        )
        
        result_wet_year = fire(wet_wet_year, grassland, 1.5, 800.0)
        firedays_wet_year = get_characteristic(result_wet_year, :firedays)
        
        @test firedays_wet_year < 50.0  # Should have few fire days
        @test firedays_wet_year >= 0.0
        
        # Drought year should have more fire days than wet year
        @test firedays_drought > firedays_wet_year
    end
    
    @testset "Error Conditions" begin
        test_pft = BorealEvergreen(5.0, 600.0, 12.0)
        set_characteristic(test_pft, :threshold, 0.32)
        
        # Test with wrong wetness: too short, too long is fine, we only take the first 365
        @test_throws BoundsError fire(fill(0.3, 300), test_pft, 2.0, 1000.0)  
        # Test with empty vector
        @test_throws BoundsError fire(Float64[], test_pft, 2.0, 1000.0)
    end
    
    @testset "Type Consistency Tests" begin
        test_pft = CoolConifer(6.0, 700.0, 10.0)
        set_characteristic(test_pft, :threshold, 0.3)
        
        # Test with Float32 - should throw an error due to type mismatch
        wet_f32 = fill(Float32(0.25), 365)
        lai_f32 = Float32(2.5)
        npp_f32 = Float32(1100.0)
        @test_throws TypeError fire(wet_f32, test_pft, lai_f32, npp_f32)
        
        # Test with Float64
        wet_f64 = fill(Float64(0.25), 365)
        lai_f64 = Float64(2.5)
        npp_f64 = Float64(1100.0)
        result_f64 = fire(wet_f64, test_pft, lai_f64, npp_f64)
        firedays_f64 = get_characteristic(result_f64, :firedays)
        @test typeof(firedays_f64) == Float64
        @test isfinite(firedays_f64)
        
    end
    
    @testset "Fire Fraction and Burn Fraction Logic" begin
        # Test the internal calculations for fire fraction and burn fraction
        test_pft = TropicalDroughtDeciduous(12.0, 1200.0, 28.0)
        set_characteristic(test_pft, :threshold, 0.25)
        
        # Create pattern with known fire days
        wet_half_fire = vcat(fill(0.1, 182), fill(0.5, 183))  # Half dry, half wet
        
        result_half = fire(wet_half_fire, test_pft, 4.0, 2000.0)
        firedays_half = get_characteristic(result_half, :firedays)
        
        # Should be approximately 182 fire days (half the year)
        @test firedays_half ≈ 182.0 atol=1.0
        
        # Test that the function is deterministic
        result_half2 = fire(wet_half_fire, test_pft, 4.0, 2000.0)
        firedays_half2 = get_characteristic(result_half2, :firedays)
        
        @test firedays_half == firedays_half2
    end
end