using Test

include("../../../../src/abstractmodel.jl")
include("../../../../src/pfts.jl")
include("../../../../src/biomes.jl")
include("../../../../src/models/MechanisticModel/pfts.jl")
include("../../../../src/models/MechanisticModel/growth_subroutines/respiration.jl")
include("../../../../src/models/MechanisticModel/constants.jl")
using .Constants: T, P0, CP, T0, G, M, R0,
    QEFFC3, DRESPC3, DRESPC4, ABS1, TETA, SLO2, JTOE, OPTRATIO,
    KO25, KC25, TAO25, CMASS, KCQ10, KOQ10, TAOQ10,
    TWIGLOSS, TUNE, LEAFRESP,
    MAXTEMP,
    LN, Y, M10, P1, STEMCARBON,
    E0, TREF, TEMP0,
    A, ES, A1, B3, B



@testset "Respiration Tests" begin
    
    @testset "Positive Test - Woody PFT Normal Conditions" begin
        # Create woody PFT
        woody_pft = TemperateDeciduous(8.0, 1000.0, 15.0)
        set_characteristic(woody_pft, :allocfact, 0.3)
        set_characteristic(woody_pft, :respfact, 0.8)
        
        # Realistic inputs
        gpp = 1500.0
        alresp = 200.0
        temp = [5.0, 8.0, 12.0, 18.0, 22.0, 25.0, 28.0, 26.0, 20.0, 15.0, 10.0, 6.0]
        sapwood = 1  # Woody (not grass)
        lai = 4.0
        monthlyfpar = [0.2, 0.3, 0.5, 0.7, 0.8, 0.9, 0.9, 0.8, 0.6, 0.4, 0.3, 0.2]
        
        result = respiration(gpp, alresp, temp, sapwood, lai, monthlyfpar, woody_pft)
        npp, stemresp, percentcost, mstemresp, mrootresp, backleafresp = result
        
        # Check output dimensions and types
        @test length(mstemresp) == 12
        @test length(mrootresp) == 12
        @test length(backleafresp) == 12
        
        # Check that all values are finite
        @test isfinite(npp)
        @test isfinite(stemresp)
        @test isfinite(percentcost)
        @test all(isfinite.(mstemresp))
        @test all(isfinite.(mrootresp))
        @test all(isfinite.(backleafresp))
        
        # Check value ranges for successful NPP calculation
        if npp != -9999.0
            @test npp > 0.0  # Should be positive under good conditions
            @test npp < gpp  # NPP should be less than GPP
            @test stemresp >= 0.0
            @test percentcost >= 0.0
            @test percentcost <= 100.0
            @test all(mstemresp .>= 0.0)
            @test all(mrootresp .>= 0.0)
            @test all(backleafresp .>= 0.0)
            
            # Stem respiration should equal sum of monthly values
            @test stemresp ≈ sum(mstemresp) atol=1e-10
            
            # Percentage cost should be reasonable
            @test percentcost > 0.0
            @test percentcost < 80.0  # Shouldn't be too high under good conditions
        end
    end
    
    @testset "Sapwood/Grass PFT Tests" begin
        # Create grass PFT
        grass_pft = C4TropicalGrass(12.0, 800.0, 28.0)
        set_characteristic(grass_pft, :allocfact, 0.4)
        set_characteristic(grass_pft, :respfact, 0.6)
        
        # Test inputs
        gpp = 1200.0
        alresp = 150.0
        temp = fill(25.0, 12)
        sapwood = 2  # Grass/sapwood
        lai = 3.0
        monthlyfpar = fill(0.6, 12)
        
        result_grass = respiration(gpp, alresp, temp, sapwood, lai, monthlyfpar, grass_pft)
        npp_g, stemresp_g, percentcost_g, mstemresp_g, mrootresp_g, backleafresp_g = result_grass
        
        # For grass/sapwood, stem respiration should be zero
        @test stemresp_g == 0.0
        @test all(mstemresp_g .== 0.0)
        
        # Other values should still be reasonable
        @test isfinite(npp_g)
        @test all(isfinite.(mrootresp_g))
        @test all(isfinite.(backleafresp_g))
        
        # Compare with woody PFT to ensure different behavior
        woody_pft = TemperateDeciduous(8.0, 1000.0, 15.0)
        set_characteristic(woody_pft, :allocfact, 0.4)
        set_characteristic(woody_pft, :respfact, 0.6)
        
        result_woody = respiration(gpp, alresp, temp, 1, lai, monthlyfpar, woody_pft)
        npp_w, stemresp_w, percentcost_w, mstemresp_w, mrootresp_w, backleafresp_w = result_woody
        
        # Woody should have stem respiration
        @test stemresp_w > 0.0
        @test any(mstemresp_w .> 0.0)
        
        # Grass should have higher NPP due to no stem respiration costs
        if npp_g != -9999.0 && npp_w != -9999.0
            @test npp_g > npp_w
        end
    end
    
    @testset "Temperature Dependency Tests" begin
        test_pft = BorealEvergreen(5.0, 600.0, 10.0)
        set_characteristic(test_pft, :allocfact, 0.35)
        set_characteristic(test_pft, :respfact, 0.7)
        
        gpp = 1000.0
        alresp = 100.0
        sapwood = 1
        lai = 2.5
        monthlyfpar = fill(0.5, 12)
        
        # Test with cold temperatures
        temp_cold = fill(0.0, 12)
        result_cold = respiration(gpp, alresp, temp_cold, sapwood, lai, monthlyfpar, test_pft)
        npp_cold, stemresp_cold, _, mstemresp_cold, _, _ = result_cold
        
        # Test with warm temperatures
        temp_warm = fill(25.0, 12)
        result_warm = respiration(gpp, alresp, temp_warm, sapwood, lai, monthlyfpar, test_pft)
        npp_warm, stemresp_warm, _, mstemresp_warm, _, _ = result_warm
        
        # Warm temperatures should lead to higher stem respiration
        @test stemresp_warm > stemresp_cold
        @test all(mstemresp_warm .>= mstemresp_cold)
        
        # Higher respiration should lead to lower NPP
        if npp_cold != -9999.0 && npp_warm != -9999.0
            @test npp_warm < npp_cold
        end
        
        # Test extreme cold (below -46.02°C threshold)
        temp_extreme_cold = fill(-50.0, 12)
        result_extreme = respiration(gpp, alresp, temp_extreme_cold, sapwood, lai, monthlyfpar, test_pft)
        npp_extreme, stemresp_extreme, _, mstemresp_extreme, _, _ = result_extreme
        
        # Stem respiration should be zero at extreme cold
        @test stemresp_extreme == 0.0
        @test all(mstemresp_extreme .== 0.0)
    end
    
    @testset "Carbon Balance Tests" begin
        balance_pft = CoolConifer(6.0, 700.0, 12.0)
        set_characteristic(balance_pft, :allocfact, 0.25)
        set_characteristic(balance_pft, :respfact, 0.9)
        
        gpp = 1800.0
        alresp = 250.0
        temp = [10.0, 12.0, 15.0, 20.0, 22.0, 25.0, 24.0, 22.0, 18.0, 15.0, 12.0, 10.0]
        sapwood = 1
        lai = 3.5
        monthlyfpar = [0.3, 0.4, 0.6, 0.8, 0.9, 1.0, 0.9, 0.8, 0.6, 0.4, 0.3, 0.3]
        
        result = respiration(gpp, alresp, temp, sapwood, lai, monthlyfpar, balance_pft)
        npp, stemresp, percentcost, mstemresp, mrootresp, backleafresp = result
        
        # Calculate components manually to verify carbon balance
        allocfact = get_characteristic(balance_pft, :allocfact)
        litterfall = lai * LN * allocfact
        finerootresp = P1 * litterfall
        leafmaint = sum(backleafresp)
        leafresp = alresp + leafmaint
        
        if npp != -9999.0
            # Calculate growth respiration
            growthresp = (1.0 - Y) * (gpp - stemresp - leafresp - finerootresp)
            
            # Verify carbon balance: NPP = GPP - all respiration costs
            calculated_npp = gpp - stemresp - leafresp - finerootresp - growthresp
            @test npp ≈ calculated_npp atol=1e-10
            
            # Verify percentage cost calculation
            expected_percentcost = 100.0 * (gpp - npp) / gpp
            @test percentcost ≈ expected_percentcost atol=1e-10
        end
        
        # Test minimum allocation requirement
        minallocation = 1.0 * litterfall
        if npp == -9999.0
            # This means the calculated NPP was below minimum allocation
            # Recalculate what it would have been
            leafmaint_calc = sum(backleafresp)
            leafresp_calc = alresp + leafmaint_calc
            growthresp_calc = (1.0 - Y) * (gpp - stemresp - leafresp_calc - finerootresp)
            calculated_npp = gpp - stemresp - leafresp_calc - finerootresp - growthresp_calc
            
            @test calculated_npp < minallocation
        else
            @test npp >= minallocation
        end
    end
    
    @testset "Edge Cases" begin
        edge_pft = TundraShrubs(1.0, 200.0, 2.0)
        set_characteristic(edge_pft, :allocfact, 0.5)
        set_characteristic(edge_pft, :respfact, 0.4)
        
        temp = fill(15.0, 12)
        sapwood = 1
        monthlyfpar = fill(0.4, 12)
        
        # Test with zero GPP
        result_zero_gpp = respiration(0.0, 50.0, temp, sapwood, 2.0, monthlyfpar, edge_pft)
        npp_zero, stemresp_zero, percentcost_zero, _, _, _ = result_zero_gpp
        
        @test npp_zero == -9999.0  # Should fail minimum allocation
        @test percentcost_zero == 0.0  # No GPP means no percentage calculation
        
        # Test with negative GPP
        result_neg_gpp = respiration(-100.0, 50.0, temp, sapwood, 2.0, monthlyfpar, edge_pft)
        npp_neg, _, percentcost_neg, _, _, _ = result_neg_gpp
        
        @test npp_neg == -9999.0
        @test percentcost_neg == 0.0
        
        # Test with zero LAI
        result_zero_lai = respiration(1000.0, 100.0, temp, sapwood, 0.0, monthlyfpar, edge_pft)
        npp_zero_lai, stemresp_zero_lai, _, mstemresp_zero_lai, _, _ = result_zero_lai
        
        @test stemresp_zero_lai == 0.0
        @test all(mstemresp_zero_lai .== 0.0)
        @test isnan(npp_zero_lai)
        
        # Test with very high GPP (should pass all constraints)
        result_high_gpp = respiration(10000.0, 200.0, temp, sapwood, 5.0, monthlyfpar, edge_pft)
        npp_high, _, percentcost_high, _, _, _ = result_high_gpp
        
        @test npp_high != -9999.0  # Should pass minimum allocation
        @test npp_high > 0.0
        @test percentcost_high > 0.0
        @test percentcost_high < 100.0
        
        # Test with very low GPP (should fail minimum allocation)
        result_low_gpp = respiration(50.0, 20.0, temp, sapwood, 3.0, monthlyfpar, edge_pft)
        npp_low, _, _, _, _, _ = result_low_gpp
        
        @test npp_low == -9999.0  # Should fail minimum allocation
    end
    
    @testset "Monthly Distribution Tests" begin
        monthly_pft = C3C4TemperateGrass(7.0, 600.0, 18.0)
        set_characteristic(monthly_pft, :allocfact, 0.3)
        set_characteristic(monthly_pft, :respfact, 0.8)
        
        gpp = 1400.0
        alresp = 180.0
        # Seasonal temperature variation
        temp = [2.0, 5.0, 10.0, 15.0, 20.0, 25.0, 28.0, 26.0, 22.0, 16.0, 10.0, 4.0]
        sapwood = 1
        lai = 3.0
        # Seasonal FPAR variation
        monthlyfpar = [0.1, 0.2, 0.4, 0.6, 0.8, 0.9, 0.9, 0.8, 0.6, 0.4, 0.2, 0.1]
        
        result = respiration(gpp, alresp, temp, sapwood, lai, monthlyfpar, monthly_pft)
        npp, stemresp, percentcost, mstemresp, mrootresp, backleafresp = result
        
        # Check seasonal patterns
        # Stem respiration should be higher in warmer months
        summer_months = [6, 7, 8]  # June, July, August
        winter_months = [1, 2, 12]  # December, January, February
        
        avg_summer_stemresp = sum(mstemresp[summer_months]) / length(summer_months)
        avg_winter_stemresp = sum(mstemresp[winter_months]) / length(winter_months)
        
        @test avg_summer_stemresp > avg_winter_stemresp
        
        # Root respiration distribution should follow stem respiration pattern
        @test all(mrootresp .>= 0.0)
        
        # Back leaf respiration should follow FPAR pattern
        @test all(backleafresp .>= 0.0)
        
        # Higher FPAR months should generally have higher back leaf respiration
        high_fpar_months = findall(x -> x > 0.7, monthlyfpar)
        low_fpar_months = findall(x -> x < 0.3, monthlyfpar)
        
        if !isempty(high_fpar_months) && !isempty(low_fpar_months)
            avg_high_fpar_backresp = sum(backleafresp[high_fpar_months]) / length(high_fpar_months)
            avg_low_fpar_backresp = sum(backleafresp[low_fpar_months]) / length(low_fpar_months)
            @test avg_high_fpar_backresp >= avg_low_fpar_backresp
        end
    end
    
    @testset "Type Consistency Tests" begin
        type_pft = BorealDeciduous(4.0, 500.0, 8.0)
        set_characteristic(type_pft, :allocfact, 0.4)
        set_characteristic(type_pft, :respfact, 0.6)
        
        # Test with Float32
        gpp_f32 = Float32(1200.0)
        alresp_f32 = Float32(150.0)
        temp_f32 = Float32[15.0, 16.0, 18.0, 20.0, 22.0, 24.0, 26.0, 24.0, 22.0, 19.0, 17.0, 15.0]
        lai_f32 = Float32(2.8)
        monthlyfpar_f32 = Float32[0.4, 0.5, 0.6, 0.7, 0.8, 0.8, 0.8, 0.7, 0.6, 0.5, 0.4, 0.4]
        
        result_f32 = respiration(gpp_f32, alresp_f32, temp_f32, 1, lai_f32, monthlyfpar_f32, type_pft)
        npp_f32, stemresp_f32, percentcost_f32, mstemresp_f32, mrootresp_f32, backleafresp_f32 = result_f32
        
        # Check type preservation
        @test typeof(npp_f32) == Float32 || npp_f32 == -9999.0
        @test typeof(stemresp_f32) == Float32
        @test typeof(percentcost_f32) == Float32
        @test eltype(mstemresp_f32) == Float32
        @test eltype(mrootresp_f32) == Float32
        @test eltype(backleafresp_f32) == Float32
        
        # Values should be finite
        if npp_f32 != -9999.0
            @test isfinite(npp_f32)
        end
        @test isfinite(stemresp_f32)
        @test isfinite(percentcost_f32)
        @test all(isfinite.(mstemresp_f32))
        @test all(isfinite.(mrootresp_f32))
        @test all(isfinite.(backleafresp_f32))
    end
    
    @testset "Array Length Validation" begin
        valid_pft = WoodyDesert(15.0, 300.0, 25.0)
        set_characteristic(valid_pft, :allocfact, 0.2)
        set_characteristic(valid_pft, :respfact, 1.0)
        
        gpp = 800.0
        alresp = 100.0
        sapwood = 1
        lai = 1.5
        
        # Test with wrong temperature array length
        @test_throws BoundsError respiration(gpp, alresp, fill(20.0, 11), sapwood, lai, fill(0.5, 12), valid_pft)

        # Test with wrong monthlyfpar array length
        @test_throws BoundsError respiration(gpp, alresp, fill(20.0, 12), sapwood, lai, fill(0.5, 10), valid_pft)
    end
    
    @testset "PFT Parameter Tests" begin
        # Test with different allocfact and respfact values
        param_pft1 = TropicalEvergreen(10.0, 1500.0, 27.0)
        param_pft2 = TropicalEvergreen(10.0, 1500.0, 27.0)
        
        # Set different parameters
        set_characteristic(param_pft1, :allocfact, 0.2)
        set_characteristic(param_pft1, :respfact, 0.5)
        set_characteristic(param_pft2, :allocfact, 0.4)
        set_characteristic(param_pft2, :respfact, 1.0)
        
        gpp = 1600.0
        alresp = 200.0
        temp = fill(26.0, 12)
        sapwood = 1
        lai = 4.0
        monthlyfpar = fill(0.7, 12)
        
        result1 = respiration(gpp, alresp, temp, sapwood, lai, monthlyfpar, param_pft1)
        result2 = respiration(gpp, alresp, temp, sapwood, lai, monthlyfpar, param_pft2)
        
        npp1, stemresp1, _, _, _, _ = result1
        npp2, stemresp2, _, _, _, _ = result2
        
        # Higher respfact should lead to higher stem respiration
        @test stemresp2 > stemresp1
        
        # Higher allocfact should lead to higher minimum allocation requirement
        # This might affect NPP depending on whether it passes the threshold
        @test isfinite(stemresp1)
        @test isfinite(stemresp2)
        
        # Both should have reasonable values
        if npp1 != -9999.0
            @test npp1 > 0.0
        end
        if npp2 != -9999.0
            @test npp2 > 0.0
        end
    end
end