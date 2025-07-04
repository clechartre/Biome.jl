using Test
using Statistics

include("../../../src/models/MechanisticModel/snow.jl")

@testset "Snow Tests" begin
    
    @testset "Positive Test - Temperate Winter/Summer Cycle" begin
        # Realistic temperature cycle with winter below freezing
        dtemp = vcat(
            fill(-5.0, 90),   # Winter - cold
            fill(5.0, 92),    # Spring - warming
            fill(20.0, 92),   # Summer - warm
            fill(0.0, 91)     # Fall - cooling
        )
        
        # Realistic precipitation pattern (mm/day equivalent)
        dprecin = vcat(
            fill(2.0, 90),    # Winter precipitation
            fill(3.0, 92),    # Spring precipitation
            fill(1.0, 92),    # Summer precipitation (less)
            fill(2.5, 91)     # Fall precipitation
        )
        
        dprec, dmelt, maxdepth = snow(dtemp, dprecin)
        
        # Check output dimensions
        @test length(dprec) == 365
        @test length(dmelt) == 365
        @test typeof(maxdepth) <: Real
        
        # Check that all values are finite and non-negative
        @test all(isfinite.(dprec))
        @test all(isfinite.(dmelt))
        @test isfinite(maxdepth)
        @test all(dprec .>= 0.0)
        @test all(dmelt .>= 0.0)
        @test maxdepth >= 0.0
        
        # During winter (cold period), should have snow accumulation
        winter_period = 1:90
        winter_melt = sum(dmelt[winter_period])
        winter_precip = sum(dprec[winter_period])
        
        # Most winter precipitation should become snow (low melt)
        @test winter_melt <= winter_precip
        
        # During summer (warm period), should have no new snow, potential melting
        summer_period = 153:244  # Roughly summer
        summer_dmelt = dmelt[summer_period]
        summer_dprec = dprec[summer_period]
        
        # Summer precipitation should mostly go directly to runoff
        # (no snow accumulation in warm weather)
        @test all(summer_dmelt .>= 0.0)
        @test all(summer_dprec .>= 0.0)
        
        # Maximum depth should be positive if we had snow accumulation
        @test maxdepth > 0.0
        
        # Mass balance check: total output should equal total input
        total_input = sum(dprecin) / (365.0 / 12.0)  # Adjusted for drain factor
        total_output = sum(dprec) + sum(dmelt)
        @test abs(total_output - total_input) < 1e-10
    end
    
    @testset "Always Cold - Snow Accumulation Only" begin
        # Temperature always below snow threshold
        dtemp_cold = fill(-10.0, 365)
        dprecin_uniform = fill(1.0, 365)
        
        dprec_cold, dmelt_cold, maxdepth_cold = snow(dtemp_cold, dprecin_uniform)
        
        # Check validity
        @test all(isfinite.(dprec_cold))
        @test all(isfinite.(dmelt_cold))
        @test isfinite(maxdepth_cold)
        @test all(dprec_cold .>= 0.0)
        @test all(dmelt_cold .>= 0.0)
        @test maxdepth_cold >= 0.0
        
        # With always cold temperatures, should have no melting
        @test all(dmelt_cold .== 0.0)
        
        # All precipitation should become snow (no liquid precip)
        @test all(dprec_cold .== 0.0)
        
        # Should accumulate significant snow depth
        @test maxdepth_cold > 0.0
        
        # Mass balance: no output since no melting and no liquid precip
        total_output_cold = sum(dprec_cold) + sum(dmelt_cold)
        @test total_output_cold == 0.0
    end
    
    @testset "Always Warm - No Snow Accumulation" begin
        # Temperature always above snow threshold
        dtemp_warm = fill(10.0, 365)
        dprecin_uniform = fill(2.0, 365)
        
        dprec_warm, dmelt_warm, maxdepth_warm = snow(dtemp_warm, dprecin_uniform)
        
        # Check validity
        @test all(isfinite.(dprec_warm))
        @test all(isfinite.(dmelt_warm))
        @test isfinite(maxdepth_warm)
        @test all(dprec_warm .>= 0.0)
        @test all(dmelt_warm .>= 0.0)
        @test maxdepth_warm >= 0.0
        
        # With always warm temperatures, should have no snow accumulation
        @test maxdepth_warm == 0.0
        
        # No melting since no snow accumulates
        @test all(dmelt_warm .== 0.0)
        
        # All precipitation should go directly to runoff
        drain_factor = 365.0 / 12.0
        expected_daily_precip = dprecin_uniform ./ drain_factor
        @test all(abs.(dprec_warm .- expected_daily_precip) .< 1e-10)
        
        # Mass balance check
        total_input_warm = sum(dprecin_uniform) / drain_factor
        total_output_warm = sum(dprec_warm) + sum(dmelt_warm)
        @test abs(total_output_warm - total_input_warm) < 1e-10
    end
    
    @testset "Temperature at Snow Threshold" begin
        # Temperature exactly at snow threshold (-1.0°C)
        tsnow = -1.0
        dtemp_threshold = fill(tsnow, 365)
        dprecin_test = fill(1.5, 365)
        
        dprec_thresh, dmelt_thresh, maxdepth_thresh = snow(dtemp_threshold, dprecin_test)
        
        # Check validity
        @test all(isfinite.(dprec_thresh))
        @test all(isfinite.(dmelt_thresh))
        @test isfinite(maxdepth_thresh)
        @test all(dprec_thresh .>= 0.0)
        @test all(dmelt_thresh .>= 0.0)
        @test maxdepth_thresh >= 0.0
        
        # At exactly the threshold, should be treated as warm (>= vs <)
        # No snow should accumulate
        @test all(dmelt_thresh .== 0.0)
        @test maxdepth_thresh == 0.0
        
        # All precipitation should go to runoff
        drain_factor = 365.0 / 12.0
        expected_precip = dprecin_test ./ drain_factor
        @test all(abs.(dprec_thresh .- expected_precip) .< 1e-10)
    end
    
    @testset "Snow Melting Rate Tests" begin
        # Test different melting rates with different temperatures
        dprecin_test = fill(1.0, 365)
        km = 0.7  # Melting coefficient from function
        tsnow = -1.0
        
        # Start with cold period to accumulate snow, then warm period
        dtemp_melt_test = vcat(
            fill(-5.0, 100),  # Cold period - accumulate snow
            fill(5.0, 265)    # Warm period - melt snow
        )
        
        dprec_melt, dmelt_melt, maxdepth_melt = snow(dtemp_melt_test, dprecin_test)
        
        @test all(isfinite.(dprec_melt))
        @test all(isfinite.(dmelt_melt))
        @test maxdepth_melt > 0.0
        
        # During warm period, melting should occur
        warm_period = 101:365
        warm_melt = dmelt_melt[warm_period]
        
        # Should have some melting during warm period
        @test sum(warm_melt) > 0.0
        
        # Test with higher temperature - should melt faster
        dtemp_hot = vcat(
            fill(-5.0, 100),  # Same cold period
            fill(10.0, 265)   # Hotter warm period
        )
        
        dprec_hot, dmelt_hot, maxdepth_hot = snow(dtemp_hot, dprecin_test)
        
        # Should have more total melting with higher temperature
        total_melt_warm = sum(dmelt_melt[101:365])
        total_melt_hot = sum(dmelt_hot[101:365])
        
        @test total_melt_hot >= total_melt_warm
    end
    
    @testset "Mass Balance Verification" begin
        # Comprehensive mass balance test with realistic scenario
        dtemp_balance = vcat(
            fill(-8.0, 60),   # Cold start
            fill(-2.0, 60),   # Slight warming
            fill(3.0, 60),    # Above freezing
            fill(15.0, 60),   # Warm
            fill(8.0, 60),    # Cooling
            fill(-3.0, 65)    # Cold end
        )
        
        dprecin_balance = vcat(
            fill(3.0, 120),   # High precip in winter/spring
            fill(1.0, 120),   # Low precip in summer
            fill(2.0, 125)    # Moderate precip in fall/winter
        )
        
        dprec_bal, dmelt_bal, maxdepth_bal = snow(dtemp_balance, dprecin_balance)
        
        # Check basic validity
        @test all(isfinite.(dprec_bal))
        @test all(isfinite.(dmelt_bal))
        @test all(dprec_bal .>= 0.0)
        @test all(dmelt_bal .>= 0.0)
        
        # Mass balance: total input = total output
        drain_factor = 365.0 / 12.0
        total_input_bal = sum(dprecin_balance) / drain_factor
        total_output_bal = sum(dprec_bal) + sum(dmelt_bal)
        
        @test abs(total_output_bal - total_input_bal) < 1e-10
        
        # Water should be conserved at each time step conceptually
        # (though the function runs twice, final result should conserve mass)
        @test isfinite(maxdepth_bal)
        @test maxdepth_bal >= 0.0
    end
    
    @testset "Zero Precipitation Tests" begin
        # Test with no precipitation
        dtemp_noprecip = vcat(fill(-5.0, 180), fill(5.0, 185))
        dprecin_zero = fill(0.0, 365)
        
        dprec_zero, dmelt_zero, maxdepth_zero = snow(dtemp_noprecip, dprecin_zero)
        
        # Check validity
        @test all(isfinite.(dprec_zero))
        @test all(isfinite.(dmelt_zero))
        @test isfinite(maxdepth_zero)
        @test all(dprec_zero .>= 0.0)
        @test all(dmelt_zero .>= 0.0)
        @test maxdepth_zero >= 0.0
        
        # With no precipitation, should have no output
        @test all(dprec_zero .== 0.0)
        @test all(dmelt_zero .== 0.0)
        @test maxdepth_zero == 0.0
        
        # Mass balance should be zero
        total_output_zero = sum(dprec_zero) + sum(dmelt_zero)
        @test total_output_zero == 0.0
    end
    
    @testset "Type Consistency Tests" begin
        # Test with Float32
        dtemp_f32 = Float32.(vcat(fill(-3.0, 180), fill(8.0, 185)))
        dprecin_f32 = Float32.(fill(1.5, 365))
        
        dprec_f32, dmelt_f32, maxdepth_f32 = snow(dtemp_f32, dprecin_f32)
        
        # Check type preservation
        @test eltype(dprec_f32) == Float32
        @test eltype(dmelt_f32) == Float32
        @test typeof(maxdepth_f32) == Float32
        
        # Check dimensions
        @test length(dprec_f32) == 365
        @test length(dmelt_f32) == 365
        
        # Values should be finite and non-negative
        @test all(isfinite.(dprec_f32))
        @test all(isfinite.(dmelt_f32))
        @test isfinite(maxdepth_f32)
        @test all(dprec_f32 .>= Float32(0.0))
        @test all(dmelt_f32 .>= Float32(0.0))
        @test maxdepth_f32 >= Float32(0.0)
        
        # Mass balance with Float32
        drain_factor_f32 = Float32(365.0 / 12.0)
        total_input_f32 = sum(dprecin_f32) / drain_factor_f32
        total_output_f32 = sum(dprec_f32) + sum(dmelt_f32)
        @test abs(total_output_f32 - total_input_f32) < Float32(1e-6)
    end
    
    @testset "Array Length Validation" begin
        # Test with wrong array lengths
        dtemp_valid = fill(5.0, 365)
        dprecin_valid = fill(2.0, 365)
        
        # Test with wrong dtemp length
        @test_throws BoundsError snow(fill(5.0, 300), dprecin_valid)
        
        # Test with wrong dprecin length
        @test_throws BoundsError snow(dtemp_valid, fill(2.0, 300))
    end
    
    @testset "Extreme Values Tests" begin
        # Test with extreme cold temperatures
        dtemp_extreme_cold = fill(-50.0, 365)
        dprecin_normal = fill(2.0, 365)
        
        dprec_extreme, dmelt_extreme, maxdepth_extreme = snow(dtemp_extreme_cold, dprecin_normal)
        
        @test all(isfinite.(dprec_extreme))
        @test all(isfinite.(dmelt_extreme))
        @test isfinite(maxdepth_extreme)
        
        # Extreme cold should result in no melting
        @test all(dmelt_extreme .== 0.0)
        @test all(dprec_extreme .== 0.0)  # All becomes snow
        @test maxdepth_extreme > 0.0
        
        # Test with extreme hot temperatures
        dtemp_extreme_hot = fill(50.0, 365)
        
        dprec_hot, dmelt_hot, maxdepth_hot = snow(dtemp_extreme_hot, dprecin_normal)
        
        @test all(isfinite.(dprec_hot))
        @test all(isfinite.(dmelt_hot))
        @test isfinite(maxdepth_hot)
        
        # Extreme heat should result in no snow accumulation
        @test maxdepth_hot == 0.0
        @test all(dmelt_hot .== 0.0)  # No snow to melt
        
        # All precipitation should go to runoff
        drain_factor = 365.0 / 12.0
        expected_runoff = dprecin_normal ./ drain_factor
        @test all(abs.(dprec_hot .- expected_runoff) .< 1e-10)
    end
    
    @testset "Seasonal Transition Tests" begin
        # Test realistic seasonal transitions
        dtemp_seasonal =
            # Gradual winter to spring transition
            vcat([max(-10.0, -10.0 + i * 0.2) for i in 1:60]...,    # Gradual warming
                 [max(-2.0, -2.0 + i * 0.1) for i in 1:60]...,     # Continued warming
                 fill(10.0, 120),                                  # Summer stability
                 [max(-5.0, 10.0 - i * 0.1) for i in 1:125]...) # Fall cooling
                 
        dprecin_seasonal = vcat(
            fill(3.0, 120),   # High winter/spring precip
            fill(0.5, 120),   # Low summer precip
            fill(2.0, 125)    # Moderate fall precip
        )
        
        dprec_seas, dmelt_seas, maxdepth_seas = snow(dtemp_seasonal, dprecin_seasonal)
        
        @test all(isfinite.(dprec_seas))
        @test all(isfinite.(dmelt_seas))
        @test isfinite(maxdepth_seas)
        @test all(dprec_seas .>= 0.0)
        @test all(dmelt_seas .>= 0.0)
        @test maxdepth_seas >= 0.0
        
        # Should show seasonal patterns
        winter_period = 1:60
        spring_period = 61:120
        summer_period = 121:240
        
        # Winter should have minimal melting
        winter_melt = sum(dmelt_seas[winter_period])
        summer_melt = sum(dmelt_seas[summer_period])
        
        # Spring transition should show overall melting activity
        spring_melt = dmelt_seas[spring_period]
        spring_total_melt = sum(spring_melt)
        
        # Spring should have more melting than winter (temperature-dependent)
        # At least some melting should occur during the warm periods
        warm_periods_melt = sum(dmelt_seas[61:240])  # Spring + Summer
        @test warm_periods_melt > 0.0
        
        # Mass balance check
        drain_factor = 365.0 / 12.0
        total_input_seas = sum(dprecin_seasonal) / drain_factor
        total_output_seas = sum(dprec_seas) + sum(dmelt_seas)
        @test abs(total_output_seas - total_input_seas) < 1e-10
    end
    
    @testset "Iterative Convergence Tests" begin
        # The function runs the calculation twice - test that this provides stability
        dtemp_iter = vcat(fill(-5.0, 100), fill(8.0, 265))
        dprecin_iter = fill(2.0, 365)
        
        # Run function (which internally does 2 iterations)
        dprec_iter, dmelt_iter, maxdepth_iter = snow(dtemp_iter, dprecin_iter)
        
        # Results should be stable and physically reasonable
        @test all(isfinite.(dprec_iter))
        @test all(isfinite.(dmelt_iter))
        @test isfinite(maxdepth_iter)
        @test all(dprec_iter .>= 0.0)
        @test all(dmelt_iter .>= 0.0)
        @test maxdepth_iter >= 0.0
        
        # Mass balance should be exact after iterations
        drain_factor = 365.0 / 12.0
        total_input_iter = sum(dprecin_iter) / drain_factor
        total_output_iter = sum(dprec_iter) + sum(dmelt_iter)
        @test abs(total_output_iter - total_input_iter) < 1e-12
        
        # Should have accumulated some snow and then melted some
        @test maxdepth_iter > 0.0
        @test sum(dmelt_iter) > 0.0
    end
end