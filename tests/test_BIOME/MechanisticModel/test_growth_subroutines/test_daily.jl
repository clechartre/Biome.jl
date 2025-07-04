using Test

include("../../../../src/models/MechanisticModel/growth_subroutines/daily.jl")

@testset "Daily Interpolation Tests" begin
    
    @testset "Positive Test - Normal monthly patterns" begin
        # Test with typical temperate climate pattern (temperature-like)
        mly_temp = [0.0, 2.0, 8.0, 15.0, 20.0, 25.0, 28.0, 26.0, 20.0, 12.0, 5.0, 1.0]
        dly_temp = daily(mly_temp)
        
        # Check output length
        @test length(dly_temp) == 365
        
        # Check that all values are finite
        @test all(isfinite.(dly_temp))
        
        # Check that values at midday points match input (approximately)
        midday = [16, 44, 75, 105, 136, 166, 197, 228, 258, 289, 319, 350]
        for i in 1:12
            @test dly_temp[midday[i]] ≈ mly_temp[i] atol=1e-10
        end
        
        # Test with precipitation pattern (always positive)
        mly_precip = [50.0, 45.0, 60.0, 80.0, 100.0, 120.0, 90.0, 85.0, 95.0, 75.0, 60.0, 55.0]
        dly_precip = daily(mly_precip)
        @test length(dly_precip) == 365
        @test all(isfinite.(dly_precip))
        @test all(dly_precip .>= 0.0)  # Precipitation should be non-negative
        
        # Test with solar radiation pattern
        mly_solar = [10.0, 15.0, 22.0, 28.0, 32.0, 35.0, 33.0, 30.0, 25.0, 18.0, 12.0, 8.0]
        dly_solar = daily(mly_solar)
        @test length(dly_solar) == 365
        @test all(isfinite.(dly_solar))
        
        # Check that interpolated values are between adjacent monthly values
        for i in 1:11
            start_day = midday[i]
            end_day = midday[i+1]
            min_val = min(mly_solar[i], mly_solar[i+1])
            max_val = max(mly_solar[i], mly_solar[i+1])
            
            for day in start_day:end_day
                @test min_val <= dly_solar[day] <= max_val
            end
        end
    end
    
    @testset "Mathematical Correctness Tests" begin
        # Test with constant monthly values
        mly_constant = fill(10.0, 12)
        dly_constant = daily(mly_constant)
        @test length(dly_constant) == 365
        @test all(dly_constant .≈ 10.0)  # All daily values should be constant
        
        # Test with linear trend (increasing by 1 each month)
        mly_linear = Float64[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
        dly_linear = daily(mly_linear)
        @test length(dly_linear) == 365
        @test all(isfinite.(dly_linear))
        
        # Check midday values
        midday = [16, 44, 75, 105, 136, 166, 197, 228, 258, 289, 319, 350]
        for i in 1:12
            @test dly_linear[midday[i]] ≈ Float64(i) atol=1e-10
        end
        
        # Test with alternating pattern
        mly_alternating = [0.0, 10.0, 0.0, 10.0, 0.0, 10.0, 0.0, 10.0, 0.0, 10.0, 0.0, 10.0]
        dly_alternating = daily(mly_alternating)
        @test length(dly_alternating) == 365
        @test all(isfinite.(dly_alternating))
        
        # Check that interpolation creates smooth transitions
        for i in 1:11
            start_day = midday[i]
            end_day = midday[i+1]
            
            # Check that values change monotonically between middays
            if mly_alternating[i] < mly_alternating[i+1]
                for day in start_day:(end_day-1)
                    @test dly_alternating[day] <= dly_alternating[day+1]
                end
            elseif mly_alternating[i] > mly_alternating[i+1]
                for day in start_day:(end_day-1)
                    @test dly_alternating[day] >= dly_alternating[day+1]
                end
            end
        end
    end
    
    @testset "Boundary Conditions Tests" begin
        # Test December to January transition
        mly_boundary = [5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 11.0, 10.0, 8.0, 6.0]
        dly_boundary = daily(mly_boundary)
        @test length(dly_boundary) == 365
        # Check that December to January transition is smooth
        # Days 350-365 and 1-15 should show smooth transition from December to January
        @test isfinite(dly_boundary[350])
        @test isfinite(dly_boundary[365])
        @test isfinite(dly_boundary[1])
        @test isfinite(dly_boundary[15])
        
        # The transition should be approximately linear
        # From day 350 (Dec midpoint) to day 16 (Jan midpoint)
        dec_to_jan_slope = (mly_boundary[1] - mly_boundary[12]) / 31.0
        # Check a few points in the transition
        @test dly_boundary[351] ≈ dly_boundary[350] + dec_to_jan_slope atol=1e-10
        @test dly_boundary[365] ≈ dly_boundary[364] + dec_to_jan_slope atol=1e-10
        @test dly_boundary[2] ≈ dly_boundary[1] + dec_to_jan_slope atol=1e-10
        
        # Test with extreme seasonal contrast
        mly_extreme = [-20.0, -15.0, -5.0, 5.0, 15.0, 25.0, 30.0, 25.0, 15.0, 5.0, -5.0, -15.0]
        dly_extreme = daily(mly_extreme)
        @test length(dly_extreme) == 365
        @test all(isfinite.(dly_extreme))
        
        # Check that daily values don't exceed reasonable bounds
        @test minimum(dly_extreme) >= -25.0  # Shouldn't go much below minimum monthly
        @test maximum(dly_extreme) <= 35.0   # Shouldn't go much above maximum monthly
    end
    
    @testset "Edge Cases" begin
        # Test with all zeros
        mly_zeros = zeros(12)
        dly_zeros = daily(mly_zeros)
        
        @test length(dly_zeros) == 365
        @test all(dly_zeros .≈ 0.0)
        
        # Test with negative values
        mly_negative = [-5.0, -3.0, -1.0, 2.0, 5.0, 8.0, 10.0, 8.0, 5.0, 2.0, -1.0, -3.0]
        dly_negative = daily(mly_negative)
        @test length(dly_negative) == 365
        @test all(isfinite.(dly_negative))
        
        # Test with very large values
        mly_large = fill(1e6, 12)
        dly_large = daily(mly_large)
        @test length(dly_large) == 365
        @test all(dly_large .≈ 1e6)
        
        # Test with very small values
        mly_small = fill(1e-10, 12)
        dly_small = daily(mly_small)
        @test length(dly_small) == 365
        @test all(dly_small .≈ 1e-10)
        
        # Test with mixed positive/negative with large range
        mly_mixed = [-100.0, -50.0, 0.0, 50.0, 100.0, 150.0, 100.0, 50.0, 0.0, -50.0, -75.0, -90.0]
        dly_mixed = daily(mly_mixed)
        @test length(dly_mixed) == 365
        @test all(isfinite.(dly_mixed))
    end
    
    @testset "Error Conditions" begin
        # Test with wrong array length
        @test_throws ErrorException daily([1.0, 2.0, 3.0])  # Too short
        @test_throws ErrorException daily(fill(1.0, 15))     # Too long
        @test_throws ErrorException daily(Float64[])         # Empty
        
        # Test with 11 elements (off by one)
        @test_throws ErrorException daily(fill(2.0, 11))
        
        # Test with 13 elements (off by one)
        @test_throws ErrorException daily(fill(2.0, 13))
        
        # Test with single element
        @test_throws ErrorException daily([5.0])
    end
    
    @testset "Type Consistency Tests" begin
        # Test with Float32
        mly_f32 = Float32[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0]
        dly_f32 = daily(mly_f32)
        
        @test typeof(dly_f32) == Vector{Float32}
        @test length(dly_f32) == 365
        @test all(isfinite.(dly_f32))
        
        # Test with Float64
        mly_f64 = Float64[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0]
        dly_f64 = daily(mly_f64)
        @test typeof(dly_f64) == Vector{Float64}
        @test length(dly_f64) == 365
        @test all(isfinite.(dly_f64))
        
        # Test with integers (should throw InexactError)
        mly_int = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
        @test_throws InexactError daily(mly_int)
    end
    
    @testset "Interpolation Quality Tests" begin
        # Test that interpolation preserves area under curve (conservation test)
        mly_test = [10.0, 15.0, 20.0, 25.0, 30.0, 35.0, 30.0, 25.0, 20.0, 15.0, 12.0, 8.0]
        dly_test = daily(mly_test)
        
        # Sum should be approximately conserved (accounting for different sampling)
        monthly_sum = sum(mly_test) * (365.0 / 12.0)  # Scale monthly to daily equivalent
        daily_sum = sum(dly_test)
        
        # Should be reasonably close (within 10% due to interpolation differences)
        @test abs(daily_sum - monthly_sum) / monthly_sum < 0.1
        
        # Test smoothness: no large jumps in daily values
        for i in 1:364
            jump = abs(dly_test[i+1] - dly_test[i])
            @test jump < 5.0  # No jump should be larger than reasonable daily change
        end
        
        # Test that the function is deterministic
        dly_test2 = daily(mly_test)
        @test dly_test == dly_test2
    end
end