using Test

include("../../../../src/models/MechanisticModel/growth_subroutines/calcphi.jl")

@testset "CalcPhi Tests" begin
    
    @testset "Positive Test - Normal GPP patterns" begin
        # Test with typical temperate forest seasonal pattern (higher summer GPP)
        gpp_temperate = [2.0, 3.0, 6.0, 12.0, 18.0, 20.0, 22.0, 20.0, 15.0, 8.0, 4.0, 2.0]
        phi_temp = calcphi(gpp_temperate)
        
        # Quantum yield should be a reasonable positive value
        @test phi_temp > 0.0
        @test isfinite(phi_temp)
        @test phi_temp <= 1.0  # Quantum yield should not exceed 1.0 (after scaling if needed)
        
        # Test with tropical pattern (less seasonal variation)
        gpp_tropical = [15.0, 16.0, 18.0, 17.0, 16.0, 14.0, 13.0, 14.0, 16.0, 17.0, 18.0, 16.0]
        phi_trop = calcphi(gpp_tropical)
        
        @test phi_trop > 0.0
        @test isfinite(phi_trop)
        @test phi_trop <= 1.0
        
        # Tropical should have lower phi due to less variation (lower avar)
        @test phi_trop < phi_temp
        
        # Test with desert pattern (low overall GPP)
        gpp_desert = [0.5, 1.0, 2.0, 3.0, 2.5, 1.5, 1.0, 1.0, 1.5, 2.0, 1.5, 0.5]
        phi_desert = calcphi(gpp_desert)
        
        @test phi_desert > 0.0
        @test isfinite(phi_desert)
        @test phi_desert <= 1.0
    end
    
    @testset "Mathematical Correctness Tests" begin
        # Test with uniform GPP (no seasonal variation)
        gpp_uniform = fill(10.0, 12)
        phi_uniform = calcphi(gpp_uniform)
        
        # With no variation, avar should be 0, so phi = 0.2552359
        @test phi_uniform ≈ 0.2552359 atol=1e-6
        
        # Test the scaling condition (phi >= 1.0 gets divided by 10)
        # Create a pattern that will result in high variance
        gpp_high_var = [0.1, 0.1, 0.1, 50.0, 50.0, 50.0, 0.1, 0.1, 0.1, 50.0, 50.0, 50.0]
        phi_high_var = calcphi(gpp_high_var)
        
        # Calculate what the unscaled phi would be
        totgpp = sum(gpp_high_var)
        meangpp = totgpp / 12.0
        normgpp = [g / meangpp for g in gpp_high_var]
        
        snormavg = zeros(4)
        snormavg[1] = sum(normgpp[1:3]) / 3.0
        snormavg[2] = sum(normgpp[4:6]) / 3.0
        snormavg[3] = sum(normgpp[7:9]) / 3.0
        snormavg[4] = sum(normgpp[10:12]) / 3.0
        
        svar = zeros(4)
        for i in 1:4
            for j in 1:3
                idx = (i-1)*3 + j
                svar[i] += ((normgpp[idx] - snormavg[i]) ^ 2) / 3.0
            end
        end
        
        avar = sum(svar)
        unscaled_phi = 0.3518717 * avar + 0.2552359
        
        if unscaled_phi >= 1.0
            @test phi_high_var ≈ unscaled_phi / 10.0 atol=1e-6
        else
            @test phi_high_var ≈ unscaled_phi atol=1e-6
        end
        
        # Test with known simple pattern
        gpp_simple = [1.0, 1.0, 1.0, 2.0, 2.0, 2.0, 3.0, 3.0, 3.0, 4.0, 4.0, 4.0]
        phi_simple = calcphi(gpp_simple)
        
        @test phi_simple >= 0.2552359  # Should be higher than baseline due to variation
        @test isfinite(phi_simple)
        @test phi_simple <= 1.0
    end
    
    @testset "Edge Cases" begin
        # Test with very small GPP values
        gpp_tiny = fill(1e-6, 12)
        phi_tiny = calcphi(gpp_tiny)
        
        @test phi_tiny ≈ 0.2552359 atol=1e-6  # Should be baseline with no variation
        @test isfinite(phi_tiny)
        
        # Test with very large GPP values
        gpp_large = fill(1e6, 12)
        phi_large = calcphi(gpp_large)
        
        @test phi_large ≈ 0.2552359 atol=1e-6  # Should be baseline with no variation
        @test isfinite(phi_large)
        
        # Test with zero GPP values
        gpp_zero = zeros(12)
        phi_zero = calcphi(gpp_zero)
        
        # This should handle division by zero gracefully (meangpp = 0)
        # The normgpp will be NaN, but we test that it doesn't crash
        @test isfinite(phi_zero) || isnan(phi_zero)
        
        # Test with mix of zero and non-zero
        gpp_mixed = [0.0, 0.0, 0.0, 10.0, 10.0, 10.0, 0.0, 0.0, 0.0, 10.0, 10.0, 10.0]
        phi_mixed = calcphi(gpp_mixed)
        
        @test isfinite(phi_mixed)
        @test phi_mixed > 0.0
    end
    
    @testset "Negative Tests - Error Conditions" begin
        # Test with wrong array length
        @test_throws AssertionError calcphi([1.0, 2.0, 3.0])  # Too short
        @test_throws AssertionError calcphi(fill(1.0, 15))     # Too long
        @test_throws AssertionError calcphi(Float64[])         # Empty
        
        # Test with single element (wrong length)
        @test_throws AssertionError calcphi([5.0])
        
        # Test with 11 elements (off by one)
        @test_throws AssertionError calcphi(fill(2.0, 11))
        
        # Test with 13 elements (off by one)
        @test_throws AssertionError calcphi(fill(2.0, 13))
    end
    
    @testset "Type Consistency Tests" begin
        # Test with Float32
        gpp_f32 = Float32[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0]
        phi_f32 = calcphi(gpp_f32)
        
        @test typeof(phi_f32) == Float32
        @test isfinite(phi_f32)
        
        # Test with Float64
        gpp_f64 = Float64[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0]
        phi_f64 = calcphi(gpp_f64)
        
        @test typeof(phi_f64) == Float64
        @test isfinite(phi_f64)
        
        # Results should be approximately equal
        @test Float64(phi_f32) ≈ phi_f64 atol=1e-6
        
        # Test with integers (should throw error due to type constraints)
        gpp_int = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
        @test_throws InexactError calcphi(gpp_int)
    end
    
    @testset "Boundary Value Tests" begin
        # Test GPP pattern that should result in phi close to 1.0 (boundary of scaling)
        # We need high variance to push phi towards 1.0
        gpp_boundary = [0.01, 0.01, 0.01, 100.0, 100.0, 100.0, 0.01, 0.01, 0.01, 100.0, 100.0, 100.0]
        phi_boundary = calcphi(gpp_boundary)
        
        @test isfinite(phi_boundary)
        @test phi_boundary > 0.0
        @test phi_boundary <= 1.0
        
        # Test pattern with maximum possible seasonal contrast
        gpp_extreme = [0.001, 0.001, 0.001, 1000.0, 1000.0, 1000.0, 0.001, 0.001, 0.001, 1000.0, 1000.0, 1000.0]
        phi_extreme = calcphi(gpp_extreme)
        
        @test isfinite(phi_extreme)
        @test phi_extreme > 0.0
        @test phi_extreme <= 1.0
    end
end