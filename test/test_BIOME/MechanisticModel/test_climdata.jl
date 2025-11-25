using Test


@testset "Climate Data Tests" begin
    
    @testset "Positive Test - Temperate Climate" begin
        # Realistic temperate climate data
        temp = [-2.0, 1.0, 6.0, 12.0, 18.0, 22.0, 25.0, 23.0, 18.0, 12.0, 6.0, 1.0]
        prec = [50.0, 60.0, 70.0, 80.0, 90.0, 100.0, 80.0, 70.0, 80.0, 90.0, 70.0, 60.0]
        
        # Daily temperatures (365 days)
        dtemp = vcat(
            fill(-2.0, 31),   # Jan
            fill(1.0, 28),    # Feb
            fill(6.0, 31),    # Mar
            fill(12.0, 30),   # Apr
            fill(18.0, 31),   # May
            fill(22.0, 30),   # Jun
            fill(25.0, 31),   # Jul
            fill(23.0, 31),   # Aug
            fill(18.0, 30),   # Sep
            fill(12.0, 31),   # Oct
            fill(6.0, 30),    # Nov
            fill(1.0, 31)     # Dec
        )
        
        tcm, gdd5, gdd0, twm = climdata(temp, prec, dtemp)
        
        # Check return types
        @test typeof(gdd5) == Float64
        @test typeof(tcm) == Float64
        @test typeof(gdd0) == Float64
        @test typeof(twm) == Float64
        
        # Check that all values are finite
        @test isfinite(gdd5)
        @test isfinite(tcm)
        @test isfinite(gdd0)
        @test isfinite(twm)
        
        # TCM should be the coldest monthly temperature
        @test tcm == minimum(temp)
        @test tcm ≈ -2.0
        
        # TWM should be the warmest monthly temperature
        @test twm ≈ maximum(temp)
        @test twm ≈ 25.0
        
        # GDD5 should be positive (has days > 5°C)
        @test gdd5 > 0.0
        
        # Calculate expected GDD5 manually
        expected_gdd5 = sum(max.(dtemp .- 5.0, 0.0))
        @test gdd5 ≈ expected_gdd5
        
        # GDD0 should be positive (has days > 0°C)
        @test gdd0 > 0.0
        expected_gdd0 = sum(max.(dtemp, 0.0))
        @test gdd0 ≈ expected_gdd0
    end
    
    @testset "Tropical Climate Tests" begin
        # Tropical climate - consistently warm
        temp_tropical = [26.0, 27.0, 28.0, 29.0, 28.0, 27.0, 26.0, 26.0, 27.0, 28.0, 27.0, 26.0]
        prec_tropical = [200.0, 150.0, 100.0, 50.0, 30.0, 20.0, 25.0, 40.0, 80.0, 150.0, 180.0, 220.0]
        dtemp_tropical = fill(27.0, 365)  # Simplified constant daily temp
        
        tcm_trop, gdd5_trop, gdd0_trop, twm_trop = climdata(temp_tropical, prec_tropical, dtemp_tropical)
        
        @test all(isfinite.([gdd5_trop, tcm_trop, gdd0_trop, twm_trop]))
        
        # TCM should be minimum temperature
        @test tcm_trop == minimum(temp_tropical)
        @test tcm_trop ≈ 26.0
        
        # TWM should be maximum temperature
        @test twm_trop ≈ maximum(temp_tropical)
        @test twm_trop ≈ 29.0
        
        # GDD5 should be very high (all days well above 5°C)
        @test gdd5_trop > 5000.0  # (27-5) * 365 = 8030
        expected_gdd5_trop = 365 * (27.0 - 5.0)
        @test gdd5_trop ≈ expected_gdd5_trop
        
        # GDD0 should be very high (all positive temperatures)
        @test gdd0_trop > 9000.0
        expected_gdd0_trop = 365 * 27.0
        @test gdd0_trop ≈ expected_gdd0_trop
    end
    
    @testset "Arctic Climate Tests" begin
        # Arctic climate - very cold
        temp_arctic = [-25.0, -22.0, -15.0, -5.0, 3.0, 10.0, 12.0, 8.0, 2.0, -8.0, -18.0, -23.0]
        prec_arctic = [10.0, 8.0, 12.0, 15.0, 20.0, 25.0, 30.0, 28.0, 22.0, 18.0, 12.0, 8.0]
        dtemp_arctic = vcat(
            fill(-25.0, 90),  # Long cold period
            fill(5.0, 90),    # Brief warming
            fill(10.0, 92),   # Short summer
            fill(-10.0, 93)   # Return to cold
        )
        
        tcm_arctic, gdd5_arctic, gdd0_arctic, twm_arctic = climdata(temp_arctic, prec_arctic, dtemp_arctic)
        
        @test all(isfinite.([gdd5_arctic, tcm_arctic, gdd0_arctic, twm_arctic]))
        
        # TCM should be very cold
        @test tcm_arctic == minimum(temp_arctic)
        @test tcm_arctic ≈ -25.0
        
        # TWM should be warmest month
        @test twm_arctic ≈ maximum(temp_arctic)
        @test twm_arctic ≈ 12.0
        
        # GDD5 should be low (few days > 5°C)
        @test gdd5_arctic >= 0.0
        
        # Calculate expected GDD5
        expected_gdd5_arctic = sum(max.(dtemp_arctic .- 5.0, 0.0))
        @test gdd5_arctic ≈ expected_gdd5_arctic
        
        # Most days should not contribute to GDD5
        contributing_days = sum(dtemp_arctic .> 5.0)
        @test contributing_days < 200  # Less than half the year
    end
    
    @testset "GDD Calculation Tests" begin
        # Test GDD5 calculation specifically
        
        # Case 1: All days above threshold
        temp_all_warm = fill(20.0, 12)
        prec_test = fill(50.0, 12)
        dtemp_all_warm = fill(20.0, 365)
        
        _, gdd5_warm, _, _ = climdata(temp_all_warm, prec_test, dtemp_all_warm)
        expected_gdd5_warm = 365 * (20.0 - 5.0)
        @test gdd5_warm ≈ expected_gdd5_warm
        @test gdd5_warm ≈ 5475.0
        
        # Case 2: All days below threshold
        temp_all_cold = fill(-10.0, 12)
        dtemp_all_cold = fill(-10.0, 365)
        
        _, gdd5_cold, _, _ = climdata(temp_all_cold, prec_test, dtemp_all_cold)
        @test gdd5_cold ≈ 0.0
        
        # Case 3: Some days above, some below
        dtemp_mixed = vcat(fill(0.0, 100), fill(10.0, 165), fill(0.0, 100))
        temp_mixed = fill(5.0, 12)
        
        _, gdd5_mixed, _, _ = climdata(temp_mixed, prec_test, dtemp_mixed)
        expected_gdd5_mixed = 165 * (10.0 - 5.0)  # Only middle 165 days contribute
        @test gdd5_mixed ≈ expected_gdd5_mixed
        @test gdd5_mixed ≈ 825.0
        
        # Case 4: Temperatures exactly at threshold
        dtemp_threshold = fill(5.0, 365)
        temp_threshold = fill(5.0, 12)
        
        _, gdd5_threshold, _, _ = climdata(temp_threshold, prec_test, dtemp_threshold)
        @test gdd5_threshold ≈ 0.0  # 5-5 = 0 for each day
    end
    
    @testset "Temperature Extremes Tests" begin
        temp_test = [0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 20.0, 15.0, 10.0, 5.0, 0.0, -5.0]
        prec_test = fill(30.0, 12)
        dtemp_test = fill(10.0, 365)
        
        tcm_test, gdd5_test, gdd0_test, twm_test = climdata(temp_test, prec_test, dtemp_test)
        
        # TCM should be coldest month
        @test tcm_test == minimum(temp_test)
        @test tcm_test ≈ -5.0
        
        # Test with extreme cold
        temp_extreme_cold = fill(-50.0, 12)
        dtemp_extreme_cold = fill(-50.0, 365)
        
        tcm_extreme, gdd5_extreme, gdd0_extreme, twm_extreme = climdata(temp_extreme_cold, prec_test, dtemp_extreme_cold)
        
        @test tcm_extreme ≈ -50.0
        @test gdd5_extreme ≈ 0.0
        
        # Test with extreme heat
        temp_extreme_hot = fill(50.0, 12)
        dtemp_extreme_hot = fill(50.0, 365)
        
        tcm_hot, gdd5_hot, gdd0_hot, twm_hot = climdata(temp_extreme_hot, prec_test, dtemp_extreme_hot)
        
        @test tcm_hot ≈ 50.0
        @test gdd5_hot ≈ 365 * (50.0 - 5.0)
        @test gdd5_hot ≈ 16425.0
    end
    
    
    @testset "Type Consistency Tests" begin
        # Test with Float32
        temp_f32 = Float32[10.0, 12.0, 15.0, 18.0, 22.0, 25.0, 27.0, 25.0, 20.0, 15.0, 12.0, 8.0]
        prec_f32 = Float32.(fill(40.0, 12))
        dtemp_f32 = Float32.(fill(18.0, 365))
        
        tcm_f32, gdd5_f32, gdd0_f32, twm_f32 = climdata(temp_f32, prec_f32, dtemp_f32)
        
        # Check type preservation
        @test typeof(gdd5_f32) == Float32
        @test typeof(tcm_f32) == Float32
        @test typeof(gdd0_f32) == Float32
        @test typeof(twm_f32) == Float32
        
        # Check values
        @test isfinite(gdd5_f32)
        @test isfinite(tcm_f32)
        @test isfinite(gdd0_f32)
        @test isfinite(twm_f32)
        
        @test tcm_f32 == minimum(temp_f32)
        @test twm_f32 ≈ maximum(temp_f32)
        @test gdd5_f32 ≈ Float32(365 * (18.0 - 5.0))
        @test gdd0_f32 ≈ Float32(365 * 18.0)
    end
    
    @testset "Array Length Validation" begin
        temp_valid = fill(15.0, 12)
        prec_valid = fill(50.0, 12)
        dtemp_valid = fill(15.0, 365)
        
        # Test with wrong temp array length
        @test_throws BoundsError climdata(fill(15.0, 10), prec_valid, dtemp_valid)
        
        # Test with wrong prec array length
        @test_throws BoundsError climdata(temp_valid, fill(50.0, 10), dtemp_valid)
        
        # Test with wrong dtemp array length
        @test_throws BoundsError climdata(temp_valid, prec_valid, fill(15.0, 300))

    end
    
    @testset "Seasonal Pattern Tests" begin
        # Test realistic seasonal patterns
        
        # Northern hemisphere pattern
        temp_nh = [-5.0, -2.0, 3.0, 10.0, 17.0, 23.0, 26.0, 24.0, 18.0, 11.0, 3.0, -3.0]
        prec_nh = [60.0, 55.0, 65.0, 70.0, 80.0, 85.0, 90.0, 85.0, 75.0, 70.0, 65.0, 60.0]
        
        # Create seasonal daily temperatures
        dtemp_nh = vcat(
            fill(-5.0, 31), fill(-2.0, 28), fill(3.0, 31), fill(10.0, 30),
            fill(17.0, 31), fill(23.0, 30), fill(26.0, 31), fill(24.0, 31),
            fill(18.0, 30), fill(11.0, 31), fill(3.0, 30), fill(-3.0, 31)
        )
        
        tcm_nh, gdd5_nh, gdd0_nh, twm_nh = climdata(temp_nh, prec_nh, dtemp_nh)
        
        @test tcm_nh == minimum(temp_nh)
        @test tcm_nh ≈ -5.0
        
        @test twm_nh ≈ maximum(temp_nh)
        
        # Calculate expected GDD5
        expected_gdd5_nh = sum(max.(dtemp_nh .- 5.0, 0.0))
        @test gdd5_nh ≈ expected_gdd5_nh
        
        # Only warm months should contribute significantly
        warm_months_days = 31 + 30 + 31 + 31 + 30  # May through September
        cold_contribution = sum(max.(vcat(fill(-5.0, 31), fill(-2.0, 28), fill(3.0, 31), fill(10.0, 30)) .- 5.0, 0.0))
        warm_contribution = sum(max.(vcat(fill(17.0, 31), fill(23.0, 30), fill(26.0, 31), fill(24.0, 31), fill(18.0, 30)) .- 5.0, 0.0))

        @test warm_contribution > cold_contribution
    end
    
    @testset "Edge Case - All Same Values" begin
        # Test with all temperatures the same
        temp_same = fill(10.0, 12)
        prec_same = fill(25.0, 12)
        dtemp_same = fill(10.0, 365)
        
        tcm_same, gdd5_same, gdd0_same, twm_same = climdata(temp_same, prec_same, dtemp_same)
        
        @test tcm_same ≈ 10.0
        @test twm_same ≈ 10.0
        @test gdd5_same ≈ 365 * (10.0 - 5.0)
        @test gdd5_same ≈ 1825.0
        @test gdd0_same ≈ 365 * 10.0
        
        @test all(isfinite.([gdd5_same, tcm_same, gdd0_same, twm_same]))
    end
    
    @testset "Mathematical Properties Tests" begin
        # Test mathematical properties and relationships
        
        temp_math = [5.0, 8.0, 12.0, 16.0, 20.0, 24.0, 26.0, 23.0, 18.0, 13.0, 8.0, 4.0]
        prec_math = [40.0, 45.0, 50.0, 55.0, 60.0, 65.0, 60.0, 55.0, 50.0, 45.0, 40.0, 35.0]
        dtemp_math = fill(15.0, 365)
        
        tcm_math, gdd5_math, gdd0_math, twm_math = climdata(temp_math, prec_math, dtemp_math)
        
        # GDD5 should be non-negative
        @test gdd5_math >= 0.0
        
        # TCM should be ≤ all monthly temperatures
        @test all(tcm_math .<= temp_math)
        
        # TWM should be >= all monthly temperatures
        @test twm_math ≈ maximum(temp_math)
        
        # If all daily temps are above 5°C, GDD5 should be positive
        if all(dtemp_math .> 5.0)
            @test gdd5_math > 0.0
        end
        
        # Test scaling: doubling daily temps above 5°C should roughly double GDD5
        dtemp_math_double = fill(25.0, 365)  # 25 vs 15, both above 5
        _, gdd5_double, _, _ = climdata(temp_math, prec_math, dtemp_math_double)
        
        expected_ratio = (25.0 - 5.0) / (15.0 - 5.0)
        actual_ratio = gdd5_double / gdd5_math
        @test abs(actual_ratio - expected_ratio) < 0.01
    end
    
    @testset "Boundary Temperature Tests" begin
        # Test temperatures exactly at GDD threshold
        temp_boundary = fill(4.9, 12)
        prec_boundary = fill(29.0, 12)
        
        # Daily temps exactly at 5°C
        dtemp_at_threshold = fill(4.9, 365)
        _, gdd5_at, _, _ = climdata(temp_boundary, prec_boundary, dtemp_at_threshold)
        @test gdd5_at ≈ 0.0
        
        # Daily temps just above 5°C
        dtemp_just_above = fill(5.01, 365)
        _, gdd5_above, _, _ = climdata(temp_boundary, prec_boundary, dtemp_just_above)
        @test gdd5_above > 0.0
        @test gdd5_above ≈ 365 * 0.01
        
        # Daily temps just below 5°C
        dtemp_just_below = fill(4.99, 365)
        _, gdd5_below, _, _ = climdata(temp_boundary, prec_boundary, dtemp_just_below)
        @test gdd5_below ≈ 0.0
    end
    
    @testset "Environment Data Override Tests" begin
        # Test basic env data functionality
        temp_test = [5.0, 8.0, 12.0, 16.0, 20.0, 24.0, 26.0, 23.0, 18.0, 13.0, 8.0, 4.0]
        prec_test = fill(50.0, 12)
        dtemp_test = fill(15.0, 365)
        
        # First get calculated values without env
        tcm_calc, gdd5_calc, gdd0_calc, twm_calc = climdata(temp_test, prec_test, dtemp_test)
        
        # Test complete override of all values
        env_complete = (
            tcm = -30.0,
            gdd5 = 2000.0, 
            gdd0 = 3500.0,
            twm = 35.0
        )
        
        tcm_env, gdd5_env, gdd0_env, twm_env = climdata(temp_test, prec_test, dtemp_test, env_complete)
        
        # All values should come from env, not calculated
        @test tcm_env ≈ -30.0
        @test gdd5_env ≈ 2000.0
        @test gdd0_env ≈ 3500.0
        @test twm_env ≈ 35.0
        
        # Verify they are different from calculated values
        @test tcm_env != tcm_calc
        @test gdd5_env != gdd5_calc
        @test gdd0_env != gdd0_calc
        @test twm_env != twm_calc
        
        # Test partial override - only some values provided
        env_partial = (tcm = -15.0, twm = 40.0)
        
        tcm_partial, gdd5_partial, gdd0_partial, twm_partial = climdata(temp_test, prec_test, dtemp_test, env_partial)
        
        # Overridden values should come from env
        @test tcm_partial ≈ -15.0
        @test twm_partial ≈ 40.0
        
        # Non-overridden values should be calculated
        @test gdd5_partial ≈ gdd5_calc
        @test gdd0_partial ≈ gdd0_calc
        
        # Test single value override
        env_single = (gdd5 = 1234.5,)
        
        tcm_single, gdd5_single, gdd0_single, twm_single = climdata(temp_test, prec_test, dtemp_test, env_single)
        
        # Only gdd5 should be overridden
        @test gdd5_single ≈ 1234.5
        @test tcm_single ≈ tcm_calc
        @test gdd0_single ≈ gdd0_calc
        @test twm_single ≈ twm_calc
        
        # Test empty env (should behave like no env)
        env_empty = NamedTuple()
        
        tcm_empty, gdd5_empty, gdd0_empty, twm_empty = climdata(temp_test, prec_test, dtemp_test, env_empty)
        
        # All values should be calculated (same as no env)
        @test tcm_empty ≈ tcm_calc
        @test gdd5_empty ≈ gdd5_calc
        @test gdd0_empty ≈ gdd0_calc
        @test twm_empty ≈ twm_calc
        
        # Test nothing env explicitly
        tcm_nothing, gdd5_nothing, gdd0_nothing, twm_nothing = climdata(temp_test, prec_test, dtemp_test, nothing)
        
        # Should be same as calculated values
        @test tcm_nothing ≈ tcm_calc
        @test gdd5_nothing ≈ gdd5_calc
        @test gdd0_nothing ≈ gdd0_calc
        @test twm_nothing ≈ twm_calc
    end
    
    @testset "Environment Data Type Consistency Tests" begin
        # Test that env data maintains type consistency
        temp_f32 = Float32[10.0, 12.0, 15.0, 18.0, 22.0, 25.0, 27.0, 25.0, 20.0, 15.0, 12.0, 8.0]
        prec_f32 = Float32.(fill(40.0, 12))
        dtemp_f32 = Float32.(fill(18.0, 365))
        
        # Test with Float32 env data
        env_f32 = (
            tcm = Float32(-10.0),
            gdd5 = Float32(1500.0),
            gdd0 = Float32(2800.0),
            twm = Float32(30.0)
        )
        
        tcm_f32_env, gdd5_f32_env, gdd0_f32_env, twm_f32_env = climdata(temp_f32, prec_f32, dtemp_f32, env_f32)
        
        # Results should maintain Float32 type
        @test typeof(tcm_f32_env) == Float32
        @test typeof(gdd5_f32_env) == Float32
        @test typeof(gdd0_f32_env) == Float32
        @test typeof(twm_f32_env) == Float32
        
        # Values should match env data
        @test tcm_f32_env ≈ Float32(-10.0)
        @test gdd5_f32_env ≈ Float32(1500.0)
        @test gdd0_f32_env ≈ Float32(2800.0)
        @test twm_f32_env ≈ Float32(30.0)
    end
    
    @testset "Environment Data Validation Tests" begin
        # Test env data with different key names (should be ignored)
        temp_test = fill(15.0, 12)
        prec_test = fill(50.0, 12)
        dtemp_test = fill(15.0, 365)
        
        # Get baseline calculated values
        tcm_baseline, gdd5_baseline, gdd0_baseline, twm_baseline = climdata(temp_test, prec_test, dtemp_test)
        
        # Test env with irrelevant keys
        env_irrelevant = (
            temperature_min = -20.0,
            growing_degree_days = 1800.0,
            some_other_var = 999.0,
            tcm = -5.0  # Only this should be used
        )
        
        tcm_irr, gdd5_irr, gdd0_irr, twm_irr = climdata(temp_test, prec_test, dtemp_test, env_irrelevant)
        
        # Only tcm should be overridden
        @test tcm_irr ≈ -5.0
        @test gdd5_irr ≈ gdd5_baseline
        @test gdd0_irr ≈ gdd0_baseline
        @test twm_irr ≈ twm_baseline
        
        # Test env with extreme values
        env_extreme = (
            tcm = -100.0,
            gdd5 = 0.0,
            gdd0 = 50000.0,
            twm = 100.0
        )
        
        tcm_ext, gdd5_ext, gdd0_ext, twm_ext = climdata(temp_test, prec_test, dtemp_test, env_extreme)
        
        # Should accept extreme values from env
        @test tcm_ext ≈ -100.0
        @test gdd5_ext ≈ 0.0
        @test gdd0_ext ≈ 50000.0
        @test twm_ext ≈ 100.0
        
        # All should be finite
        @test all(isfinite.([tcm_ext, gdd5_ext, gdd0_ext, twm_ext]))
    end
end