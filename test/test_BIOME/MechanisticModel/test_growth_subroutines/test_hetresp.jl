using Test

@testset "Heterotrophic Respiration Tests" begin
    
    @testset "Positive Test - Normal conditions" begin
        # Create different PFT types
        tropical_evergreen = BIOME4.TropicalEvergreen()
        tropical_drought = BIOME4.TropicalDroughtDeciduous()
        temperate_deciduous = BIOME4.TemperateDeciduous()
        
        # Realistic environmental data
        nppann = 1500.0
        tsoil = [12.0, 14.0, 18.0, 22.0, 25.0, 27.0, 29.0, 27.0, 24.0, 20.0, 16.0, 13.0]
        aet = [50.0, 60.0, 80.0, 100.0, 120.0, 140.0, 130.0, 110.0, 90.0, 70.0, 55.0, 45.0]
        moist = [0.6, 0.5, 0.4, 0.3, 0.2, 0.1, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6]
        isoveg = -25.0
        
        # Initialize output arrays
        Rlit = zeros(12)
        Rfst = zeros(12)
        Rslo = zeros(12)
        Rtot = zeros(12)
        isoR = zeros(12)
        isoflux = zeros(12)
        Rmean = 0.0
        meanKlit = 0.0
        meanKsoil = 0.0
        
        # Test tropical evergreen
        result_trop_ever = hetresp(tropical_evergreen, nppann, tsoil, aet, moist, isoveg,
                                  Rlit, Rfst, Rslo, Rtot, isoR, isoflux, Rmean, meanKlit, meanKsoil)
        
        Rlit_te, Rfst_te, Rslo_te, Rtot_te, isoR_te, isoflux_te, Rmean_te, meanKlit_te, meanKsoil_te = result_trop_ever
        
        # Check that all outputs are finite and reasonable
        @test all(isfinite.(Rlit_te))
        @test all(isfinite.(Rfst_te))
        @test all(isfinite.(Rslo_te))
        @test all(isfinite.(Rtot_te))
        @test all(isfinite.(isoR_te))
        @test all(isfinite.(isoflux_te))
        @test isfinite(Rmean_te)
        @test isfinite(meanKlit_te)
        @test isfinite(meanKsoil_te)
        
        # All respiration should be non-negative
        @test all(Rlit_te .>= 0.0)
        @test all(Rfst_te .>= 0.0)
        @test all(Rslo_te .>= 0.0)
        @test all(Rtot_te .>= 0.0)
        @test Rmean_te >= 0.0
        @test meanKlit_te >= 0.0
        @test meanKsoil_te >= 0.0
        
        # Total respiration should equal sum of components
        for m in 1:12
            @test Rtot_te[m] ≈ Rlit_te[m] + Rfst_te[m] + Rslo_te[m] atol=1e-10
        end
        
        # Mean should be average of monthly values
        @test Rmean_te ≈ sum(Rtot_te) / 12.0 atol=1e-10
        
        # In equilibrium, total annual respiration should equal NPP
        total_annual_resp = sum(Rtot_te)
        @test total_annual_resp ≈ nppann atol=1e-6
        
        # Test temperate deciduous (different partitioning)
        Rlit_td = zeros(12)
        Rfst_td = zeros(12)
        Rslo_td = zeros(12)
        Rtot_td = zeros(12)
        isoR_td = zeros(12)
        isoflux_td = zeros(12)
        
        result_temp_dec = hetresp(temperate_deciduous, nppann, tsoil, aet, moist, isoveg,
                                 Rlit_td, Rfst_td, Rslo_td, Rtot_td, isoR_td, isoflux_td, 
                                 Rmean, meanKlit, meanKsoil)
        
        Rlit_td, Rfst_td, Rslo_td, Rtot_td, isoR_td, isoflux_td, Rmean_td, meanKlit_td, meanKsoil_td = result_temp_dec
        
        # Should also have valid outputs
        @test all(isfinite.(Rtot_td))
        @test all(Rtot_td .>= 0.0)
        @test sum(Rtot_td) ≈ nppann atol=1e-6
        
        # Different PFTs should have different partitioning patterns
        # (but both should sum to same total)
        @test !isapprox(Rlit_te, Rlit_td, rtol=0.01)  # Different partitioning
    end
    
    @testset "NPP Partitioning Tests" begin
        # Test the different partitioning strategies
        tropical = BIOME4.TropicalEvergreen()
        temperate = BIOME4.TemperateDeciduous()
        
        nppann = 1000.0
        tsoil = fill(18.0, 12)
        aet = fill(100.0, 12)
        moist = fill(0.5, 12)
        isoveg = -25.0
        
        # Initialize arrays
        Rlit = zeros(12); Rfst = zeros(12); Rslo = zeros(12); Rtot = zeros(12)
        isoR = zeros(12); isoflux = zeros(12)
        
        # Test tropical partitioning (65% litter, 34.3% fast, 0.7% slow)
        result_trop = hetresp(tropical, nppann, tsoil, aet, moist, isoveg,
                             Rlit, Rfst, Rslo, Rtot, isoR, isoflux, 0.0, 0.0, 0.0)
        
        Rlit_t, Rfst_t, Rslo_t, Rtot_t, isoR_t, isoflux_t, Rmean_t, meanKlit_t, meanKsoil_t = result_trop
        
        # Check partitioning ratios for tropical
        total_lit = sum(Rlit_t)
        total_fst = sum(Rfst_t)
        total_slo = sum(Rslo_t)
        
        @test total_lit ≈ 0.65 * nppann atol=1e-6
        @test total_fst ≈ 0.98 * 0.35 * nppann atol=1e-6
        @test total_slo ≈ 0.02 * 0.35 * nppann atol=1e-6
        
        # Reset arrays for temperate test
        fill!(Rlit, 0.0); fill!(Rfst, 0.0); fill!(Rslo, 0.0); fill!(Rtot, 0.0)
        fill!(isoR, 0.0); fill!(isoflux, 0.0)
        
        # Test temperate partitioning (70% litter, 29.55% fast, 0.45% slow)
        result_temp = hetresp(temperate, nppann, tsoil, aet, moist, isoveg,
                             Rlit, Rfst, Rslo, Rtot, isoR, isoflux, 0.0, 0.0, 0.0)
        
        Rlit_temp, Rfst_temp, Rslo_temp, Rtot_temp, isoR_temp, isoflux_temp, 
        Rmean_temp, meanKlit_temp, meanKsoil_temp = result_temp
        
        # Check partitioning ratios for temperate
        total_lit_temp = sum(Rlit_temp)
        total_fst_temp = sum(Rfst_temp)
        total_slo_temp = sum(Rslo_temp)
        
        @test total_lit_temp ≈ 0.70 * nppann atol=1e-6
        @test total_fst_temp ≈ 0.985 * 0.30 * nppann atol=1e-6
        @test total_slo_temp ≈ 0.015 * 0.30 * nppann atol=1e-6
    end
    
    @testset "Temperature and Moisture Dependencies" begin
        test_pft = BIOME4.BorealEvergreen()
        
        nppann = 800.0
        aet = fill(80.0, 12)
        isoveg = -26.0
        
        # Test temperature dependency
        tsoil_cold = fill(5.0, 12)
        tsoil_warm = fill(25.0, 12)
        moist = fill(0.5, 12)
        
        # Initialize arrays
        Rlit = zeros(12); Rfst = zeros(12); Rslo = zeros(12); Rtot = zeros(12)
        isoR = zeros(12); isoflux = zeros(12)
        
        result_cold = hetresp(test_pft, nppann, tsoil_cold, aet, moist, isoveg,
                             Rlit, Rfst, Rslo, Rtot, isoR, isoflux, 0.0, 0.0, 0.0)
        
        Rlit_cold, Rfst_cold, Rslo_cold, Rtot_cold, _, _, _, meanKlit_cold, meanKsoil_cold = result_cold
        
        # Reset arrays
        fill!(Rlit, 0.0); fill!(Rfst, 0.0); fill!(Rslo, 0.0); fill!(Rtot, 0.0)
        fill!(isoR, 0.0); fill!(isoflux, 0.0)
        
        result_warm = hetresp(test_pft, nppann, tsoil_warm, aet, moist, isoveg,
                             Rlit, Rfst, Rslo, Rtot, isoR, isoflux, 0.0, 0.0, 0.0)
        
        Rlit_warm, Rfst_warm, Rslo_warm, Rtot_warm, _, _, _, meanKlit_warm, meanKsoil_warm = result_warm
        
        # Warmer soils should have higher decay rates for fast and slow pools
        @test meanKsoil_warm > meanKsoil_cold
        
        # Test moisture dependency
        moist_dry = fill(0.1, 12)
        moist_wet = fill(0.9, 12)
        tsoil = fill(15.0, 12)
        
        # Reset arrays
        fill!(Rlit, 0.0); fill!(Rfst, 0.0); fill!(Rslo, 0.0); fill!(Rtot, 0.0)
        fill!(isoR, 0.0); fill!(isoflux, 0.0)
        
        result_dry = hetresp(test_pft, nppann, tsoil, aet, moist_dry, isoveg,
                            Rlit, Rfst, Rslo, Rtot, isoR, isoflux, 0.0, 0.0, 0.0)
        
        _, _, _, _, _, _, _, _, meanKsoil_dry = result_dry
        
        # Reset arrays
        fill!(Rlit, 0.0); fill!(Rfst, 0.0); fill!(Rslo, 0.0); fill!(Rtot, 0.0)
        fill!(isoR, 0.0); fill!(isoflux, 0.0)
        
        result_wet = hetresp(test_pft, nppann, tsoil, aet, moist_wet, isoveg,
                            Rlit, Rfst, Rslo, Rtot, isoR, isoflux, 0.0, 0.0, 0.0)
        
        _, _, _, _, _, _, _, _, meanKsoil_wet = result_wet
        
        # Wetter conditions should have higher decay rates
        @test meanKsoil_wet > meanKsoil_dry
    end
    
    @testset "Isotope Calculations" begin
        test_pft = BIOME4.CoolConifer()
        
        nppann = 1200.0
        tsoil = fill(8.0, 12)
        aet = fill(60.0, 12)
        moist = fill(0.4, 12)
        isoveg = -24.0
        
        # Initialize arrays
        Rlit = zeros(12); Rfst = zeros(12); Rslo = zeros(12); Rtot = zeros(12)
        isoR = zeros(12); isoflux = zeros(12)
        
        result = hetresp(test_pft, nppann, tsoil, aet, moist, isoveg,
                        Rlit, Rfst, Rslo, Rtot, isoR, isoflux, 0.0, 0.0, 0.0)
        
        Rlit_iso, Rfst_iso, Rslo_iso, Rtot_iso, isoR_iso, isoflux_iso, _, _, _ = result
        
        # Check isotope calculations
        # isolit should be isoveg - 0.75, isofst should be isoveg - 1.5, isoslo should be isoveg - 2.25
        isolit_expected = isoveg - 0.75  # -24.75
        isofst_expected = isoveg - 1.5   # -25.5
        isoslo_expected = isoveg - 2.25  # -26.25
        
        # Calculate expected isoR values
        Plit = 0.70 * nppann
        Pfst = 0.985 * 0.30 * nppann
        Pslo = 0.015 * 0.30 * nppann
        
        expected_isoR = (Plit/nppann) * isolit_expected + (Pfst/nppann) * isofst_expected + (Pslo/nppann) * isoslo_expected
        
        for m in 1:12
            @test isoR_iso[m] ≈ expected_isoR atol=1e-6
            @test isoflux_iso[m] ≈ (-8.0 - expected_isoR) * Rtot_iso[m] atol=1e-6
        end
    end
    
    @testset "Edge Cases" begin
        test_pft = BIOME4.TemperateDeciduous()
        
        tsoil = fill(18.0, 12)
        aet = fill(100.0, 12)
        moist = fill(0.5, 12)
        isoveg = -25.0
        
        # Initialize arrays
        Rlit = zeros(12); Rfst = zeros(12); Rslo = zeros(12); Rtot = zeros(12)
        isoR = zeros(12); isoflux = zeros(12)
        
        # Test with zero NPP
        result_zero = hetresp(test_pft, 0.0, tsoil, aet, moist, isoveg,
                             Rlit, Rfst, Rslo, Rtot, isoR, isoflux, 0.0, 0.0, 0.0)
        
        Rlit_zero, Rfst_zero, Rslo_zero, Rtot_zero, isoR_zero, isoflux_zero, 
        Rmean_zero, meanKlit_zero, meanKsoil_zero = result_zero
        
        # All outputs should be zero
        @test all(Rlit_zero .== 0.0)
        @test all(Rfst_zero .== 0.0)
        @test all(Rslo_zero .== 0.0)
        @test all(Rtot_zero .== 0.0)
        @test all(isoR_zero .== 0.0)
        @test all(isoflux_zero .== 0.0)
        @test Rmean_zero == 0.0
        @test meanKlit_zero == 0.0
        @test meanKsoil_zero == 0.0
        
        # Test with negative NPP
        fill!(Rlit, 0.0); fill!(Rfst, 0.0); fill!(Rslo, 0.0); fill!(Rtot, 0.0)
        fill!(isoR, 0.0); fill!(isoflux, 0.0)
        
        result_neg = hetresp(test_pft, -100.0, tsoil, aet, moist, isoveg,
                            Rlit, Rfst, Rslo, Rtot, isoR, isoflux, 0.0, 0.0, 0.0)
        
        Rlit_neg, Rfst_neg, Rslo_neg, Rtot_neg, _, _, _, _, _ = result_neg
        
        # Should also be zero
        @test all(Rtot_neg .== 0.0)
        
        # Test with extreme temperatures
        tsoil_extreme_cold = fill(-20.0, 12)
        tsoil_extreme_hot = fill(60.0, 12)
        
        fill!(Rlit, 0.0); fill!(Rfst, 0.0); fill!(Rslo, 0.0); fill!(Rtot, 0.0)
        fill!(isoR, 0.0); fill!(isoflux, 0.0)
        
        result_extreme_cold = hetresp(test_pft, 1000.0, tsoil_extreme_cold, aet, moist, isoveg,
                                     Rlit, Rfst, Rslo, Rtot, isoR, isoflux, 0.0, 0.0, 0.0)
        
        _, _, _, Rtot_extreme_cold, _, _, _, _, _ = result_extreme_cold
        
        @test all(isfinite.(Rtot_extreme_cold))
        @test sum(Rtot_extreme_cold) ≈ 1000.0 atol=1e-6
        
        # Test with extreme moisture
        moist_extreme_dry = fill(0.0, 12)
        moist_extreme_wet = fill(1.0, 12)
        
        fill!(Rlit, 0.0); fill!(Rfst, 0.0); fill!(Rslo, 0.0); fill!(Rtot, 0.0)
        fill!(isoR, 0.0); fill!(isoflux, 0.0)
        
        result_extreme_dry = hetresp(test_pft, 1000.0, tsoil, aet, moist_extreme_dry, isoveg,
                                    Rlit, Rfst, Rslo, Rtot, isoR, isoflux, 0.0, 0.0, 0.0)
        
        _, _, _, Rtot_extreme_dry, _, _, _, _, _ = result_extreme_dry
        
        @test all(isfinite.(Rtot_extreme_dry))
        @test sum(Rtot_extreme_dry) ≈ 1000.0 atol=1e-6
    end
    
    @testset "Array Length Validation" begin
        test_pft = BIOME4.BorealDeciduous()
        
        nppann = 600.0
        isoveg = -27.0
        
        # Initialize arrays
        Rlit = zeros(12); Rfst = zeros(12); Rslo = zeros(12); Rtot = zeros(12)
        isoR = zeros(12); isoflux = zeros(12)
        
        # Test with wrong array lengths
        @test_throws BoundsError hetresp(test_pft, nppann, fill(18.0, 10), 
                                        fill(100.0, 12), fill(0.5, 12), isoveg,
                                        Rlit, Rfst, Rslo, Rtot, isoR, isoflux, 0.0, 0.0, 0.0)
        
        @test_throws BoundsError hetresp(test_pft, nppann, fill(18.0, 13), 
                                        fill(100.0, 12), fill(0.5, 10), isoveg,
                                        Rlit, Rfst, Rslo, Rtot, isoR, isoflux, 0.0, 0.0, 0.0)
    end
    
    @testset "Type Consistency Tests" begin
        test_pft = BIOME4.LichenForb()
        
        # Test with Float32
        nppann_f32 = Float32(800.0)
        tsoil_f32 = fill(Float32(12.0), 12)
        aet_f32 = fill(Float32(70.0), 12)
        moist_f32 = fill(Float32(0.4), 12)
        isoveg_f32 = Float32(-26.0)
        
        Rlit_f32 = zeros(Float32, 12); Rfst_f32 = zeros(Float32, 12)
        Rslo_f32 = zeros(Float32, 12); Rtot_f32 = zeros(Float32, 12)
        isoR_f32 = zeros(Float32, 12); isoflux_f32 = zeros(Float32, 12)
        
        result_f32 = hetresp(test_pft, nppann_f32, tsoil_f32, aet_f32, moist_f32, isoveg_f32,
                            Rlit_f32, Rfst_f32, Rslo_f32, Rtot_f32, isoR_f32, isoflux_f32, 
                            Float32(0.0), Float32(0.0), Float32(0.0))
        
        _, _, _, Rtot_f32_result, _, _, Rmean_f32, _, _ = result_f32
        
        @test typeof(Rmean_f32) == Float32
        @test all(isfinite.(Rtot_f32_result))
        @test sum(Rtot_f32_result) ≈ nppann_f32 atol=1e-4
    end
end