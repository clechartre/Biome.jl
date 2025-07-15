using Test


@testset "Climate Data Tests" begin
    
    @testset "Positive Test - Temperate Climate" begin
        # Realistic temperate climate data
        temp = [-2.0, 1.0, 6.0, 12.0, 18.0, 22.0, 25.0, 23.0, 18.0, 12.0, 6.0, 1.0]  # Monthly temps
        prec = [50.0, 60.0, 70.0, 80.0, 90.0, 100.0, 80.0, 70.0, 80.0, 90.0, 70.0, 60.0]  # Monthly precip
        
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
        
        tcm, gdd5, wmin, warm = climdata(temp, prec, dtemp)
        
        # Check return types
        @test typeof(gdd5) == Float64
        @test typeof(tcm) == Float64
        @test typeof(wmin) == Float64
        @test typeof(warm) == Float64
        
        # Check that all values are finite
        @test isfinite(gdd5)
        @test isfinite(tcm)
        @test isfinite(wmin)
        @test isfinite(warm)
        
        # TCM should be the coldest monthly temperature
        @test tcm == minimum(temp)
        @test tcm ≈ -2.0
        
        # Total precipitation should equal sum of monthly precip
        @test warm ≈ maximum(temp)
        @test warm ≈ 25.0
        
        # GDD5 should be positive (has days > 5°C)
        @test gdd5 > 0.0
        
        # Calculate expected GDD5 manually
        expected_gdd5 = sum(max.(dtemp .- 5.0, 0.0))
        @test gdd5 ≈ expected_gdd5
        
        # wmin should be based on warmest month
        @test wmin > 0.0
    end
    
    @testset "Tropical Climate Tests" begin
        # Tropical climate - consistently warm
        temp_tropical = [26.0, 27.0, 28.0, 29.0, 28.0, 27.0, 26.0, 26.0, 27.0, 28.0, 27.0, 26.0]
        prec_tropical = [200.0, 150.0, 100.0, 50.0, 30.0, 20.0, 25.0, 40.0, 80.0, 150.0, 180.0, 220.0]
        dtemp_tropical = fill(27.0, 365)  # Simplified constant daily temp
        
        tcm_trop, gdd5_trop, wmin_trop, warm_trop = climdata(temp_tropical, prec_tropical, dtemp_tropical)
        
        @test all(isfinite.([gdd5_trop, tcm_trop, wmin_trop, warm_trop]))
        
        # TCM should be minimum temperature
        @test tcm_trop == minimum(temp_tropical)
        @test tcm_trop ≈ 26.0
        
        # Total precipitation
        @test warm_trop ≈ maximum(temp_tropical)
        @test warm_trop ≈ 29.0
        
        # GDD5 should be very high (all days well above 5°C)
        @test gdd5_trop > 5000.0  # (27-5) * 365 = 8030
        expected_gdd5_trop = 365 * (27.0 - 5.0)
        @test gdd5_trop ≈ expected_gdd5_trop
        
        # wmin should be positive
        @test wmin_trop > 0.0
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
        
        tcm_arctic, gdd5_arctic, wmin_arctic, warm_arctic = climdata(temp_arctic, prec_arctic, dtemp_arctic)
        
        @test all(isfinite.([gdd5_arctic, tcm_arctic, wmin_arctic, warm_arctic]))
        
        # TCM should be very cold
        @test tcm_arctic == minimum(temp_arctic)
        @test tcm_arctic ≈ -25.0
        
        # TWM should be very cold
        @test warm_arctic ≈ maximum(temp_arctic)
        @test warm_arctic ≈ 12.0
        
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
        
        tcm_test, gdd5_test,  wmin_test, warm_test = climdata(temp_test, prec_test, dtemp_test)
        
        # TCM should be coldest month
        @test tcm_test == minimum(temp_test)
        @test tcm_test ≈ -5.0
        
        # Test with extreme cold
        temp_extreme_cold = fill(-50.0, 12)
        dtemp_extreme_cold = fill(-50.0, 365)
        
        tcm_extreme, gdd5_extreme, wmin_extreme, warm_extreme = climdata(temp_extreme_cold, prec_test, dtemp_extreme_cold)
        
        @test tcm_extreme ≈ -50.0
        @test gdd5_extreme ≈ 0.0
        
        # Test with extreme heat
        temp_extreme_hot = fill(50.0, 12)
        dtemp_extreme_hot = fill(50.0, 365)
        
        tcm_hot, gdd5_hot, wmin_hot, warm_hot = climdata(temp_extreme_hot, prec_test, dtemp_extreme_hot)
        
        @test tcm_hot ≈ 50.0
        @test gdd5_hot ≈ 365 * (50.0 - 5.0)
        @test gdd5_hot ≈ 16425.0
    end
    
    
    @testset "Type Consistency Tests" begin
        # Test with Float32
        temp_f32 = Float32[10.0, 12.0, 15.0, 18.0, 22.0, 25.0, 27.0, 25.0, 20.0, 15.0, 12.0, 8.0]
        prec_f32 = Float32.(fill(40.0, 12))
        dtemp_f32 = Float32.(fill(18.0, 365))
        
        tcm_f32, gdd5_f32, wmin_f32, warm_f32 = climdata(temp_f32, prec_f32, dtemp_f32)
        
        # Check type preservation
        @test typeof(gdd5_f32) == Float32
        @test typeof(tcm_f32) == Float32
        @test typeof(wmin_f32) == Float32
        @test typeof(warm_f32) == Float32
        
        # Check values
        @test isfinite(gdd5_f32)
        @test isfinite(tcm_f32)
        @test isfinite(wmin_f32)
        @test isfinite(warm_f32)
        
        @test tcm_f32 == minimum(temp_f32)
        @test warm_f32 ≈ maximum(temp_f32)
        @test gdd5_f32 ≈ Float32(365 * (18.0 - 5.0))
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
        
        tcm_nh, gdd5_nh, wmin_nh, warm_nh = climdata(temp_nh, prec_nh, dtemp_nh)
        
        @test tcm_nh == minimum(temp_nh)
        @test tcm_nh ≈ -5.0
        
        @test warm_nh ≈ maximum(temp_nh)
        
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
        
        tcm_same,gdd5_same, wmin_same, warm_same = climdata(temp_same, prec_same, dtemp_same)
        
        @test tcm_same ≈ 10.0
        @test warm_same ≈ 10.0
        @test gdd5_same ≈ 365 * (10.0 - 5.0)
        @test gdd5_same ≈ 1825.0
        
        @test all(isfinite.([gdd5_same, tcm_same, wmin_same, warm_same]))
    end
    
    @testset "Mathematical Properties Tests" begin
        # Test mathematical properties and relationships
        
        temp_math = [5.0, 8.0, 12.0, 16.0, 20.0, 24.0, 26.0, 23.0, 18.0, 13.0, 8.0, 4.0]
        prec_math = [40.0, 45.0, 50.0, 55.0, 60.0, 65.0, 60.0, 55.0, 50.0, 45.0, 40.0, 35.0]
        dtemp_math = fill(15.0, 365)
        
        tcm_math, gdd5_math, wmin_math, warm_math = climdata(temp_math, prec_math, dtemp_math)
        
        # GDD5 should be non-negative
        @test gdd5_math >= 0.0
        
        # TCM should be ≤ all monthly temperatures
        @test all(tcm_math .<= temp_math)
        
        # TWM should be >= all monthly temperatures
        @test warm_math ≈ maximum(temp_math)
        
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
end