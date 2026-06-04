using Test

@testset "Table Lookup Tests" begin
    
    @testset "Exact Temperature Matches" begin
        # Test all exact temperature points in the table
        expected_results = [
            (-5.0, 64.6, 2.513),
            (0.0, 64.9, 2.501),
            (5.0, 65.2, 2.489),
            (10.0, 65.6, 2.477),
            (15.0, 65.9, 2.465),
            (20.0, 66.1, 2.454),
            (25.0, 66.5, 2.442),
            (30.0, 66.8, 2.430),
            (35.0, 67.2, 2.418),
            (40.0, 67.5, 2.406),
            (45.0, 67.8, 2.394)
        ]
        
        for (tas, expected_gamma, expected_lambda) in expected_results
            gamma, lambda_val = table(tas)
            
            @test gamma ≈ expected_gamma atol=1e-10
            @test lambda_val ≈ expected_lambda atol=1e-10
            @test typeof(gamma) == Float64
            @test typeof(lambda_val) == Float64
        end
    end
    
    @testset "Step-wise Lookup Behavior" begin
        # Test that the function uses step-wise lookup (≤ comparison)
        # Temperature slightly below a table point should use that point's values
        
        # Test just below 0°C - should use 0°C values
        gamma_below_0, lambda_below_0 = table(-0.1)
        gamma_at_0, lambda_at_0 = table(0.0)
        
        @test gamma_below_0 == gamma_at_0
        @test lambda_below_0 == lambda_at_0
        @test gamma_below_0 ≈ 64.9
        @test lambda_below_0 ≈ 2.501
        
        # Test just below 10°C - should use 10°C values
        gamma_below_10, lambda_below_10 = table(9.9)
        gamma_at_10, lambda_at_10 = table(10.0)
        
        @test gamma_below_10 == gamma_at_10
        @test lambda_below_10 == lambda_at_10
        @test gamma_below_10 ≈ 65.6
        @test lambda_below_10 ≈ 2.477
        
        # Test between table points - should use the next higher table point
        gamma_between, lambda_between = table(7.5)  # Between 5°C and 10°C
        gamma_at_10_check, lambda_at_10_check = table(10.0)
        
        @test gamma_between == gamma_at_10_check
        @test lambda_between == lambda_at_10_check
    end
    
    @testset "Below Minimum Temperature" begin
        # Test temperatures below the minimum table value (-5°C)
        test_tass = [-10.0, -20.0, -100.0]
        
        for tas in test_tass
            gamma, lambda_val = table(tas)
            
            # Should use the -5°C values (first entry)
            @test gamma ≈ 64.6
            @test lambda_val ≈ 2.513
            @test isfinite(gamma)
            @test isfinite(lambda_val)
        end
    end
    
    @testset "Above Maximum Temperature" begin
        # Test temperatures above the maximum table value (45°C)
        test_tass = [50.0, 100.0, 1000.0]
        
        for tas in test_tass
            gamma, lambda_val = table(tas)
            
            # Should use the 45°C values (last entry)
            @test gamma ≈ 67.8
            @test lambda_val ≈ 2.394
            @test isfinite(gamma)
            @test isfinite(lambda_val)
        end
    end
    
    @testset "Intermediate Temperature Tests" begin
        # Test various intermediate temperatures to verify step behavior
        
        # Between -5°C and 0°C - should use 0°C values
        gamma_neg2, lambda_neg2 = table(-2.0)
        @test gamma_neg2 ≈ 64.9
        @test lambda_neg2 ≈ 2.501
        
        # Between 15°C and 20°C - should use 20°C values
        gamma_17, lambda_17 = table(17.5)
        @test gamma_17 ≈ 66.1
        @test lambda_17 ≈ 2.454
        
        # Between 30°C and 35°C - should use 35°C values
        gamma_32, lambda_32 = table(32.0)
        @test gamma_32 ≈ 67.2
        @test lambda_32 ≈ 2.418
        
        # Test edge case: temperature exactly between two points
        gamma_mid, lambda_mid = table(12.5)  # Exactly between 10°C and 15°C
        @test gamma_mid ≈ 65.9  # Should use 15°C values
        @test lambda_mid ≈ 2.465
    end
    
    @testset "Type Consistency Tests" begin
        # Test with Float32 input
        tas_f32 = Float32(15.0)
        gamma_f32, lambda_f32 = table(tas_f32)
        
        @test typeof(gamma_f32) == Float32
        @test typeof(lambda_f32) == Float32
        @test gamma_f32 ≈ Float32(65.9)
        @test lambda_f32 ≈ Float32(2.465)
        
        # Test with Integer input - should throw InexactError
        tas_int = Int(20)
        @test_throws InexactError table(tas_int)
        
        # Test with Float64 (default)
        tas_f64 = 25.0
        gamma_f64, lambda_f64 = table(tas_f64)
        
        @test typeof(gamma_f64) == Float64
        @test typeof(lambda_f64) == Float64
        @test gamma_f64 ≈ 66.5
        @test lambda_f64 ≈ 2.442
    end
    
    @testset "Gamma and Lambda Relationship Tests" begin
        # Test that gamma generally increases with temperature
        tass = [-5.0, 0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 30.0, 35.0, 40.0, 45.0]
        gammas = Float64[]
        lambdas = Float64[]
        
        for tas in tass
            gamma, lambda_val = table(tas)
            push!(gammas, gamma)
            push!(lambdas, lambda_val)
        end
        
        # Gamma should be monotonically increasing
        for i in 2:length(gammas)
            @test gammas[i] >= gammas[i-1]
        end
        
        # Lambda should be monotonically decreasing
        for i in 2:length(lambdas)
            @test lambdas[i] <= lambdas[i-1]
        end
        
        # Test reasonable ranges
        @test all(64.0 .<= gammas .<= 68.0)  # Gamma in reasonable range
        @test all(2.3 .<= lambdas .<= 2.6)   # Lambda in reasonable range
    end
    
    @testset "Zero Temperature Test" begin
        # Specific test for 0°C (common reference point)
        gamma_zero, lambda_zero = table(0.0)
        
        @test gamma_zero ≈ 64.9
        @test lambda_zero ≈ 2.501
        @test isfinite(gamma_zero)
        @test isfinite(lambda_zero)
        
        # Test temperatures very close to zero
        gamma_near_zero_pos, lambda_near_zero_pos = table(0.0001)
        gamma_near_zero_neg, lambda_near_zero_neg = table(-0.0001)
        
        # Both should use the same table entry (0°C for positive, 0°C for negative)
        @test gamma_near_zero_pos ≈ 65.2  # Uses 5°C entry
        @test lambda_near_zero_pos ≈ 2.489
        @test gamma_near_zero_neg ≈ 64.9  # Uses 0°C entry
        @test lambda_near_zero_neg ≈ 2.501
    end
    
    @testset "Extreme Value Tests" begin
        # Test with very extreme temperatures
        
        # Extremely cold
        gamma_extreme_cold, lambda_extreme_cold = table(-273.15)  # Absolute zero
        @test gamma_extreme_cold ≈ 64.6  # Should use -5°C entry
        @test lambda_extreme_cold ≈ 2.513
        @test isfinite(gamma_extreme_cold)
        @test isfinite(lambda_extreme_cold)
        
        # Extremely hot
        gamma_extreme_hot, lambda_extreme_hot = table(1000.0)
        @test gamma_extreme_hot ≈ 67.8  # Should use 45°C entry
        @test lambda_extreme_hot ≈ 2.394
        @test isfinite(gamma_extreme_hot)
        @test isfinite(lambda_extreme_hot)
        
        # Test with very large Float64 values
        gamma_large, lambda_large = table(1e10)
        @test gamma_large ≈ 67.8
        @test lambda_large ≈ 2.394
        @test isfinite(gamma_large)
        @test isfinite(lambda_large)
        
        # Test with very small Float64 values
        gamma_small, lambda_small = table(-1e10)
        @test gamma_small ≈ 64.6
        @test lambda_small ≈ 2.513
        @test isfinite(gamma_small)
        @test isfinite(lambda_small)
    end
    
    @testset "Boundary Precision Tests" begin
        # Test values very close to table boundaries to ensure correct behavior
        
        # Just below and at boundary points
        test_cases = [
            (-5.0, 64.6, 2.513),      # Exact minimum
            (-4.999999, 64.9, 2.501), # Just above minimum (should use 0°C)
            (44.999999, 67.8, 2.394), # Just below maximum (should use 45°C)
            (45.0, 67.8, 2.394),      # Exact maximum
            (45.000001, 67.8, 2.394)  # Just above maximum (should use 45°C)
        ]
        
        for (tas, expected_gamma, expected_lambda) in test_cases
            gamma, lambda_val = table(tas)
            @test gamma ≈ expected_gamma atol=1e-10
            @test lambda_val ≈ expected_lambda atol=1e-10
        end
    end
    
    @testset "Return Value Validation" begin
        # Test that return values are always valid (not nothing)
        test_tass = [-100.0, -5.0, 0.0, 22.5, 45.0, 100.0]
        
        for tas in test_tass
            gamma, lambda_val = table(tas)
            
            @test gamma !== nothing
            @test lambda_val !== nothing
            @test isfinite(gamma)
            @test isfinite(lambda_val)
            @test gamma > 0.0
            @test lambda_val > 0.0
        end
    end
    
    @testset "Interpolation Behavior Verification" begin
        # Verify the step-wise (non-interpolating) behavior
        # The function should NOT interpolate between table points
        
        # Test a range of temperatures between two table points
        tass_between = [5.1, 6.0, 7.5, 9.0, 9.9]  # Between 5°C and 10°C
        
        for tas in tass_between
            gamma, lambda_val = table(tas)
            # All should use the 10°C table entry (next higher)
            @test gamma ≈ 65.6
            @test lambda_val ≈ 2.477
        end
        
        # Test another range
        tass_between_2 = [25.1, 27.0, 29.9]  # Between 25°C and 30°C
        
        for tas in tass_between_2
            gamma, lambda_val = table(tas)
            # All should use the 30°C table entry
            @test gamma ≈ 66.8
            @test lambda_val ≈ 2.430
        end
    end
    
    @testset "Performance and Consistency Tests" begin
        # Test that the function is consistent across multiple calls
        test_tas = 12.5
        
        results = [table(test_tas) for _ in 1:100]
        
        # All results should be identical
        first_result = results[1]
        for result in results
            @test result[1] == first_result[1]  # gamma
            @test result[2] == first_result[2]  # lambda
        end
        
        # Test with a range of inputs for consistency
        tass = [-10.0, 0.0, 15.0, 30.0, 50.0]
        
        for tas in tass
            # Call multiple times
            result1 = table(tas)
            result2 = table(tas)
            result3 = table(tas)
            
            @test result1 == result2 == result3
        end
    end
    
    @testset "Table Completeness Tests" begin
        # Test that the table covers expected range and has expected properties
        
        # Get all table values
        table_tass = [-5.0, 0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 30.0, 35.0, 40.0, 45.0]
        
        gammas = [table(tas)[1] for tas in table_tass]
        lambdas = [table(tas)[2] for tas in table_tass]
        
        # Check that we have 11 points (as expected from the table)
        @test length(gammas) == 11
        @test length(lambdas) == 11
        
        # Check ranges are reasonable
        @test minimum(gammas) ≈ 64.6
        @test maximum(gammas) ≈ 67.8
        @test minimum(lambdas) ≈ 2.394
        @test maximum(lambdas) ≈ 2.513
        
        # Check monotonicity
        @test issorted(gammas)          # Gamma increases with temperature
        @test issorted(lambdas, rev=true)  # Lambda decreases with temperature
    end
end