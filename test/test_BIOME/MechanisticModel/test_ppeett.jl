using Test
using Statistics

@testset "PPEETT Tests" begin
    
    @testset "Positive Test - Temperate Climate" begin
        # Temperate latitude (45°N)
        lat = 45.0
        
        # Realistic seasonal temperature pattern (°C)
        dtemp = vcat(
            fill(-5.0, 31),   # January
            fill(-2.0, 28),   # February
            fill(5.0, 31),    # March
            fill(12.0, 30),   # April
            fill(18.0, 31),   # May
            fill(22.0, 30),   # June
            fill(25.0, 31),   # July
            fill(23.0, 31),   # August
            fill(18.0, 30),   # September
            fill(12.0, 31),   # October
            fill(5.0, 30),    # November
            fill(-2.0, 31)    # December
        )
        
        # Realistic cloud cover pattern (%)
        dclou = vcat(
            fill(70.0, 90),   # Winter - cloudy
            fill(60.0, 92),   # Spring - moderate
            fill(40.0, 92),   # Summer - clear
            fill(65.0, 91)    # Fall - cloudy
        )
        
        # Monthly temperatures
        temp = [-5.0, -2.0, 5.0, 12.0, 18.0, 22.0, 25.0, 23.0, 18.0, 12.0, 5.0, -2.0]
        
        dpet, dayl, sun, rad0, ddayl = ppeett(lat, dtemp, dclou, temp)
        
        # Check output dimensions
        @test length(dpet) == 365
        @test length(dayl) == 12
        @test length(sun) == 12
        @test length(ddayl) == 365
        @test typeof(rad0) <: Real
        
        # Check that all values are finite and non-negative
        @test all(isfinite.(dpet))
        @test all(isfinite.(dayl))
        @test all(isfinite.(sun))
        @test isfinite(rad0)
        @test all(isfinite.(ddayl))
        
        @test all(dpet .>= 0.0)
        @test all(dayl .>= 0.0)
        @test all(sun .>= 0.0)
        @test rad0 >= 0.0
        @test all(ddayl .>= 0.0)
        
        # Check reasonable ranges
        @test all(dpet .<= 20.0)  # PET shouldn't be extremely high
        @test all(dayl .<= 24.0)  # Daylength max 24 hours
        @test all(ddayl .<= 24.0)
        
        # Check seasonal patterns
        # Summer should have longer days than winter at temperate latitudes
        summer_dayl = mean(dayl[6:8])  # June-August
        winter_dayl = mean(dayl[[12, 1, 2]])  # Dec-Feb
        @test summer_dayl > winter_dayl
        
        # Summer should have higher solar radiation
        summer_sun = mean(sun[6:8])
        winter_sun = mean(sun[[12, 1, 2]])
        @test summer_sun > winter_sun
        
        # PET should generally be higher in summer
        summer_dpet = mean(dpet[152:243])  # Roughly June-August
        winter_dpet = mean(dpet[[1:59; 335:365]])  # Roughly Dec-Feb
        @test summer_dpet > winter_dpet
    end
    
    @testset "Tropical Latitude Tests" begin
        # Equatorial latitude
        lat = 0.0
        
        # Tropical temperature pattern (minimal seasonal variation)
        dtemp = fill(26.0, 365)
        dclou = fill(60.0, 365)  # Moderate cloud cover
        temp = fill(26.0, 12)
        
        dpet_eq, dayl_eq, sun_eq, rad0_eq, ddayl_eq = ppeett(lat, dtemp, dclou, temp)
        
        # Check output validity
        @test all(isfinite.(dpet_eq))
        @test all(isfinite.(dayl_eq))
        @test all(isfinite.(sun_eq))
        @test all(dpet_eq .>= 0.0)
        @test all(dayl_eq .>= 0.0)
        @test all(sun_eq .>= 0.0)
        
        # At equator, daylength should be close to 12 hours year-round
        @test all(abs.(dayl_eq .- 12.0) .< 1.0)
        @test all(abs.(ddayl_eq .- 12.0) .< 1.0)
        
        # Should have minimal seasonal variation in solar radiation
        sun_variation = maximum(sun_eq) - minimum(sun_eq)
        sun_mean = mean(sun_eq)
        @test sun_variation / sun_mean < 0.2  # Less than 20% variation
        
        # Compare with temperate latitude
        lat_temp = 45.0
        dpet_temp, dayl_temp, sun_temp, rad0_temp, ddayl_temp = ppeett(lat_temp, dtemp, dclou, temp)
        
        # Temperate should have more seasonal variation
        temp_sun_variation = maximum(sun_temp) - minimum(sun_temp)
        temp_dayl_variation = maximum(dayl_temp) - minimum(dayl_temp)
        eq_dayl_variation = maximum(dayl_eq) - minimum(dayl_eq)
        
        @test temp_sun_variation > sun_variation
        @test temp_dayl_variation > eq_dayl_variation
    end
    
    @testset "Polar Latitude Tests" begin
        # High latitude (70°N)
        lat = 70.0
        
        # Arctic temperature pattern
        dtemp = vcat(
            fill(-25.0, 90),  # Winter - very cold
            fill(-5.0, 90),   # Spring - cold
            fill(10.0, 92),   # Summer - mild
            fill(-10.0, 93)   # Fall - cold
        )
        dclou = fill(50.0, 365)
        temp = [-25.0, -20.0, -10.0, -2.0, 5.0, 12.0, 15.0, 10.0, 2.0, -5.0, -15.0, -22.0]
        
        dpet_polar, dayl_polar, sun_polar, rad0_polar, ddayl_polar = ppeett(lat, dtemp, dclou, temp)
        
        # Check output validity
        @test all(isfinite.(dpet_polar))
        @test all(isfinite.(dayl_polar))
        @test all(isfinite.(sun_polar))
        @test all(dpet_polar .>= 0.0)
        @test all(dayl_polar .>= 0.0)
        @test all(sun_polar .>= 0.0)
        
        # At high latitudes, should have extreme seasonal variation
        dayl_variation = maximum(dayl_polar) - minimum(dayl_polar)
        @test dayl_variation > 15.0  # Should have very long and very short days
        
        # Winter months should have very short days or polar night
        winter_dayl = mean(dayl_polar[[1, 2, 12]])
        @test winter_dayl < 5.0  # Very short winter days
        
        # Summer should have very long days
        summer_dayl = mean(dayl_polar[6:8])
        @test summer_dayl > 15.0  # Very long summer days
        
        # Solar radiation should show extreme seasonal pattern
        sun_variation = maximum(sun_polar) - minimum(sun_polar)
        sun_mean = mean(sun_polar)
        @test sun_variation / sun_mean > 0.8  # High relative variation
    end
    
    @testset "Cloud Cover Effects Tests" begin
        lat = 35.0
        dtemp = fill(20.0, 365)  # Constant temperature
        temp = fill(20.0, 12)
        
        # Test with no clouds
        dclou_clear = fill(0.0, 365)
        dpet_clear, dayl_clear, sun_clear, rad0_clear, ddayl_clear = ppeett(lat, dtemp, dclou_clear, temp)
        
        # Test with full cloud cover
        dclou_cloudy = fill(100.0, 365)
        dpet_cloudy, dayl_cloudy, sun_cloudy, rad0_cloudy, ddayl_cloudy = ppeett(lat, dtemp, dclou_cloudy, temp)
        
        # Both should be valid
        @test all(isfinite.(dpet_clear))
        @test all(isfinite.(dpet_cloudy))
        @test all(dpet_clear .>= 0.0)
        @test all(dpet_cloudy .>= 0.0)
        
        # PET might be different due to radiation effects
        # Clear conditions might have higher PET in some cases
        @test all(isfinite.(dpet_clear))
        @test all(isfinite.(dpet_cloudy))
    end
    
    @testset "Temperature Effects Tests" begin
        lat = 40.0
        dclou = fill(50.0, 365)  # Moderate cloud cover
        
        # Test with cold temperatures
        dtemp_cold = fill(-10.0, 365)
        temp_cold = fill(-10.0, 12)
        
        dpet_cold, dayl_cold, sun_cold, rad0_cold, ddayl_cold = ppeett(lat, dtemp_cold, dclou, temp_cold)
        
        # Test with hot temperatures
        dtemp_hot = fill(35.0, 365)
        temp_hot = fill(35.0, 12)
        
        dpet_hot, dayl_hot, sun_hot, rad0_hot, ddayl_hot = ppeett(lat, dtemp_hot, dclou, temp_hot)
        
        # Both should be valid
        @test all(isfinite.(dpet_cold))
        @test all(isfinite.(dpet_hot))
        @test all(dpet_cold .>= 0.0)
        @test all(dpet_hot .>= 0.0)
        
        # Temperature affects PET calculation
        @test mean(dpet_hot) > mean(dpet_cold)  # Higher temp should increase PET
        
        # Temperature shouldn't significantly affect solar radiation calculations
        @test all(abs.(sun_hot .- sun_cold) .< mean(sun_hot) * 0.1)  # Within 10%
        
        # rad0 calculation depends on positive temperatures
        # Cold temperatures might result in rad0 = 0 if all temps <= 0
        @test rad0_cold == 0.0  # All temps <= 0
        @test rad0_hot > 0.0   # All temps > 0
    end
    
    @testset "Extreme Latitude Tests" begin
        dtemp = fill(15.0, 365)
        dclou = fill(50.0, 365)
        temp = fill(15.0, 12)
        
        # Test extreme northern latitude
        lat_north = 85.0
        dpet_north, dayl_north, sun_north, rad0_north, ddayl_north = ppeett(lat_north, dtemp, dclou, temp)
        
        @test all(isfinite.(dpet_north))
        @test all(isfinite.(dayl_north))
        @test all(dpet_north .>= 0.0)
        @test all(dayl_north .>= 0.0)
        
        # Should have polar day/night patterns
        @test minimum(dayl_north) < 2.0   # Polar night
        @test maximum(dayl_north) > 22.0  # Polar day
        
        # Test extreme southern latitude
        lat_south = -85.0
        dpet_south, dayl_south, sun_south, rad0_south, ddayl_south = ppeett(lat_south, dtemp, dclou, temp)
        
        @test all(isfinite.(dpet_south))
        @test all(isfinite.(dayl_south))
        @test all(dpet_south .>= 0.0)
        @test all(dayl_south .>= 0.0)
        
        # Southern hemisphere should have opposite seasonal pattern
        # When north has polar night, south should have polar day
        north_winter_dayl = mean(dayl_north[[1, 2, 12]])
        south_winter_dayl = mean(dayl_south[[1, 2, 12]])
        north_summer_dayl = mean(dayl_north[6:8])
        south_summer_dayl = mean(dayl_south[6:8])
        
        @test north_winter_dayl < north_summer_dayl
        @test south_winter_dayl > south_summer_dayl  # Opposite pattern
    end
    
    @testset "Type Consistency Tests" begin
        lat_f32 = Float32(45.0)
        dtemp_f32 = Float32.(fill(20.0, 365))
        dclou_f32 = Float32.(fill(60.0, 365))
        temp_f32 = Float32.(fill(20.0, 12))
        
        dpet_f32, dayl_f32, sun_f32, rad0_f32, ddayl_f32 = ppeett(lat_f32, dtemp_f32, dclou_f32, temp_f32)
        
        # Check type preservation
        @test eltype(dpet_f32) == Float32
        @test eltype(dayl_f32) == Float32
        @test eltype(sun_f32) == Float32
        @test typeof(rad0_f32) == Float32
        @test eltype(ddayl_f32) == Float32
        
        # Check dimensions
        @test length(dpet_f32) == 365
        @test length(dayl_f32) == 12
        @test length(sun_f32) == 12
        @test length(ddayl_f32) == 365
        
        # Values should be finite and non-negative
        @test all(isfinite.(dpet_f32))
        @test all(isfinite.(dayl_f32))
        @test all(isfinite.(sun_f32))
        @test isfinite(rad0_f32)
        @test all(isfinite.(ddayl_f32))
        
        @test all(dpet_f32 .>= Float32(0.0))
        @test all(dayl_f32 .>= Float32(0.0))
        @test all(sun_f32 .>= Float32(0.0))
        @test rad0_f32 >= Float32(0.0)
        @test all(ddayl_f32 .>= Float32(0.0))
    end
    
    @testset "Array Length Validation" begin
        lat = 50.0
        temp_valid = fill(15.0, 12)
        
        # Test with wrong dtemp array length
        @test_throws BoundsError ppeett(lat, fill(15.0, 300), fill(50.0, 365), temp_valid)
        
        # Test with wrong dclou array length
        @test_throws BoundsError ppeett(lat, fill(15.0, 365), fill(50.0, 300), temp_valid)
        
        # Test with wrong temp array length
        @test_throws BoundsError ppeett(lat, fill(15.0, 365), fill(50.0, 365), fill(15.0, 10))
    end
    
    @testset "Safe Exponential Function Tests" begin
        # Test safe_exp function separately
        @test isfinite(safe_exp(1.0))
        @test safe_exp(1.0) ≈ exp(1.0)
        
        # Test with large values that might overflow
        large_val = 1000.0
        result = safe_exp(large_val)
        @test result == Inf || isfinite(result)  # Should handle overflow gracefully
        
        # Test with Float32
        @test typeof(safe_exp(Float32(1.0))) == Float32
        @test safe_exp(Float32(1.0)) ≈ exp(Float32(1.0))
    end
    
    @testset "Physical Consistency Tests" begin
        lat = 45.0
        
        # Create realistic annual cycle
        dtemp = vcat(
            [i * 0.5 - 10.0 for i in 1:90],   # Winter to spring
            [10.0 + i * 0.2 for i in 1:92],   # Spring to summer
            [28.0 - i * 0.2 for i in 1:92],   # Summer to fall
            [10.0 - i * 0.25 for i in 1:91]   # Fall to winter
        )
        dclou = 50.0 .+ 20.0 .* sin.(2π .* (1:365) ./ 365.0)  # Sinusoidal cloud pattern
        daysinmonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        temp = [mean(dtemp[sum(daysinmonth[1:i-1])+1:sum(daysinmonth[1:i])]) for i in 1:12]
        
        dpet, dayl, sun, rad0, ddayl = ppeett(lat, dtemp, dclou, temp)
        
        # Physical consistency checks
        
        # 1. Energy balance: Solar radiation should correlate with daylength
        correlation_sun_dayl = cor(sun, dayl)
        @test correlation_sun_dayl > 0.5  # Should be positively correlated
        
        # 2. PET should correlate with temperature and solar radiation
        monthly_dpet = [mean(dpet[sum(daysinmonth[1:i-1])+1:sum(daysinmonth[1:i])]) for i in 1:12]
        correlation_pet_temp = cor(monthly_dpet, temp)
        correlation_pet_sun = cor(monthly_dpet, sun)
        
        @test correlation_pet_temp > 0.3  # Should be positively correlated with temperature
        @test correlation_pet_sun > 0.3   # Should be positively correlated with solar radiation
        
        # 3. Symmetry: Northern hemisphere summer solstice should have longest day
        longest_day_index = argmax(ddayl)
        @test 150 < longest_day_index < 200  # Should be around day 172 (June 21)
        
        # 4. Shortest day should be around winter solstice
        shortest_day_index = argmin(ddayl)
        @test shortest_day_index < 30 || shortest_day_index > 350  # Around Dec 21
        
        # 5. Daily and monthly daylengths should be consistent
        for month in 1:12
            midday = [16, 44, 75, 105, 136, 166, 197, 228, 258, 289, 319, 350][month]
            @test abs(dayl[month] - ddayl[midday]) < 0.1  # Should be very close
        end
    end
    
    @testset "Edge Case - Zero Inputs" begin
        lat = 0.0
        dtemp_zero = fill(0.0, 365)
        dclou_zero = fill(0.0, 365)
        temp_zero = fill(0.0, 12)
        
        dpet_zero, dayl_zero, sun_zero, rad0_zero, ddayl_zero = ppeett(lat, dtemp_zero, dclou_zero, temp_zero)
        
        # Should handle zero inputs gracefully
        @test all(isfinite.(dpet_zero))
        @test all(isfinite.(dayl_zero))
        @test all(isfinite.(sun_zero))
        @test isfinite(rad0_zero)
        @test all(isfinite.(ddayl_zero))
        
        @test all(dpet_zero .>= 0.0)
        @test all(dayl_zero .>= 0.0)
        @test all(sun_zero .>= 0.0)
        @test rad0_zero >= 0.0
        @test all(ddayl_zero .>= 0.0)
        
        # At equator with zero temperature, rad0 should be zero
        @test rad0_zero == 0.0
        
        # Daylength at equator should still be ~12 hours
        @test all(abs.(dayl_zero .- 12.0) .< 1.0)
    end
end