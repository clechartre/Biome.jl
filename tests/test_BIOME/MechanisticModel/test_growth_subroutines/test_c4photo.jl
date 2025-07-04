using Test
using Base.Math: exp

include("../../../../src/abstractmodel.jl")
include("../../../../src/pfts.jl")
include("../../../../src/biomes.jl")
include("../../../../src/models/MechanisticModel/pfts.jl")
include("../../../../src/models/MechanisticModel/growth_subroutines/c4photo.jl")

# Mock constants (these should match the actual constants used in the model)
const SLO2 = 0.209
const MAXTEMP = 50.0
const TAO25 = 2600.0
const TAOQ10 = 0.57
const DRESPC4 = 0.5
const CMASS = 12.0
const JTOE = 4.6
const TWIGLOSS = 0.8
const TUNE = 1.0
const OPTRATIO = 0.8
const TETA = 0.95

@testset "C4 Photosynthesis Tests" begin
    
    @testset "Positive Test - Normal C4 photosynthesis conditions" begin
        # Create real C4 PFTs using the actual constructors
        c4_tropical = C4TropicalGrass(10.0, 100.0, 25.0)  # clt, prec, temp
        c4_woody_desert = WoodyDesert(10.0, 50.0, 25.0)   # clt, prec, temp
        
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
        c4_tropical = C4TropicalGrass(10.0, 100.0, 25.0)
        
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
        c3_deciduous = TemperateDeciduous(10.0, 100.0, 15.0)  # This is a C3 plant
        
        # Test that function handles non-C4 PFT appropriately
        # The function should print a warning but may crash due to uninitialized variables
        @test_throws ArgumentError c4photo(0.7, 20.0, 12.0, 30.0, 6.0, 0.8, 101.3, 400.0, c3_deciduous)
    end
    
    @testset "Edge Cases" begin
        # Create real C4 PFT
        c4_tropical = C4TropicalGrass(10.0, 100.0, 25.0)
        
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
    
    @testset "Domain Error Tests" begin
        # Create real C4 PFT
        c4_tropical = C4TropicalGrass(10.0, 100.0, 25.0)
        
        # Test conditions that can cause sqrt of negative number in the photosynthesis calculation
        # This happens when (je + jc)^2 - 4*TETA*je*jc < 0
        
        # Test with parameters that lead to numerical instability
        @test_throws DomainError c4photo(0.7, 1.0, 2.0, 30.0, 6.0, 0.1, 101.3, 400.0, c4_tropical)
        
        # Test with very low solar radiation and short daytime
        @test_throws DomainError c4photo(0.8, 0.5, 1.0, 25.0, 12.0, 0.05, 101.3, 350.0, c4_tropical)
        
        # Test with extreme parameter combinations that cause mathematical domain errors
        @test_throws DomainError c4photo(0.9, 0.1, 3.0, 35.0, 24.0, 0.02, 90.0, 300.0, c4_tropical)
        
        # Test with very old leaves and poor conditions
        @test_throws DomainError c4photo(0.6, 0.8, 2.5, 28.0, 36.0, 0.03, 101.3, 380.0, c4_tropical)
    end
    
end