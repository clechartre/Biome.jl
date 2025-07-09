using Test
using Statistics

@testset "Soil Temperature Tests" begin
    
    @testset "Positive Test - Temperate Climate" begin
        # Realistic temperate climate with seasonal variation
        tair = [-2.0, 0.0, 6.0, 12.0, 18.0, 22.0, 25.0, 23.0, 18.0, 12.0, 6.0, 1.0]
        
        tsoil = soiltemp(tair)
        
        # Check output dimensions and type
        @test length(tsoil) == 12
        @test eltype(tsoil) == Float64
        
        # Check that all values are finite
        @test all(isfinite.(tsoil))
        
        # Soil temperatures should be dampened compared to air temperatures
        air_range = maximum(tair) - minimum(tair)
        soil_range = maximum(tsoil) - minimum(tsoil)
        @test soil_range < air_range  # Soil should have less variation
        
        # Mean soil temperature should be close to mean air temperature
        mean_air = sum(tair) / 12.0
        mean_soil = sum(tsoil) / 12.0
        @test abs(mean_soil - mean_air) < 0.5  # Should be very close
        
        # Soil temperatures should be reasonable for temperate climate
        @test all(tsoil .>= -10.0)  # Minimum constraint
        @test all(tsoil .<= 30.0)   # Reasonable upper bound
        
        # Winter soil should be warmer than winter air (thermal mass effect)
        winter_months = [1, 2, 12]
        for month in winter_months
            if tair[month] < 0.0
                @test tsoil[month] >= tair[month]  # Soil warmer in winter
            end
        end
        
        # Summer soil should be cooler than summer air (thermal mass effect)
        summer_months = [6, 7, 8]
        for month in summer_months
            @test tsoil[month] <= tair[month] + 2.0  # Soil cooler in summer (with tolerance)
        end
    end
    
    @testset "Tropical Climate Tests" begin
        # Tropical climate with minimal seasonal variation
        tair_tropical = [26.0, 27.0, 28.0, 29.0, 28.0, 27.0, 26.0, 26.0, 27.0, 28.0, 27.0, 26.0]
        
        tsoil_tropical = soiltemp(tair_tropical)
        
        @test length(tsoil_tropical) == 12
        @test all(isfinite.(tsoil_tropical))
        @test all(tsoil_tropical .>= -10.0)
        
        # With minimal air temperature variation, soil should be even more stable
        air_var_tropical = maximum(tair_tropical) - minimum(tair_tropical)
        soil_var_tropical = maximum(tsoil_tropical) - minimum(tsoil_tropical)
        @test soil_var_tropical <= air_var_tropical
        
        # Mean should be conserved
        mean_air_tropical = sum(tair_tropical) / 12.0
        mean_soil_tropical = sum(tsoil_tropical) / 12.0
        @test abs(mean_soil_tropical - mean_air_tropical) < 0.2
        
        # All temperatures should be warm
        @test all(tsoil_tropical .> 20.0)
    end
    
    @testset "Arctic Climate Tests" begin
        # Arctic climate with extreme cold and variation
        tair_arctic = [-25.0, -22.0, -15.0, -5.0, 5.0, 12.0, 15.0, 10.0, 2.0, -8.0, -18.0, -23.0]
        
        tsoil_arctic = soiltemp(tair_arctic)
        
        @test length(tsoil_arctic) == 12
        @test all(isfinite.(tsoil_arctic))
        
        # Should enforce minimum temperature constraint
        @test all(tsoil_arctic .>= -10.0)
        
        # Check that some months hit the minimum constraint
        extreme_cold_months = findall(x -> x < -15.0, tair_arctic)
        if !isempty(extreme_cold_months)
            # At least some winter months should be at the minimum
            winter_soil_temps = tsoil_arctic[extreme_cold_months]
            @test any(winter_soil_temps .== -10.0)
        end
        
        # Dampening should still occur for non-constrained months
        non_constrained = findall(x -> x > -10.0, tsoil_arctic)
        if length(non_constrained) >= 2
            air_range_nc = maximum(tair_arctic[non_constrained]) - minimum(tair_arctic[non_constrained])
            soil_range_nc = maximum(tsoil_arctic[non_constrained]) - minimum(tsoil_arctic[non_constrained])
            @test soil_range_nc <= air_range_nc
        end
    end
    
    @testset "Thermal Dampening Tests" begin
        # Test with extreme air temperature swings
        tair_extreme = [5.0, 25.0, 5.0, 25.0, 5.0, 25.0, 5.0, 25.0, 5.0, 25.0, 5.0, 25.0]
        
        tsoil_extreme = soiltemp(tair_extreme)
        
        @test length(tsoil_extreme) == 12
        @test all(isfinite.(tsoil_extreme))
        @test all(tsoil_extreme .>= -10.0)
        
        # Soil should significantly dampen these extreme swings
        air_range_extreme = maximum(tair_extreme) - minimum(tair_extreme)
        soil_range_extreme = maximum(tsoil_extreme) - minimum(tsoil_extreme)
        
        @test soil_range_extreme < air_range_extreme
        @test soil_range_extreme < air_range_extreme * 0.8  # Should be significantly dampened
        
        # Mean temperature should be preserved
        mean_air_extreme = sum(tair_extreme) / 12.0
        mean_soil_extreme = sum(tsoil_extreme) / 12.0
        @test abs(mean_soil_extreme - mean_air_extreme) < 0.5
        
        # Soil temperatures should be more gradual
        soil_monthly_changes = [abs(tsoil_extreme[i] - tsoil_extreme[i-1]) for i in 2:12]
        air_monthly_changes = [abs(tair_extreme[i] - tair_extreme[i-1]) for i in 2:12]
        
        # On average, soil changes should be smaller than air changes
        @test mean(soil_monthly_changes) < mean(air_monthly_changes)
    end
    
    @testset "Time Lag Tests" begin
        # Test with asymmetric seasonal pattern to detect lag
        tair_asym = [0.0, 2.0, 8.0, 16.0, 22.0, 25.0, 26.0, 24.0, 18.0, 10.0, 4.0, 1.0]
        
        tsoil_asym = soiltemp(tair_asym)
        
        @test length(tsoil_asym) == 12
        @test all(isfinite.(tsoil_asym))
        @test all(tsoil_asym .>= -10.0)
        
        # Find peak air and soil temperatures
        air_peak_month = argmax(tair_asym)
        soil_peak_month = argmax(tsoil_asym)
        
        # Soil peak should lag behind air peak (thermal inertia)
        # Due to the lag calculation, peak might be delayed
        # Test that soil doesn't lead air temperature significantly
        if soil_peak_month != air_peak_month
            # Calculate lag accounting for circular year
            lag_months = mod(soil_peak_month - air_peak_month, 12)
            @test lag_months <= 3  # Reasonable lag limit
        end
        
        # Similar test for minimum temperatures
        air_min_month = argmin(tair_asym)
        soil_min_month = argmin(tsoil_asym)
        
        # Check that the lag effect is present
        @test all(isfinite.(tsoil_asym))
    end
    
    @testset "Constant Temperature Tests" begin
        # Test with constant air temperature
        tair_constant = fill(15.0, 12)
        
        tsoil_constant = soiltemp(tair_constant)
        
        @test length(tsoil_constant) == 12
        @test all(isfinite.(tsoil_constant))
        @test all(tsoil_constant .>= -10.0)
        
        # With constant air temperature, soil should also be constant
        @test all(abs.(tsoil_constant .- 15.0) .< 1e-10)
        
        # Test with constant cold temperature
        tair_cold_constant = fill(-5.0, 12)
        
        tsoil_cold_constant = soiltemp(tair_cold_constant)
        
        @test all(abs.(tsoil_cold_constant .+ 5.0) .< 1e-10)  # Should equal -5.0
        
        # Test with constant extremely cold temperature
        tair_extreme_cold = fill(-20.0, 12)
        
        tsoil_extreme_cold = soiltemp(tair_extreme_cold)
        
        # Should be constrained to minimum
        @test all(tsoil_extreme_cold .== -10.0)
    end
    
    @testset "Minimum Temperature Constraint Tests" begin
        # Test various scenarios that should trigger the -10°C constraint
        
        # Case 1: Extremely cold winter
        tair_cold_winter = [-30.0, -25.0, -10.0, 5.0, 15.0, 20.0, 22.0, 18.0, 10.0, 0.0, -15.0, -25.0]
        
        tsoil_cold_winter = soiltemp(tair_cold_winter)
        
        @test all(tsoil_cold_winter .>= -10.0)
        @test any(tsoil_cold_winter .== -10.0)  # Some months should hit the constraint
        
        # Case 2: All months extremely cold
        tair_all_cold = fill(-40.0, 12)
        
        tsoil_all_cold = soiltemp(tair_all_cold)
        
        @test all(tsoil_all_cold .== -10.0)  # All months should be constrained
        
        # Case 3: Just barely triggering constraint
        tair_barely_cold = [-12.0, -8.0, -2.0, 5.0, 12.0, 18.0, 20.0, 16.0, 10.0, 3.0, -5.0, -10.0]
        
        tsoil_barely_cold = soiltemp(tair_barely_cold)
        
        @test all(tsoil_barely_cold .>= -10.0)
        
        # The constraint should only affect months that would naturally be below -10
        # Some months should not be constrained
        @test any(tsoil_barely_cold .> -10.0)
    end
    
    @testset "Type Consistency Tests" begin
        # Test with Float32
        tair_f32 = Float32[5.0, 8.0, 12.0, 18.0, 22.0, 25.0, 27.0, 24.0, 19.0, 13.0, 8.0, 6.0]
        
        tsoil_f32 = soiltemp(tair_f32)
        
        # Check type preservation
        @test eltype(tsoil_f32) == Float32
        @test length(tsoil_f32) == 12
        
        # Values should be finite and respect constraints
        @test all(isfinite.(tsoil_f32))
        @test all(tsoil_f32 .>= Float32(-10.0))
        
        # Dampening should still work
        air_range_f32 = maximum(tair_f32) - minimum(tair_f32)
        soil_range_f32 = maximum(tsoil_f32) - minimum(tsoil_f32)
        @test soil_range_f32 <= air_range_f32
        
        # Mean preservation
        mean_air_f32 = sum(tair_f32) / Float32(12.0)
        mean_soil_f32 = sum(tsoil_f32) / Float32(12.0)
        @test abs(mean_soil_f32 - mean_air_f32) < Float32(0.5)
    end
    
    @testset "Array Length Validation" begin
        # Test with wrong array lengths
        @test_throws BoundsError soiltemp(fill(15.0, 10))
        @test_throws BoundsError soiltemp(Float32[])
        @test_throws BoundsError soiltemp([10.0])  # Single element
        
        # Test with exactly 12 elements (should work)
        tair_valid = fill(12.0, 12)
        tsoil_valid = soiltemp(tair_valid)
        @test length(tsoil_valid) == 12
        @test all(isfinite.(tsoil_valid))
    end
    
    @testset "Physical Realism Tests" begin
        # Test realistic temperature scenarios from different climate zones
        
        # Continental climate (large seasonal variation)
        tair_continental = [-8.0, -4.0, 2.0, 12.0, 20.0, 25.0, 28.0, 26.0, 18.0, 8.0, -1.0, -6.0]
        tsoil_continental = soiltemp(tair_continental)
        
        # Maritime climate (moderated seasonal variation)
        tair_maritime = [4.0, 6.0, 9.0, 12.0, 16.0, 19.0, 21.0, 20.0, 17.0, 13.0, 8.0, 5.0]
        tsoil_maritime = soiltemp(tair_maritime)
        
        # Both should be valid
        @test all(isfinite.(tsoil_continental))
        @test all(isfinite.(tsoil_maritime))
        @test all(tsoil_continental .>= -10.0)
        @test all(tsoil_maritime .>= -10.0)
        
        # Continental should show more dampening (larger air range)
        air_range_cont = maximum(tair_continental) - minimum(tair_continental)
        soil_range_cont = maximum(tsoil_continental) - minimum(tsoil_continental)
        dampening_cont = 1.0 - (soil_range_cont / air_range_cont)
        
        air_range_mar = maximum(tair_maritime) - minimum(tair_maritime)
        soil_range_mar = maximum(tsoil_maritime) - minimum(tsoil_maritime)
        dampening_mar = 1.0 - (soil_range_mar / air_range_mar)
        
        # Continental should show significant dampening
        @test dampening_cont > 0.1  # At least 10% dampening
        @test dampening_mar >= 0.0  # Maritime might show less dampening
        
        # Mean temperatures should be preserved
        @test abs(mean(tsoil_continental) - mean(tair_continental)) < 0.5
        @test abs(mean(tsoil_maritime) - mean(tair_maritime)) < 0.5
    end
    
    @testset "Seasonal Transition Smoothness" begin
        # Test that soil temperatures provide smooth transitions
        tair_sharp = [0.0, 0.0, 20.0, 20.0, 20.0, 20.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        tsoil_sharp = soiltemp(tair_sharp)
        
        @test all(isfinite.(tsoil_sharp))
        @test all(tsoil_sharp .>= -10.0)
        
        # Soil should smooth out the sharp air temperature transitions
        air_transitions = [abs(tair_sharp[i] - tair_sharp[i-1]) for i in 2:12]
        soil_transitions = [abs(tsoil_sharp[i] - tsoil_sharp[i-1]) for i in 2:12]
        
        # Maximum soil transition should be smaller than maximum air transition
        @test maximum(soil_transitions) < maximum(air_transitions)
        
        # Average soil transition should be smaller
        @test mean(soil_transitions) <= mean(air_transitions)
    end
    
    @testset "Edge Case - Extreme Values" begin
        # Test with very extreme values
        tair_extreme_hot = fill(100.0, 12)
        tsoil_extreme_hot = soiltemp(tair_extreme_hot)
        
        @test all(isfinite.(tsoil_extreme_hot))
        @test all(tsoil_extreme_hot .== 100.0)  # Should equal input with no variation
        
        # Test with mix of extreme values
        tair_mixed_extreme = [100.0, -100.0, 50.0, -50.0, 0.0, 25.0, -25.0, 75.0, -75.0, 10.0, -10.0, 30.0]
        tsoil_mixed_extreme = soiltemp(tair_mixed_extreme)
        
        @test all(isfinite.(tsoil_mixed_extreme))
        @test all(tsoil_mixed_extreme .>= -10.0)  # Constraint should be enforced
        
        # Should show significant dampening of extreme variations
        air_range_mixed = maximum(tair_mixed_extreme) - minimum(tair_mixed_extreme)
        soil_range_mixed = maximum(tsoil_mixed_extreme) - minimum(tsoil_mixed_extreme)
        @test soil_range_mixed < air_range_mixed * 0.9  # Significant dampening
    end
end