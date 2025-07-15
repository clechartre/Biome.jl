using Test
using Base.Math: exp
using BIOME 

@testset "C4 Photosynthesis Tests" begin
    
    @testset "Positive Test - Normal C4 photosynthesis conditions" begin
        # Create real C4 PFTs using the actual constructors
        c4_tropical = C4TropicalGrass()
        c4_woody_desert = WoodyDesert() 
        
        # Realistic environmental parameters for active photosynthesis
        ratio = 0.7          # Normal intercellular/ambient CO2 ratio
        dsun = 20.0          # Good solar radiation (MJ/m²/day)
        daytime = 12.0       # 12 hours of daylight
        temp = 30.0          # Optimal temperature for C4 plants (°C)
        age = 6.0            # 6-month-old leaves
        fpar = 0.8           # Good light absorption
        p = 101.3            # Standard atmospheric pressure (kPa)
        ca = 400.0           # Current atmospheric CO2 (ppm)
        
        # Test with C4 Tropical Grass
        leafresp, grossphot, aday = c4photo(ratio, dsun, daytime, temp, age, fpar, p, ca, c4_tropical)
        
        # Function should return valid numbers (not NaN or Inf)
        @test isfinite(leafresp)
        @test isfinite(grossphot)
        @test isfinite(aday)
        
        # All values should be non-negative
        @test leafresp >= 0.0
        @test grossphot >= 0.0
        @test aday >= 0.0
        
        # Function should return a tuple of three values
        @test isa((leafresp, grossphot, aday), Tuple{Float64, Float64, Float64})
        
        # Test with C4 Woody Desert (different parameters)
        leafresp2, grossphot2, aday2 = c4photo(ratio, dsun, daytime, temp, age, fpar, p, ca, c4_woody_desert)
        
        # Should return valid numbers for different C4 types
        @test isfinite(leafresp2)
        @test isfinite(grossphot2) 
        @test isfinite(aday2)
        @test leafresp2 >= 0.0
        @test grossphot2 >= 0.0
        @test aday2 >= 0.0
    end
    
    @testset "Negative Test - Conditions limiting photosynthesis" begin
        # Create real C4 PFT for controlled testing
        c4_tropical = C4TropicalGrass()
        
        # Test with extreme cold temperature
        ratio = 0.7
        dsun = 20.0
        daytime = 12.0
        temp = 5.0           # Very cold temperature (below t0=10)
        age = 6.0
        fpar = 0.8
        p = 101.3
        ca = 400.0
        
        leafresp_cold, grossphot_cold, aday_cold = c4photo(ratio, dsun, daytime, temp, age, fpar, p, ca, c4_tropical)
        
        # Cold temperature should result in zero photosynthesis due to temperature stress
        @test grossphot_cold == 0.0
        @test aday_cold == 0.0
        @test leafresp_cold >= 0.0  # Respiration may still occur
        
        # Test with zero solar radiation
        leafresp_dark, grossphot_dark, aday_dark = c4photo(ratio, 0.0, daytime, 30.0, age, fpar, p, ca, c4_tropical)
        
        # No light should result in no photosynthesis
        @test grossphot_dark == 0.0
        @test aday_dark == 0.0
        
        # Test with extreme temperature (too hot)
        leafresp_hot, grossphot_hot, aday_hot = c4photo(ratio, dsun, daytime, 55.0, age, fpar, p, ca, c4_tropical)
        
        # Extreme heat should limit photosynthesis (above MAXTEMP=50)
        @test grossphot_hot == 0.0
        @test aday_hot == 0.0
        
        # Test return types are consistent
        @test typeof(leafresp_cold) == typeof(grossphot_cold) == typeof(aday_cold)
        @test all(isfinite.([leafresp_cold, grossphot_cold, aday_cold]))
    end
    
    @testset "Non-C4 PFT Test" begin
        # Create a non-C4 PFT to test error handling
        c3_deciduous = TemperateDeciduous()  # This is a C3 plant
        
        # Test that function handles non-C4 PFT appropriately
        # The function should print a warning but may crash due to uninitialized variables
        @test_throws ArgumentError c4photo(0.7, 20.0, 12.0, 30.0, 6.0, 0.8, 101.3, 400.0, c3_deciduous)
    end
    
    @testset "Edge Cases" begin
        # Create real C4 PFT
        c4_tropical = C4TropicalGrass()
        
        # Test with very low ratio (should trigger damage calculation)
        leafresp_low, grossphot_low, aday_low = c4photo(0.2, 20.0, 12.0, 30.0, 6.0, 0.8, 101.3, 400.0, c4_tropical)
        @test isfinite(leafresp_low)
        @test isfinite(grossphot_low)
        @test isfinite(aday_low)
        @test leafresp_low >= 0.0
        @test grossphot_low >= 0.0
        @test aday_low >= 0.0
        
        # Test with zero fpar (no light absorption)
        leafresp_zero, grossphot_zero, aday_zero = c4photo(0.7, 20.0, 12.0, 30.0, 6.0, 0.0, 101.3, 400.0, c4_tropical)
        @test isfinite(leafresp_zero)
        @test isfinite(grossphot_zero)
        @test isfinite(aday_zero)
        @test grossphot_zero == 0.0  # No light = no photosynthesis
        @test aday_zero == 0.0
        @test leafresp_zero >= 0.0   # Respiration may still occur
    end
    
    @testset "Edge Cases with Low Values" begin
        # Create real C4 PFT
        c4_tropical = C4TropicalGrass()
        
        # Test conditions that produce very small positive values instead of domain errors
        # These parameters lead to extremely low photosynthesis but valid results
        
        # Test with very low solar radiation and short daytime
        leafresp1, grossphot1, aday1 = c4photo(0.7, 1.0, 2.0, 30.0, 6.0, 0.1, 101.3, 400.0, c4_tropical)
        @test isfinite(leafresp1) && leafresp1 >= 0.0
        @test isfinite(grossphot1) && grossphot1 >= 0.0
        @test isfinite(aday1) && aday1 >= 0.0
        @test grossphot1 < 1e-6  # Very small value
        
        # Test with low solar radiation and poor conditions
        leafresp2, grossphot2, aday2 = c4photo(0.8, 0.5, 1.0, 25.0, 12.0, 0.05, 101.3, 350.0, c4_tropical)
        @test isfinite(leafresp2) && leafresp2 >= 0.0
        @test isfinite(grossphot2) && grossphot2 >= 0.0
        @test isfinite(aday2) && aday2 >= 0.0
        @test grossphot2 < 1e-7  # Very small value
        
        # Test with extreme parameter combinations that produce minimal photosynthesis
        leafresp3, grossphot3, aday3 = c4photo(0.9, 0.1, 3.0, 35.0, 24.0, 0.02, 90.0, 300.0, c4_tropical)
        @test isfinite(leafresp3) && leafresp3 >= 0.0
        @test isfinite(grossphot3) && grossphot3 >= 0.0
        @test isfinite(aday3) && aday3 >= 0.0
        @test grossphot3 < 1e-8  # Very small value
        
        # Test with very old leaves and poor conditions
        leafresp4, grossphot4, aday4 = c4photo(0.6, 0.8, 2.5, 28.0, 36.0, 0.03, 101.3, 380.0, c4_tropical)
        @test isfinite(leafresp4) && leafresp4 >= 0.0
        @test isfinite(grossphot4) && grossphot4 >= 0.0
        @test isfinite(aday4) && aday4 >= 0.0
        @test grossphot4 < 1e-7  # Very small value
    end
    
    
end