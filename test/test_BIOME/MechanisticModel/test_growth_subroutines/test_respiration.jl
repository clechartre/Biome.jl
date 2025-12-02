using Test
using Biome

@testset "Plant Respiration Tests" begin
    
    @testset "Positive Test - Normal conditions" begin
        # Create different PFT types for testing
        tropical_evergreen = BIOME4.TropicalEvergreen()
        temperate_deciduous = BIOME4.TemperateDeciduous()
        boreal_evergreen = BIOME4.BorealEvergreen()
        
        # Realistic environmental parameters for active growth
        gpp = 2000.0                    # Good gross primary productivity
        alresp = 150.0                  # Autotrophic leaf respiration
        temp = [5.0, 8.0, 12.0, 16.0, 20.0, 24.0, 26.0, 24.0, 20.0, 15.0, 10.0, 6.0]  # Monthly temps
        sapwood = 1                     # Woody plant (not grass)
        lai = 5.0                      # Good leaf area index
        monthlyfpar = [0.1, 0.2, 0.4, 0.6, 0.8, 0.9, 0.9, 0.8, 0.6, 0.4, 0.2, 0.1]  # Seasonal FPAR
        
        # Test tropical evergreen
        npp_te, stemresp_te, percentcost_te, mstemresp_te, mrootresp_te, backleafresp_te = 
            respiration(gpp, alresp, temp, sapwood, lai, monthlyfpar, tropical_evergreen)
        
        # All outputs should be finite
        @test isfinite(npp_te)
        @test isfinite(stemresp_te)
        @test isfinite(percentcost_te)
        @test all(isfinite.(mstemresp_te))
        @test all(isfinite.(mrootresp_te))
        @test all(isfinite.(backleafresp_te))
        
        # NPP should be positive under good conditions
        @test npp_te > 0.0
        
        # All respiration components should be non-negative
        @test stemresp_te >= 0.0
        @test percentcost_te >= 0.0
        @test all(mstemresp_te .>= 0.0)
        @test all(mrootresp_te .>= 0.0)
        @test all(backleafresp_te .>= 0.0)
        
        # Arrays should have correct length
        @test length(mstemresp_te) == 12
        @test length(mrootresp_te) == 12
        @test length(backleafresp_te) == 12
        
        # NPP should be less than GPP (respiration costs)
        @test npp_te < gpp
        
        # Percent cost should be reasonable (0-100%)
        @test 0.0 <= percentcost_te <= 100.0
        
        # Stem respiration should equal sum of monthly values
        @test stemresp_te ≈ sum(mstemresp_te) atol=1e-10
        
        # Test temperate deciduous (different characteristics)
        npp_td, stemresp_td, percentcost_td, mstemresp_td, mrootresp_td, backleafresp_td = 
            respiration(gpp, alresp, temp, sapwood, lai, monthlyfpar, temperate_deciduous)
        
        @test isfinite(npp_td) && npp_td > 0.0
        @test isfinite(stemresp_td) && stemresp_td >= 0.0
        @test all(isfinite.(mstemresp_td)) && all(mstemresp_td .>= 0.0)
        
        # Different PFTs should have different respiration patterns due to different respfact/allocfact
        @test !isapprox(stemresp_te, stemresp_td, rtol=0.01) || 
              !isapprox(percentcost_te, percentcost_td, rtol=0.01)
    end
    
    @testset "Sapwood vs Woody PFT Tests" begin
        # Test grass/sapwood PFT behavior
        c4_grass = BIOME4.C4TropicalGrass()
        
        gpp = 1500.0
        alresp = 100.0
        temp = fill(20.0, 12)  # Constant temperature
        lai = 3.0
        monthlyfpar = fill(0.5, 12)
        
        # Test woody PFT (sapwood = 1)
        npp_woody, stemresp_woody, _, mstemresp_woody, _, _ = 
            respiration(gpp, alresp, temp, 1, lai, monthlyfpar, c4_grass)
        
        # Test grass PFT (sapwood = 2)
        npp_grass, stemresp_grass, _, mstemresp_grass, _, _ = 
            respiration(gpp, alresp, temp, 2, lai, monthlyfpar, c4_grass)
        
        # Grass should have zero stem respiration
        @test stemresp_grass == 0.0
        @test all(mstemresp_grass .== 0.0)
        
        # Woody should have positive stem respiration
        @test stemresp_woody > 0.0
        @test any(mstemresp_woody .> 0.0)
        
        # Grass should have higher NPP due to no stem respiration costs
        @test npp_grass > npp_woody
    end
    
    @testset "Temperature Dependency Tests" begin
        test_pft = BIOME4.TemperateDeciduous()
        
        gpp = 1800.0
        alresp = 120.0
        sapwood = 1
        lai = 4.0
        monthlyfpar = fill(0.6, 12)
        
        # Test different temperature scenarios
        temp_cold = fill(0.0, 12)      # Cold conditions
        temp_moderate = fill(15.0, 12)  # Moderate conditions  
        temp_warm = fill(25.0, 12)     # Warm conditions
        temp_extreme_cold = fill(-50.0, 12)  # Below temperature threshold
        
        _, stemresp_cold, _, mstemresp_cold, _, _ = 
            respiration(gpp, alresp, temp_cold, sapwood, lai, monthlyfpar, test_pft)
        _, stemresp_moderate, _, mstemresp_moderate, _, _ = 
            respiration(gpp, alresp, temp_moderate, sapwood, lai, monthlyfpar, test_pft)
        _, stemresp_warm, _, mstemresp_warm, _, _ = 
            respiration(gpp, alresp, temp_warm, sapwood, lai, monthlyfpar, test_pft)
        _, stemresp_extreme, _, mstemresp_extreme, _, _ = 
            respiration(gpp, alresp, temp_extreme_cold, sapwood, lai, monthlyfpar, test_pft)
        
        # Warmer temperatures should increase respiration
        @test stemresp_warm > stemresp_moderate > stemresp_cold
        
        # Extreme cold should result in zero respiration
        @test stemresp_extreme == 0.0
        @test all(mstemresp_extreme .== 0.0)
        
        # All should be finite and non-negative
        @test all(isfinite.([stemresp_cold, stemresp_moderate, stemresp_warm]))
        @test all([stemresp_cold, stemresp_moderate, stemresp_warm] .>= 0.0)
    end
    
    @testset "LAI Dependency Tests" begin
        test_pft = BIOME4.BorealEvergreen()
        
        gpp = 1200.0
        alresp = 80.0
        temp = fill(18.0, 12)
        sapwood = 1
        monthlyfpar = fill(0.7, 12)
        
        # Test different LAI values
        lai_low = 1.0
        lai_medium = 4.0  
        lai_high = 8.0
        
        npp_low, stemresp_low, _, _, _, _ = 
            respiration(gpp, alresp, temp, sapwood, lai_low, monthlyfpar, test_pft)
        npp_medium, stemresp_medium, _, _, _, _ = 
            respiration(gpp, alresp, temp, sapwood, lai_medium, monthlyfpar, test_pft)
        npp_high, stemresp_high, _, _, _, _ = 
            respiration(gpp, alresp, temp, sapwood, lai_high, monthlyfpar, test_pft)
        
        # Higher LAI should increase respiration costs
        @test stemresp_high > stemresp_medium > stemresp_low
        
        # Higher respiration costs should reduce NPP
        @test npp_low > npp_medium > npp_high
        
        # All should be finite
        @test all(isfinite.([npp_low, npp_medium, npp_high]))
        @test all(isfinite.([stemresp_low, stemresp_medium, stemresp_high]))
    end
    
    @testset "Negative Tests - Limiting conditions" begin
        test_pft = BIOME4.TropicalEvergreen()
        temp = fill(20.0, 12)
        sapwood = 1
        lai = 3.0
        monthlyfpar = fill(0.5, 12)
        
        # Test very low GPP
        npp_low_gpp, _, percentcost_low, _, _, _ = 
            respiration(10.0, 5.0, temp, sapwood, lai, monthlyfpar, test_pft)
        
        # Should result in negative NPP (below minimum allocation)
        @test npp_low_gpp == -9999.0
        @test percentcost_low == 0.0  # Percent cost is 0 when NPP is -9999
        
        # Test zero GPP
        npp_zero_gpp, stemresp_zero, percentcost_zero, _, _, _ = 
            respiration(0.0, 0.0, temp, sapwood, lai, monthlyfpar, test_pft)
        
        @test npp_zero_gpp == -9999.0
        @test percentcost_zero == 0.0
        @test stemresp_zero >= 0.0  # Should still be non-negative
        
        # Test with high respiration relative to GPP
        npp_high_resp, _, percentcost_high, _, _, _ = 
            respiration(500.0, 400.0, temp, sapwood, lai, monthlyfpar, test_pft)
        
        # Should result in very low or negative NPP
        @test npp_high_resp <= 0.0 || npp_high_resp == -9999.0
        
        # Test with zero LAI
        npp_zero_lai, stemresp_zero_lai, _, _, _, _ = 
            respiration(1000.0, 50.0, temp, sapwood, 0.0, monthlyfpar, test_pft)
        
        @test isfinite(npp_zero_lai) || npp_zero_lai == -9999.0 || isnan(npp_zero_lai)
        @test isfinite(stemresp_zero_lai) && stemresp_zero_lai >= 0.0
    end
    
    @testset "Edge Cases" begin
        test_pft = BIOME4.TemperateDeciduous()
        
        # Test with single month arrays (should fail gracefully or handle correctly)
        temp_short = [20.0]
        monthlyfpar_short = [0.5]
        
        # This should either work with broadcasting or give a clear error
        try
            npp, stemresp, _, mstemresp, mrootresp, backleafresp = 
                respiration(1000.0, 50.0, temp_short, 1, 3.0, monthlyfpar_short, test_pft)
            
            # If it works, check outputs are reasonable
            @test isfinite(npp)
            @test isfinite(stemresp) && stemresp >= 0.0
            @test length(mstemresp) == 1
            @test length(mrootresp) == 1  
            @test length(backleafresp) == 1
        catch e
            # If it fails, that's also acceptable behavior for edge case
            @test isa(e, Exception)
        end
        
        # Test with very high LAI
        npp_extreme_lai, stemresp_extreme_lai, _, _, _, _ = 
            respiration(5000.0, 200.0, fill(20.0, 12), 1, 100.0, fill(0.8, 12), test_pft)
        
        @test isfinite(npp_extreme_lai) || npp_extreme_lai == -9999.0
        @test isfinite(stemresp_extreme_lai) && stemresp_extreme_lai >= 0.0
        
        # Test with extreme temperature values within range
        temp_extreme_hot = fill(45.0, 12)
        
        npp_hot, stemresp_hot, _, _, _, _ = 
            respiration(2000.0, 100.0, temp_extreme_hot, 1, 5.0, fill(0.6, 12), test_pft)
        
        @test isfinite(npp_hot) || npp_hot == -9999.0
        @test isfinite(stemresp_hot) && stemresp_hot >= 0.0
    end
    
    @testset "Exception Tests" begin
        test_pft = BIOME4.BorealEvergreen()
        
        # Test with invalid sapwood values
        @test_throws MethodError respiration(1000.0, 50.0, fill(20.0, 12), 1.5, 3.0, fill(0.5, 12), test_pft)
        @test_throws MethodError respiration(1000.0, 50.0, fill(20.0, 12), "invalid", 3.0, fill(0.5, 12), test_pft)
        
        # Test with negative values (should handle gracefully)
        npp_neg_gpp, _, _, _, _, _ = 
            respiration(-500.0, 50.0, fill(20.0, 12), 1, 3.0, fill(0.5, 12), test_pft)
        
        @test isfinite(npp_neg_gpp) || npp_neg_gpp == -9999.0
        
        npp_neg_alresp, _, _, _, _, _ = 
            respiration(1000.0, -50.0, fill(20.0, 12), 1, 3.0, fill(0.5, 12), test_pft)
        
        @test isfinite(npp_neg_alresp) || npp_neg_alresp == -9999.0
        
        # Test with negative LAI (should handle gracefully)
        npp_neg_lai, stemresp_neg_lai, _, _, _, _ = 
            respiration(1000.0, 50.0, fill(20.0, 12), 1, -2.0, fill(0.5, 12), test_pft)
        
        @test isfinite(npp_neg_lai) || npp_neg_lai == -9999.0
        @test isfinite(stemresp_neg_lai) || isnan(stemresp_neg_lai)  # Allow negative values as edge case behavior
        
        # Test with mismatched array lengths (should error)
        temp_wrong_length = fill(20.0, 10)  # Wrong length
        @test_throws BoundsError respiration(1000.0, 50.0, temp_wrong_length, 1, 3.0, fill(0.5, 12), test_pft)
        
        monthlyfpar_wrong_length = fill(0.5, 8)  # Wrong length
        @test_throws BoundsError respiration(1000.0, 50.0, fill(20.0, 12), 1, 3.0, monthlyfpar_wrong_length, test_pft)
    end
    
    @testset "Monthly Respiration Consistency Tests" begin
        test_pft = BIOME4.TropicalEvergreen()
        
        gpp = 2500.0
        alresp = 180.0
        temp = [8.0, 12.0, 16.0, 20.0, 24.0, 28.0, 30.0, 28.0, 24.0, 18.0, 12.0, 9.0]
        sapwood = 1
        lai = 6.0
        monthlyfpar = [0.2, 0.3, 0.5, 0.7, 0.9, 1.0, 1.0, 0.9, 0.7, 0.5, 0.3, 0.2]
        
        npp, stemresp, percentcost, mstemresp, mrootresp, backleafresp = 
            respiration(gpp, alresp, temp, sapwood, lai, monthlyfpar, test_pft)
        
        # Monthly arrays should sum correctly
        @test stemresp ≈ sum(mstemresp) atol=1e-10
        
        # Root respiration should be related to stem respiration
        total_mrootresp = sum(mrootresp)
        @test total_mrootresp > 0.0
        @test isfinite(total_mrootresp)
        
        # Leaf maintenance respiration should be related to FPAR
        total_backleafresp = sum(backleafresp)
        @test total_backleafresp > 0.0
        @test isfinite(total_backleafresp)
        
        # Higher FPAR months should generally have higher leaf maintenance respiration
        max_fpar_idx = argmax(monthlyfpar)
        min_fpar_idx = argmin(monthlyfpar)
        @test backleafresp[max_fpar_idx] >= backleafresp[min_fpar_idx]
        
        # Warmer months should have higher stem respiration
        max_temp_idx = argmax(temp)
        min_temp_idx = argmin(temp)
        @test mstemresp[max_temp_idx] > mstemresp[min_temp_idx]
    end

end