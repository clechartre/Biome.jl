using Test

@testset "Isotope Fractionation Tests" begin
    
    @testset "isoC3 Function Tests" begin
        # Test normal C3 fractionation
        Cratio = 0.7
        Ca = 350.0
        temp = 25.0
        Rd = 2.0
        
        delC3 = isoC3(Cratio, Ca, temp, Rd)
        
        # C3 fractionation should be finite
        @test isfinite(delC3)
        
        # Test temperature dependency
        delC3_cold = isoC3(Cratio, Ca, 5.0, Rd)
        delC3_hot = isoC3(Cratio, Ca, 35.0, Rd)
        
        @test isfinite(delC3_cold)
        @test isfinite(delC3_hot)
        @test delC3_cold == delC3_hot  # Should not be temperature dependent
        
        # Test Cratio dependency
        delC3_low_ratio = isoC3(0.3, Ca, temp, Rd)
        delC3_high_ratio = isoC3(0.9, Ca, temp, Rd)
        
        @test isfinite(delC3_low_ratio)
        @test isfinite(delC3_high_ratio)
        @test delC3_low_ratio != delC3_high_ratio  # Should depend on Cratio
        
        # Test with zero/negative respiration (should be adjusted to 0.01)
        delC3_zero_rd = isoC3(Cratio, Ca, temp, 0.0)
        delC3_neg_rd = isoC3(Cratio, Ca, temp, -1.0)
        
        @test isfinite(delC3_zero_rd)
        @test isfinite(delC3_neg_rd)
        @test delC3_zero_rd == delC3_neg_rd  # Both should use Rd = 0.01
    end
    
    @testset "isoC4 Function Tests" begin
        # Test normal C4 fractionation
        Cratio = 0.4
        phi = 0.05
        temp = 30.0
        
        delC4 = isoC4(Cratio, phi, temp)
        
        # C4 fractionation should be finite and in reasonable range
        @test isfinite(delC4)
        
        # Test temperature dependency
        delC4_cold = isoC4(Cratio, phi, 10.0)
        delC4_hot = isoC4(Cratio, phi, 40.0)
        
        @test isfinite(delC4_cold)
        @test isfinite(delC4_hot)
        @test delC4_cold != delC4_hot  # Should be temperature dependent
        
        # Test phi dependency (quantum yield)
        delC4_low_phi = isoC4(Cratio, 0.02, temp)
        delC4_high_phi = isoC4(Cratio, 0.08, temp)
        
        @test isfinite(delC4_low_phi)
        @test isfinite(delC4_high_phi)
        @test delC4_low_phi != delC4_high_phi  # Should depend on phi
        
        # Test Cratio dependency
        delC4_low_ratio = isoC4(0.2, phi, temp)
        delC4_high_ratio = isoC4(0.8, phi, temp)
        
        @test isfinite(delC4_low_ratio)
        @test isfinite(delC4_high_ratio)
        @test delC4_low_ratio != delC4_high_ratio  # Should depend on Cratio

    end
    
    @testset "Isotope Main Function Tests - Pure C3" begin
        # Test with all C3 months
        Cratio = [0.7, 0.6, 0.65, 0.8, 0.75, 0.7, 0.8, 0.75, 0.7, 0.65, 0.6, 0.7]
        Ca = 380.0
        temp = [10.0, 15.0, 20.0, 25.0, 28.0, 30.0, 32.0, 30.0, 25.0, 20.0, 15.0, 12.0]
        Rd = [1.0, 1.5, 2.0, 2.5, 3.0, 3.2, 3.0, 2.8, 2.0, 1.5, 1.2, 1.0]
        c4month = fill(false, 12)  # All C3
        mgpp = [50.0, 80.0, 120.0, 150.0, 180.0, 200.0, 190.0, 170.0, 130.0, 100.0, 70.0, 60.0]
        phi = 0.04
        gpp = sum(mgpp)
        
        meanC3, meanC4, C3DA, C4DA = isotope(Cratio, Ca, temp, Rd, c4month, mgpp, phi, gpp)
        
        # For pure C3, meanC4 should be zero
        @test meanC4 ≈ 0.0 atol=1e-10
        @test all(C4DA .≈ 0.0)
        
        # meanC3 should be finite and reasonable
        @test isfinite(meanC3)

        # C3DA should have values for all months
        @test all(isfinite.(C3DA))
        
        # meanC3 should be weighted average
        expected_meanC3 = sum(C3DA .* mgpp) / gpp
        @test meanC3 ≈ expected_meanC3 atol=1e-10
    end
    
    @testset "Isotope Main Function Tests - Pure C4" begin
        # Test with all C4 months
        Cratio = [0.4, 0.3, 0.35, 0.5, 0.45, 0.4, 0.5, 0.45, 0.4, 0.35, 0.3, 0.4]
        Ca = 380.0
        temp = [25.0, 28.0, 30.0, 32.0, 35.0, 38.0, 40.0, 38.0, 32.0, 30.0, 28.0, 26.0]
        Rd = [2.0, 2.5, 3.0, 3.5, 4.0, 4.2, 4.0, 3.8, 3.0, 2.5, 2.2, 2.0]
        c4month = fill(true, 12)  # All C4
        mgpp = [80.0, 100.0, 140.0, 180.0, 220.0, 250.0, 240.0, 210.0, 160.0, 120.0, 90.0, 85.0]
        phi = 0.06
        gpp = sum(mgpp)
        
        meanC3, meanC4, C3DA, C4DA = isotope(Cratio, Ca, temp, Rd, c4month, mgpp, phi, gpp)
        
        # For pure C4, meanC3 should be zero
        @test meanC3 ≈ 0.0 atol=1e-10
        @test all(C3DA .≈ 0.0)
        
        # meanC4 should be finite and reasonable
        @test isfinite(meanC4)
        
        # C4DA should have values for all months
        @test all(isfinite.(C4DA))
        
        # meanC4 should be weighted average
        expected_meanC4 = sum(C4DA .* mgpp) / gpp
        @test meanC4 ≈ expected_meanC4 atol=1e-10
    end
    
    @testset "Isotope Main Function Tests - Mixed C3/C4" begin
        # Test with mixed C3/C4 months (seasonal switching)
        Cratio = [0.7, 0.6, 0.5, 0.4, 0.3, 0.3, 0.4, 0.4, 0.5, 0.6, 0.7, 0.7]
        Ca = 370.0
        temp = [15.0, 18.0, 22.0, 28.0, 32.0, 35.0, 38.0, 35.0, 30.0, 25.0, 20.0, 16.0]
        Rd = [1.5, 1.8, 2.2, 2.8, 3.2, 3.5, 3.8, 3.5, 3.0, 2.5, 2.0, 1.6]
        c4month = [false, false, false, true, true, true, true, true, false, false, false, false]  # C4 in summer
        mgpp = [40.0, 60.0, 100.0, 150.0, 200.0, 220.0, 210.0, 180.0, 120.0, 80.0, 50.0, 45.0]
        phi = 0.05
        gpp = sum(mgpp)
        
        meanC3, meanC4, C3DA, C4DA = isotope(Cratio, Ca, temp, Rd, c4month, mgpp, phi, gpp)
        
        # Both meanC3 and meanC4 should be non-zero and finite
        @test isfinite(meanC3)
        @test isfinite(meanC4)
        @test meanC3 != 0.0
        @test meanC4 != 0.0
        
        # Check that values are assigned to correct months
        for m in 1:12
            if c4month[m]
                @test C3DA[m] ≈ 0.0 atol=1e-10
                @test C4DA[m] != 0.0
                @test isfinite(C4DA[m])
            else
                @test C4DA[m] ≈ 0.0 atol=1e-10
                @test C3DA[m] != 0.0
                @test isfinite(C3DA[m])
            end
        end
        
        # Verify weighted averages
        c3_gpp = sum(mgpp[.!c4month])
        c4_gpp = sum(mgpp[c4month])
        
        if c3_gpp > 0
            expected_meanC3 = sum(C3DA .* mgpp) / gpp
            @test meanC3 ≈ expected_meanC3 atol=1e-10
        end
        
        if c4_gpp > 0
            expected_meanC4 = sum(C4DA .* mgpp) / gpp
            @test meanC4 ≈ expected_meanC4 atol=1e-10
        end
    
    end
    
    @testset "Cratio Boundary Conditions" begin
        # Test Cratio < 0.05 adjustment
        Cratio_low = [0.02, 0.01, 0.03, 0.04, 0.06, 0.05, 0.04, 0.03, 0.02, 0.01, 0.02, 0.03]
        Ca = 360.0
        temp = fill(25.0, 12)
        Rd = fill(2.0, 12)
        c4month = fill(false, 12)
        mgpp = fill(100.0, 12)
        phi = 0.04
        gpp = sum(mgpp)
        
        # Make a copy to check modification
        Cratio_original = copy(Cratio_low)
        
        meanC3, meanC4, C3DA, C4DA = isotope(Cratio_low, Ca, temp, Rd, c4month, mgpp, phi, gpp)
        
        # Check that low Cratio values were adjusted to 0.05
        for m in 1:12
            if Cratio_original[m] < 0.05
                @test Cratio_low[m] == 0.05
            else
                @test Cratio_low[m] == Cratio_original[m]
            end
        end
        
        # Results should still be finite
        @test isfinite(meanC3)
        @test all(isfinite.(C3DA))
    end
    
    @testset "Zero GPP Edge Cases" begin
        # Test with some months having zero GPP
        Cratio = fill(0.6, 12)
        Ca = 350.0
        temp = fill(20.0, 12)
        Rd = fill(2.0, 12)
        c4month = fill(false, 12)
        mgpp = [0.0, 50.0, 100.0, 150.0, 0.0, 200.0, 180.0, 150.0, 100.0, 50.0, 0.0, 0.0]
        phi = 0.04
        gpp = sum(mgpp)
        
        meanC3, meanC4, C3DA, C4DA = isotope(Cratio, Ca, temp, Rd, c4month, mgpp, phi, gpp)
        
        # Months with zero GPP should have zero discrimination
        for m in 1:12
            if mgpp[m] == 0.0
                @test C3DA[m] ≈ 0.0 atol=1e-10
                @test C4DA[m] ≈ 0.0 atol=1e-10
            else
                @test C3DA[m] != 0.0
                @test isfinite(C3DA[m])
            end
        end
        
        # meanC3 should still be calculated correctly from non-zero months
        @test isfinite(meanC3)
        @test meanC3 != 0.0
        
        # Test with total GPP = 0
        mgpp_zero = fill(0.0, 12)
        meanC3_zero, meanC4_zero, C3DA_zero, C4DA_zero = isotope(Cratio, Ca, temp, Rd, c4month, mgpp_zero, phi, 0.0)
        
        @test meanC3_zero ≈ 0.0 atol=1e-10
        @test meanC4_zero ≈ 0.0 atol=1e-10
        @test all(C3DA_zero .≈ 0.0)
        @test all(C4DA_zero .≈ 0.0)
    end
    
    @testset "Extreme Temperature Tests" begin
        # Test with extreme temperatures
        Cratio = fill(0.6, 12)
        Ca = 400.0
        temp_extreme_cold = fill(-10.0, 12)
        temp_extreme_hot = fill(50.0, 12)
        Rd = fill(1.5, 12)
        c4month = [false, false, false, true, true, true, true, true, false, false, false, false]
        mgpp = fill(100.0, 12)
        phi = 0.05
        gpp = sum(mgpp)
        
        # Test extreme cold
        meanC3_cold, meanC4_cold, C3DA_cold, C4DA_cold = isotope(Cratio, Ca, temp_extreme_cold, Rd, c4month, mgpp, phi, gpp)
        
        @test isfinite(meanC3_cold)
        @test isfinite(meanC4_cold)
        @test all(isfinite.(C3DA_cold))
        @test all(isfinite.(C4DA_cold))
        
        # Test extreme hot
        meanC3_hot, meanC4_hot, C3DA_hot, C4DA_hot = isotope(Cratio, Ca, temp_extreme_hot, Rd, c4month, mgpp, phi, gpp)
        
        @test isfinite(meanC3_hot)
        @test isfinite(meanC4_hot)
        @test all(isfinite.(C3DA_hot))
        @test all(isfinite.(C4DA_hot))
    
    end
    
    @testset "Type Consistency Tests" begin
        # Test with Float32
        Cratio_f32 = Float32[0.6, 0.7, 0.6, 0.5, 0.4, 0.4, 0.5, 0.5, 0.6, 0.7, 0.6, 0.6]
        Ca_f32 = Float32(380.0)
        temp_f32 = Float32[20.0, 22.0, 25.0, 28.0, 30.0, 32.0, 30.0, 28.0, 25.0, 22.0, 20.0, 20.0]
        Rd_f32 = Float32[2.0, 2.2, 2.5, 2.8, 3.0, 3.2, 3.0, 2.8, 2.5, 2.2, 2.0, 2.0]
        c4month_f32 = [false, false, true, true, true, true, true, true, false, false, false, false]
        mgpp_f32 = Float32[80.0, 100.0, 120.0, 150.0, 180.0, 200.0, 190.0, 170.0, 140.0, 110.0, 90.0, 80.0]
        phi_f32 = Float32(0.05)
        gpp_f32 = sum(mgpp_f32)
        
        meanC3_f32, meanC4_f32, C3DA_f32, C4DA_f32 = isotope(Cratio_f32, Ca_f32, temp_f32, Rd_f32, c4month_f32, mgpp_f32, phi_f32, gpp_f32)
        
        # Check type preservation
        @test typeof(meanC3_f32) == Float32
        @test typeof(meanC4_f32) == Float32
        @test eltype(C3DA_f32) == Float32
        @test eltype(C4DA_f32) == Float32
        
        # Values should be finite
        @test isfinite(meanC3_f32)
        @test isfinite(meanC4_f32)
        @test all(isfinite.(C3DA_f32))
        @test all(isfinite.(C4DA_f32))
        
        # Test individual functions with Float32
        delC3_f32 = isoC3(Float32(0.7), Float32(380.0), Float32(25.0), Float32(2.0))
        delC4_f32 = isoC4(Float32(0.4), Float32(0.05), Float32(30.0))
        
        @test typeof(delC3_f32) == Float32
        @test typeof(delC4_f32) == Float32
        @test isfinite(delC3_f32)
        @test isfinite(delC4_f32)
    end
    
    @testset "Array Length Validation" begin
        # Test with wrong array lengths
        Ca = 380.0
        phi = 0.05
        gpp = 1000.0
        
        # Correct length arrays
        Cratio_correct = fill(0.6, 12)
        temp_correct = fill(25.0, 12)
        Rd_correct = fill(2.0, 12)
        mgpp_correct = fill(100.0, 12)
        c4month_correct = fill(false, 12)
        
        # Test with wrong Cratio length
        @test_throws BoundsError isotope(fill(0.6, 11), Ca, temp_correct, Rd_correct, c4month_correct, mgpp_correct, phi, gpp)
        
        # Test with wrong temp length
        @test_throws BoundsError isotope(Cratio_correct, Ca, fill(25.0, 7), Rd_correct, c4month_correct, mgpp_correct, phi, gpp)
        
        # Test with wrong Rd length
        @test_throws BoundsError isotope(Cratio_correct, Ca, temp_correct, fill(2.0, 10), c4month_correct, mgpp_correct, phi, gpp)
        
        # Test with wrong mgpp length
        @test_throws BoundsError isotope(Cratio_correct, Ca, temp_correct, Rd_correct, c4month_correct, fill(100.0, 9), phi, gpp)
        
        # Test with wrong c4month length
        @test_throws BoundsError isotope(Cratio_correct, Ca, temp_correct, Rd_correct, fill(false, 8), mgpp_correct, phi, gpp)
    end
    
    @testset "Realistic Scenario Tests" begin
        # Test a realistic C3/C4 grass scenario (temperate grassland)
        # C4 photosynthesis dominates in hot summer months
        Cratio = [0.8, 0.75, 0.7, 0.6, 0.5, 0.4, 0.35, 0.4, 0.5, 0.6, 0.7, 0.75]  # Lower in summer
        Ca = 410.0  # Current atmospheric CO2
        temp = [5.0, 10.0, 15.0, 22.0, 28.0, 32.0, 35.0, 33.0, 27.0, 20.0, 12.0, 7.0]  # Seasonal temperature
        Rd = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.2, 3.0, 2.2, 1.8, 1.0, 0.7]  # Temperature-dependent respiration
        c4month = [false, false, false, false, true, true, true, true, false, false, false, false]  # C4 in hot months
        mgpp = [20.0, 40.0, 80.0, 120.0, 180.0, 220.0, 240.0, 200.0, 140.0, 100.0, 60.0, 30.0]  # Seasonal productivity
        phi = 0.04  # Typical quantum yield
        gpp = sum(mgpp)
        
        meanC3, meanC4, C3DA, C4DA = isotope(Cratio, Ca, temp, Rd, c4month, mgpp, phi, gpp)
        
        # Both pathways should contribute
        @test meanC3 != 0.0
        @test meanC4 != 0.0
        
        # Summer months should have C4 values, winter months C3 values
        @test all(C3DA[1:4] .!= 0.0)  # Early months are C3
        @test all(C4DA[1:4] .== 0.0)
        @test all(C4DA[5:8] .!= 0.0)  # Summer months are C4
        @test all(C3DA[5:8] .== 0.0)
        @test all(C3DA[9:12] .!= 0.0)  # Late months are C3
        @test all(C4DA[9:12] .== 0.0)
        
        # Verify that weighted averages are calculated correctly
        c3_weighted = sum(C3DA .* mgpp) / gpp
        c4_weighted = sum(C4DA .* mgpp) / gpp
        
        @test meanC3 ≈ c3_weighted atol=1e-10
        @test meanC4 ≈ c4_weighted atol=1e-10
    end
end