using Test

include("../../../src/abstractmodel.jl")
include("../../../src/pfts.jl")
include("../../../src/biomes.jl")
include("../../../src/models/MechanisticModel/pfts.jl")
include("../../../src/models/MechanisticModel/phenology.jl")

@testset "Phenology Tests" begin
    
    @testset "Positive Test - Boreal Deciduous" begin
        # Create Boreal Deciduous PFT
        boreal_dec = BorealDeciduous(4.0, 500.0, 8.0)
        set_characteristic(boreal_dec, :GDD5_full_leaf_out, 350.0)
        set_characteristic(boreal_dec, :GDD0_full_leaf_out, 400.0)
        
        # Realistic inputs for boreal region
        dphen_input = ones(365, 2)  # Will be overwritten
        dtemp = vcat(fill(-15.0, 90), fill(5.0, 90), fill(15.0, 90), fill(-5.0, 95))  # Seasonal pattern
        temp = [-10.0, -8.0, -2.0, 8.0, 15.0, 20.0, 22.0, 18.0, 12.0, 5.0, -2.0, -8.0]  # Monthly temps
        tcm = -10.0  # Coldest month temperature
        tmin = -30.0  # Annual minimum temperature
        ddayl = vcat(fill(8.0, 90), fill(14.0, 90), fill(16.0, 90), fill(10.0, 95))  # Seasonal daylength
        
        result = phenology(dphen_input, dtemp, temp, tcm, tmin, boreal_dec, ddayl)
        
        # Check output dimensions
        @test size(result) == (365, 2)
        
        # Check that all values are finite
        @test all(isfinite.(result))
        
        # Check value ranges (phenology values should be between 0 and 1)
        @test all(0.0 .<= result .<= 1.0)
        
        # For deciduous trees, there should be periods with reduced leaf cover
        @test minimum(result[:, 2]) < 1.0  # Not always full leaf cover
        
        # Spring should show increasing leaf cover
        spring_days = 91:180  # Roughly April-June
        spring_values = result[spring_days, 2]
    
    end
    
    @testset "Evergreen PFT Tests" begin
        # Create evergreen PFT
        evergreen = BorealEvergreen(5.0, 600.0, 10.0)
        set_characteristic(evergreen, :GDD5_full_leaf_out, 200.0)
        set_characteristic(evergreen, :GDD0_full_leaf_out, 250.0)
        
        # Standard inputs
        dphen_input = ones(365, 2)
        dtemp = vcat(fill(-5.0, 90), fill(10.0, 90), fill(20.0, 90), fill(0.0, 95))
        temp = [-2.0, 0.0, 5.0, 12.0, 18.0, 22.0, 24.0, 20.0, 15.0, 8.0, 2.0, -1.0]
        tcm = -2.0
        tmin = -5.0
        ddayl = vcat(fill(9.0, 90), fill(15.0, 90), fill(17.0, 90), fill(11.0, 95))
        
        result_evergreen = phenology(dphen_input, dtemp, temp, tcm, tmin, evergreen, ddayl)
        
        # Check dimensions
        @test size(result_evergreen) == (365, 2)
        @test all(isfinite.(result_evergreen))
        @test all(0.0 .<= result_evergreen .<= 1.0)
        
        # For evergreens, should maintain higher leaf cover throughout year
        @test minimum(result_evergreen[:, 1]) > 0.5  # Should not drop too low
        
        # Compare with deciduous - evergreen should have less variation
        boreal_dec = BorealDeciduous(4.0, 500.0, 8.0)
        set_characteristic(boreal_dec, :GDD5_full_leaf_out, 350.0)
        set_characteristic(boreal_dec, :GDD0_full_leaf_out, 400.0)
        
        result_deciduous = phenology(dphen_input, dtemp, temp, tcm, tmin, boreal_dec, ddayl)
        
        # Evergreen should have less seasonal variation
        evergreen_var = maximum(result_evergreen[:, 1]) - minimum(result_evergreen[:, 1])
        deciduous_var = maximum(result_deciduous[:, 1]) - minimum(result_deciduous[:, 1])
        
        @test evergreen_var <= deciduous_var
    end
    
    @testset "Temperature Threshold Tests" begin
        # Test with different temperature thresholds
        test_pft = TemperateDeciduous(8.0, 800.0, 15.0)
        set_characteristic(test_pft, :GDD5_full_leaf_out, 300.0)
        set_characteristic(test_pft, :GDD0_full_leaf_out, 350.0)
        
        dphen_input = ones(365, 2)
        ddayl = vcat(fill(10.0, 90), fill(16.0, 90), fill(18.0, 90), fill(12.0, 95))
        
        # Test with cold spring (delayed leaf-out)
        dtemp_cold = vcat(fill(-10.0, 120), fill(5.0, 60), fill(20.0, 90), fill(0.0, 95))
        temp_cold = [-8.0, -6.0, -2.0, 2.0, 10.0, 18.0, 22.0, 20.0, 14.0, 6.0, 0.0, -5.0]
        tcm_cold = -8.0
        tmin_cold = -10.0
        
        result_cold = phenology(dphen_input, dtemp_cold, temp_cold, tcm_cold, tmin_cold, test_pft, ddayl)
        
        # Test with warm spring (early leaf-out)
        dtemp_warm = vcat(fill(0.0, 60), fill(10.0, 90), fill(25.0, 90), fill(5.0, 125))
        temp_warm = [2.0, 4.0, 8.0, 15.0, 20.0, 25.0, 28.0, 26.0, 20.0, 12.0, 6.0, 3.0]
        tcm_warm = 2.0
        tmin_warm = 0.0
        
        result_warm = phenology(dphen_input, dtemp_warm, temp_warm, tcm_warm, tmin_warm, test_pft, ddayl)
        
        # Both should be valid
        @test all(isfinite.(result_cold))
        @test all(isfinite.(result_warm))
        @test all(0.0 .<= result_cold .<= 1.0)
        @test all(0.0 .<= result_warm .<= 1.0)
        
        # Early spring in warm case should show earlier leaf development
        early_spring = 60:120  # March-April period
        warm_early_spring = mean(result_warm[early_spring, 2])
        cold_early_spring = mean(result_cold[early_spring, 2])
        
        @test warm_early_spring >= cold_early_spring
    end
    
    @testset "GDD Threshold Tests" begin
        # Test different GDD requirements
        low_gdd_pft = C3C4TemperateGrass(7.0, 600.0, 18.0)
        high_gdd_pft = C3C4TemperateGrass(7.0, 600.0, 18.0)
        
        # Set different GDD requirements
        set_characteristic(low_gdd_pft, :GDD5_full_leaf_out, 100.0)
        set_characteristic(low_gdd_pft, :GDD0_full_leaf_out, 150.0)
        set_characteristic(high_gdd_pft, :GDD5_full_leaf_out, 500.0)
        set_characteristic(high_gdd_pft, :GDD0_full_leaf_out, 600.0)
        
        dphen_input = ones(365, 2)
        dtemp = vcat(fill(0.0, 90), fill(8.0, 90), fill(18.0, 90), fill(2.0, 95))
        temp = [1.0, 3.0, 6.0, 12.0, 16.0, 20.0, 22.0, 19.0, 14.0, 8.0, 4.0, 2.0]
        tcm = 1.0
        tmin = 0.0
        ddayl = vcat(fill(9.0, 90), fill(15.0, 90), fill(17.0, 90), fill(11.0, 95))
        
        result_low_gdd = phenology(dphen_input, dtemp, temp, tcm, tmin, low_gdd_pft, ddayl)
        result_high_gdd = phenology(dphen_input, dtemp, temp, tcm, tmin, high_gdd_pft, ddayl)
        
        # Both should be valid
        @test all(isfinite.(result_low_gdd))
        @test all(isfinite.(result_high_gdd))
        @test all(0.0 .<= result_low_gdd .<= 1.0)
        @test all(0.0 .<= result_high_gdd .<= 1.0)
        
        # Low GDD requirement should reach full leaf cover earlier
        mid_spring = 100:150  # Mid-spring period
        low_gdd_spring = mean(result_low_gdd[mid_spring, 1])
        high_gdd_spring = mean(result_high_gdd[mid_spring, 1])
        
        @test low_gdd_spring >= high_gdd_spring
    end
    
    @testset "Extreme Temperature Tests" begin
        extreme_pft = TundraShrubs(1.0, 200.0, 2.0)
        set_characteristic(extreme_pft, :GDD5_full_leaf_out, 200.0)
        set_characteristic(extreme_pft, :GDD0_full_leaf_out, 250.0)
        
        dphen_input = ones(365, 2)
        ddayl = vcat(fill(6.0, 90), fill(18.0, 90), fill(20.0, 90), fill(8.0, 95))
        
        # Test with always cold conditions
        dtemp_always_cold = fill(-20.0, 365)
        temp_always_cold = fill(-15.0, 12)
        tcm_always_cold = -15.0
        tmin_always_cold = -20.0
        
        result_always_cold = phenology(dphen_input, dtemp_always_cold, temp_always_cold, 
                                     tcm_always_cold, tmin_always_cold, extreme_pft, ddayl)
        
        @test all(isfinite.(result_always_cold))
        @test all(0.0 .<= result_always_cold .<= 1.0)
        
        # Should have minimal leaf development in always cold conditions
        @test maximum(result_always_cold[:, 1]) < 0.5
        
        # Test with always warm conditions
        dtemp_always_warm = fill(25.0, 365)
        temp_always_warm = fill(20.0, 12)
        tcm_always_warm = 20.0
        tmin_always_warm = 25.0
        
        result_always_warm = phenology(dphen_input, dtemp_always_warm, temp_always_warm,
                                     tcm_always_warm, tmin_always_warm, extreme_pft, ddayl)
        
        @test all(isfinite.(result_always_warm))
        @test all(0.0 .<= result_always_warm .<= 1.0)
    
    end
    
    @testset "Seasonal Timing Tests" begin
        seasonal_pft = CoolConifer(6.0, 700.0, 12.0)
        set_characteristic(seasonal_pft, :GDD5_full_leaf_out, 250.0)
        set_characteristic(seasonal_pft, :GDD0_full_leaf_out, 300.0)
        
        dphen_input = ones(365, 2)
        # Realistic northern hemisphere seasonal pattern
        dtemp = vcat(
            fill(-8.0, 31),   # January
            fill(-5.0, 28),   # February  
            fill(0.0, 31),    # March
            fill(8.0, 30),    # April
            fill(15.0, 31),   # May
            fill(20.0, 30),   # June
            fill(22.0, 31),   # July
            fill(20.0, 31),   # August
            fill(15.0, 30),   # September
            fill(8.0, 31),    # October
            fill(0.0, 30),    # November
            fill(-5.0, 31)    # December
        )
        temp = [-8.0, -5.0, 0.0, 8.0, 15.0, 20.0, 22.0, 20.0, 15.0, 8.0, 0.0, -5.0]
        tcm = -8.0
        tmin = -8.0
        ddayl = vcat(
            fill(8.0, 90),    # Winter - short days
            fill(14.0, 92),   # Spring - increasing
            fill(16.0, 92),   # Summer - long days
            fill(10.0, 91)    # Fall - decreasing
        )
        
        result = phenology(dphen_input, dtemp, temp, tcm, tmin, seasonal_pft, ddayl)
        
        @test all(isfinite.(result))
        @test all(0.0 .<= result .<= 1.0)
        
        # Check seasonal progression
        winter_period = [1:59; 335:365]  # Dec-Feb, roughly
        spring_period = 60:151           # Mar-May
        summer_period = 152:243          # Jun-Aug
        fall_period = 244:334            # Sep-Nov
        
        winter_mean = mean(result[winter_period, 1])
        spring_mean = mean(result[spring_period, 1])
        summer_mean = mean(result[summer_period, 1])
        fall_mean = mean(result[fall_period, 1])
        
        # Expected seasonal progression: winter < spring < summer, fall between spring and summer
        @test summer_mean >= spring_mean
        @test spring_mean >= winter_mean
        @test fall_mean <= summer_mean
    end
    
    @testset "Type Consistency Tests" begin
        type_pft = LichenForb(2.0, 300.0, 5.0)
        set_characteristic(type_pft, :GDD5_full_leaf_out, 150.0)
        set_characteristic(type_pft, :GDD0_full_leaf_out, 200.0)
        
        # Test with Float32
        dphen_input_f32 = ones(Float32, 365, 2)
        dtemp_f32 = Float32.(vcat(fill(-2.0, 90), fill(8.0, 90), fill(15.0, 90), fill(0.0, 95)))
        temp_f32 = Float32[0.0, 2.0, 5.0, 10.0, 14.0, 18.0, 20.0, 17.0, 12.0, 6.0, 2.0, 0.0]
        tcm_f32 = Float32(0.0)
        tmin_f32 = Float32(-2.0)
        ddayl_f32 = Float32.(vcat(fill(8.0, 90), fill(14.0, 90), fill(16.0, 90), fill(10.0, 95)))
        
        result_f32 = phenology(dphen_input_f32, dtemp_f32, temp_f32, tcm_f32, tmin_f32, type_pft, ddayl_f32)
        
        # Check type preservation
        @test eltype(result_f32) == Float32
        @test size(result_f32) == (365, 2)
        
        # Values should be finite and in valid range
        @test all(isfinite.(result_f32))
        @test all(0.0f0 .<= result_f32 .<= 1.0f0)
    end
    
    @testset "Array Length Validation" begin
        valid_pft = WoodyDesert(15.0, 300.0, 25.0)
        set_characteristic(valid_pft, :GDD5_full_leaf_out, 100.0)
        set_characteristic(valid_pft, :GDD0_full_leaf_out, 150.0)
        set_characteristic(valid_pft, :phenological_type, 2)  # Evergreen
        
        dphen_valid = ones(365, 2)
        dtemp_valid = fill(20.0, 365)
        temp_valid = fill(18.0, 12)
        tcm_valid = 15.0
        tmin_valid = 10.0
        ddayl_valid = fill(12.0, 365)
        
        # Test with wrong dtemp array length
        @test_throws BoundsError phenology(dphen_valid, fill(20.0, 300), temp_valid, tcm_valid, tmin_valid, valid_pft, ddayl_valid)
        
        # Test with wrong temp array length
        @test_throws BoundsError phenology(dphen_valid, dtemp_valid, fill(18.0, 10), tcm_valid, tmin_valid, valid_pft, ddayl_valid)
        
        # Test with wrong ddayl array length
        @test_throws BoundsError phenology(dphen_valid, dtemp_valid, temp_valid, tcm_valid, tmin_valid, valid_pft, fill(12.0, 300))
        
        # Test with wrong dphen dimensions
        @test_throws BoundsError phenology(ones(300, 1), dtemp_valid, temp_valid, tcm_valid, tmin_valid, valid_pft, ddayl_valid)
    end
    
    @testset "PFT Characteristic Tests" begin
        # Test different PFT characteristics
        char_pft1 = TropicalEvergreen(10.0, 1500.0, 27.0)
        char_pft2 = TropicalEvergreen(10.0, 1500.0, 27.0)
        
        # Set different GDD requirements
        set_characteristic(char_pft1, :GDD5_full_leaf_out, 50.0)   # Low requirement
        set_characteristic(char_pft1, :GDD0_full_leaf_out, 100.0)
        set_characteristic(char_pft2, :GDD5_full_leaf_out, 400.0)  # High requirement
        set_characteristic(char_pft2, :GDD0_full_leaf_out, 500.0)
        
        dphen_input = ones(365, 2)
        dtemp = vcat(fill(15.0, 90), fill(20.0, 90), fill(25.0, 90), fill(18.0, 95))
        temp = fill(20.0, 12)  # Constant warm temperature
        tcm = 20.0
        tmin = 15.0
        ddayl = fill(12.0, 365)  # Tropical daylength
        
        result1 = phenology(dphen_input, dtemp, temp, tcm, tmin, char_pft1, ddayl)
        result2 = phenology(dphen_input, dtemp, temp, tcm, tmin, char_pft2, ddayl)
        
        # Both should be valid
        @test all(isfinite.(result1))
        @test all(isfinite.(result2))
        @test all(0.0 .<= result1 .<= 1.0)
        @test all(0.0 .<= result2 .<= 1.0)
        
        # Low GDD requirement should reach full development faster
        early_season = 1:100
        mean_early_1 = mean(result1[early_season, 1])
        mean_early_2 = mean(result2[early_season, 1])
        
        @test mean_early_1 >= mean_early_2
    end
    
    @testset "Edge Case - Flat Temperature Profile" begin
        flat_pft = C4TropicalGrass(12.0, 900.0, 28.0)
        set_characteristic(flat_pft, :GDD5_full_leaf_out, 200.0)
        set_characteristic(flat_pft, :GDD0_full_leaf_out, 250.0)
        
        dphen_input = ones(365, 2)
        # Completely flat temperature profile
        dtemp_flat = fill(15.0, 365)
        temp_flat = fill(15.0, 12)
        tcm_flat = 15.0
        tmin_flat = 15.0
        ddayl_flat = fill(12.0, 365)
        
        result_flat = phenology(dphen_input, dtemp_flat, temp_flat, tcm_flat, tmin_flat, flat_pft, ddayl_flat)
        
        @test all(isfinite.(result_flat))
        @test all(0.0 .<= result_flat .<= 1.0)
        
        # With constant favorable conditions, should reach and maintain high values
        @test mean(result_flat[:, 1]) > 0.7
    end
end