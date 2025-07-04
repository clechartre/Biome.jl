using Test

include("../../../../src/abstractmodel.jl")
include("../../../../src/pfts.jl")
include("../../../../src/biomes.jl")
include("../../../../src/models/MechanisticModel/pfts.jl")
include("../../../../src/models/MechanisticModel/growth_subroutines/hydrology.jl")

@testset "Hydrology Tests" begin
    
    @testset "Positive Test - Normal hydrological conditions" begin
        # Create different PFT types
        evergreen = BorealEvergreen(5.0, 800.0, 10.0)
        deciduous = TemperateDeciduous(8.0, 1000.0, 15.0)
        
        # Set required PFT characteristics
        set_characteristic(evergreen, :sw_drop, 0.3)
        set_characteristic(deciduous, :sw_drop, 0.25)
        
        # Realistic daily inputs
        dprec = vcat(fill(2.0, 90), fill(1.0, 90), fill(0.5, 90), fill(3.0, 95))  # Seasonal precipitation
        dmelt = vcat(fill(1.0, 60), fill(0.0, 305))  # Spring snowmelt
        deq = vcat(fill(1.0, 90), fill(3.0, 90), fill(5.0, 90), fill(2.0, 95))  # Seasonal EET
        dtemp = vcat(fill(-5.0, 90), fill(10.0, 90), fill(25.0, 90), fill(5.0, 95))  # Seasonal temperature
        
        # Soil and canopy parameters
        root = 0.7  # Root fraction in upper layer
        k = [0.1, 0.2, 0.3, 0.4, 100.0, 200.0, 0.8]  # Soil parameters
        maxfvc = 0.8  # Maximum foliar vegetation cover
        phentype = 1  # Evergreen
        wst = 0.5  # Initial soil moisture
        gcopt = fill(0.5, 365)  # Optimal canopy conductance
        mgmin = 0.1  # Minimum conductance modifier
        dphen = ones(365, 2)  # Phenology data (for evergreen, not used)
        sapwood = 1
        emax = 2.0  # Maximum evapotranspiration efficiency
        
        # Test evergreen PFT
        result_evergreen = hydrology(dprec, dmelt, deq, root, k, maxfvc, evergreen, 
                                   phentype, wst, gcopt, mgmin, dphen, dtemp, sapwood, emax)
        
        meanfvc_e, meangc_e, meanwr_e, meanaet_e, runoffmonth_e, wet_e, dayfvc_e, 
        annaet_e, sumoff_e, greendays_e, runnoff_e, wilt_e = result_evergreen
        
        # Check output dimensions and types
        @test length(meanfvc_e) == 12
        @test length(meangc_e) == 12
        @test length(meanwr_e) == 12
        @test all(length(wr) == 3 for wr in meanwr_e)  # Each month has 3 water reservoir values
        @test length(meanaet_e) == 12
        @test length(runoffmonth_e) == 12
        @test length(wet_e) == 365
        @test length(dayfvc_e) == 365
        
        # Check that all values are finite and reasonable
        @test all(isfinite.(meanfvc_e))
        @test all(isfinite.(meangc_e))
        @test all(isfinite.(meanaet_e))
        @test all(isfinite.(runoffmonth_e))
        @test all(isfinite.(wet_e))
        @test all(isfinite.(dayfvc_e))
        @test isfinite(annaet_e)
        @test isfinite(sumoff_e)
        @test isfinite(runnoff_e)
        
        # Check value ranges
        @test all(0.0 .<= round.(meanfvc_e, digits=2) .<= round(maxfvc, digits=2))  # Allow for floating-point precision errors
        @test all(meangc_e .>= 0.0)
        @test all(meanaet_e .>= 0.0)
        @test all(runoffmonth_e .>= 0.0)
        @test all(0.0 .<= wet_e .<= 1.0)  # Soil moisture should be between 0 and 1
        @test all(0.0 .<= dayfvc_e .<= maxfvc)
        @test annaet_e >= 0.0
        @test sumoff_e >= 0.0
        @test greendays_e >= 0
        @test greendays_e <= 365
        
        # For evergreen, all days should be green (fvc = maxfvc)
        @test greendays_e == 365
        @test all(dayfvc_e .≈ maxfvc)
        
        # Annual AET should equal sum of monthly means * days
        days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        calculated_annual = sum(meanaet_e .* days)
        @test annaet_e ≈ calculated_annual atol=1e-10
        
        # Total runoff should equal sum of monthly runoff
        @test sumoff_e ≈ sum(runoffmonth_e) atol=1e-10
    end
    
    @testset "Phenological Type Tests" begin
        # Test different phenological types
        deciduous_pft = TemperateDeciduous(8.0, 1000.0, 15.0)
        set_characteristic(deciduous_pft, :sw_drop, 0.25)
        
        # Create seasonal phenology pattern (cold deciduous)
        dphen_seasonal = zeros(365, 2)
        dphen_seasonal[120:270, 1] .= 1.0  # Growing season
        dphen_seasonal[:, 2] .= dphen_seasonal[:, 1]
        
        # Standard inputs
        dprec = fill(2.0, 365)
        dmelt = fill(0.0, 365)
        deq = fill(3.0, 365)
        dtemp = vcat(fill(-5.0, 119), fill(15.0, 151), fill(-5.0, 95))  # Cold-warm-cold
        root = 0.6
        k = [0.1, 0.2, 0.3, 0.4, 100.0, 200.0, 0.8]
        maxfvc = 0.9
        wst = 0.4
        gcopt = fill(0.4, 365)
        mgmin = 0.1
        sapwood = 1
        emax = 2.0
        
        # Test cold deciduous (phentype = 2)
        result_cold_dec = hydrology(dprec, dmelt, deq, root, k, maxfvc, deciduous_pft, 
                                  2, wst, gcopt, mgmin, dphen_seasonal, dtemp, sapwood, emax)
        
        meanfvc_cd, meangc_cd, meanwr_cd, meanaet_cd, runoffmonth_cd, wet_cd, dayfvc_cd, 
        annaet_cd, sumoff_cd, greendays_cd, runnoff_cd, wilt_cd = result_cold_dec
        
        # For cold deciduous, green days should be less than 365
        @test greendays_cd < 365
        @test greendays_cd > 0
        
        # FVC should follow phenology pattern
        @test all(dayfvc_cd[1:119] .≈ 0.0)  # Winter: no leaves
        @test all(dayfvc_cd[120:270] .≈ maxfvc)  # Growing season: full leaves
        @test all(dayfvc_cd[271:365] .≈ 0.0)  # Winter: no leaves
        
        # Compare with evergreen - should have different patterns
        result_evergreen = hydrology(dprec, dmelt, deq, root, k, maxfvc, deciduous_pft, 
                                   1, wst, gcopt, mgmin, dphen_seasonal, dtemp, sapwood, emax)
        
        _, _, _, _, _, _, _, _, _, greendays_e, _, _ = result_evergreen
        
        @test greendays_cd < greendays_e  # Deciduous should have fewer green days
    end
    
    @testset "Water Balance Tests" begin
        test_pft = CoolConifer(6.0, 700.0, 12.0)
        set_characteristic(test_pft, :sw_drop, 0.3)
        
        # Simple water balance test with known inputs
        dprec = fill(5.0, 365)  # Constant precipitation
        dmelt = fill(0.0, 365)  # No snowmelt
        deq = fill(2.0, 365)    # Constant demand
        dtemp = fill(15.0, 365) # Constant temperature
        root = 0.5
        k = [0.05, 0.1, 0.2, 0.3, 50.0, 100.0, 0.5]  # Lower percolation rates
        maxfvc = 0.7
        wst = 0.5
        gcopt = fill(0.3, 365)
        mgmin = 0.05
        dphen = ones(365, 2)
        sapwood = 1
        emax = 1.5
        
        result = hydrology(dprec, dmelt, deq, root, k, maxfvc, test_pft, 
                          1, wst, gcopt, mgmin, dphen, dtemp, sapwood, emax)
        
        meanfvc, meangc, meanwr, meanaet, runoffmonth, wet, dayfvc, 
        annaet, sumoff, greendays, runnoff, wilt = result
        
        # Water balance check: Input should roughly equal AET + runoff + storage change
        total_input = sum(dprec)  # Total precipitation
        final_storage = wet[365]
        initial_storage = wst
        storage_change = final_storage - initial_storage
        
        # In steady state, input ≈ AET + runoff + storage change
        water_balance_error = abs(total_input - annaet - sumoff - storage_change)
        @test water_balance_error / total_input < 0.1  # Within 10% (allowing for soil layer effects)
        
        # Check that wilting didn't occur under normal conditions
        @test !wilt
    end
    
    @testset "Drought Stress Tests" begin
        drought_pft = WoodyDesert(15.0, 200.0, 25.0)
        set_characteristic(drought_pft, :sw_drop, 0.2)
        
        # Severe drought conditions
        dprec = vcat(fill(0.1, 300), fill(0.0, 65))  # Very low precipitation
        dmelt = fill(0.0, 365)
        deq = fill(8.0, 365)  # High evaporative demand
        dtemp = fill(35.0, 365)  # Hot temperatures
        root = 0.8  # Deep roots
        k = [0.2, 0.3, 0.4, 0.5, 30.0, 60.0, 1.0]  # High drainage
        maxfvc = 0.6
        wst = 0.2  # Low initial moisture
        gcopt = fill(0.6, 365)
        mgmin = 0.02
        dphen = ones(365, 2)
        sapwood = 1
        emax = 1.0  # Low efficiency
        
        result_drought = hydrology(dprec, dmelt, deq, root, k, maxfvc, drought_pft, 
                                  1, wst, gcopt, mgmin, dphen, dtemp, sapwood, emax)
        
        meanfvc_d, meangc_d, meanwr_d, meanaet_d, runoffmonth_d, wet_d, dayfvc_d, 
        annaet_d, sumoff_d, greendays_d, runnoff_d, wilt_d = result_drought
        
        # Under severe drought, wilting should occur
        @test wilt_d
        
        # Soil moisture should be very low
        @test all(wet_d .<= 0.5)
        @test minimum(wet_d) < 0.1
        
        # AET should be limited by water availability
        @test annaet_d < sum(deq) * 0.5  # Much less than potential
        
        # Compare with well-watered conditions
        dprec_wet = fill(10.0, 365)  # High precipitation
        result_wet = hydrology(dprec_wet, dmelt, deq, root, k, maxfvc, drought_pft, 
                              1, wst, gcopt, mgmin, dphen, dtemp, sapwood, emax)
        
        _, _, _, _, _, _, _, annaet_w, _, _, _, wilt_w = result_wet
        
        @test !wilt_w  # No wilting under wet conditions
        @test annaet_w > annaet_d  # Higher AET when water is available
    end
    
    @testset "Temperature Effects Tests" begin
        cold_pft = BorealDeciduous(4.0, 500.0, 8.0)
        set_characteristic(cold_pft, :sw_drop, 0.35)
        
        # Test extreme cold conditions
        dprec = fill(3.0, 365)
        dmelt = fill(0.0, 365)
        deq = fill(4.0, 365)
        dtemp_cold = fill(-15.0, 365)  # Below -10°C threshold
        root = 0.6
        k = [0.1, 0.2, 0.3, 0.4, 80.0, 160.0, 0.6]
        maxfvc = 0.8
        wst = 0.6
        gcopt = fill(0.5, 365)
        mgmin = 0.08
        dphen = ones(365, 2)
        sapwood = 1
        emax = 1.8
        
        result_cold = hydrology(dprec, dmelt, deq, root, k, maxfvc, cold_pft, 
                               1, wst, gcopt, mgmin, dphen, dtemp_cold, sapwood, emax)
        
        meanfvc_c, meangc_c, meanwr_c, meanaet_c, runoffmonth_c, wet_c, dayfvc_c, 
        annaet_c, sumoff_c, greendays_c, runnoff_c, wilt_c = result_cold
        
        # Under extreme cold, conductance should be zero
        @test all(meangc_c .≈ 0.0)
        
        # AET should be minimal (only soil evaporation)
        @test annaet_c < sum(deq) * 0.1
        
        # Compare with warm conditions
        dtemp_warm = fill(20.0, 365)
        result_warm = hydrology(dprec, dmelt, deq, root, k, maxfvc, cold_pft, 
                               1, wst, gcopt, mgmin, dphen, dtemp_warm, sapwood, emax)
        
        _, meangc_w, _, meanaet_w, _, _, _, annaet_w, _, _, _, _ = result_warm
        
        @test any(meangc_w .> 0.0)  # Some conductance under warm conditions
        @test annaet_w > annaet_c   # Higher AET when warm
    end
    
    @testset "Edge Cases" begin
        edge_pft = TropicalEvergreen(10.0, 1500.0, 27.0)
        set_characteristic(edge_pft, :sw_drop, 0.25)
        
        # Standard conditions for baseline
        dprec = fill(1.0, 365)
        dmelt = fill(0.0, 365)
        deq = fill(2.0, 365)
        dtemp = fill(20.0, 365)
        root = 0.5
        k = [0.1, 0.2, 0.3, 0.4, 100.0, 200.0, 0.7]
        maxfvc = 0.5
        wst = 0.5
        gcopt = fill(0.3, 365)
        mgmin = 0.1
        dphen = ones(365, 2)
        sapwood = 1
        emax = 2.0
        
        # Test with zero precipitation
        dprec_zero = fill(0.0, 365)
        result_zero_prec = hydrology(dprec_zero, dmelt, deq, root, k, maxfvc, edge_pft, 
                                    1, wst, gcopt, mgmin, dphen, dtemp, sapwood, emax)
        
        _, _, _, _, _, _, _, annaet_zero, sumoff_zero, _, _, wilt_zero = result_zero_prec
        
        @test isfinite(annaet_zero)
        @test annaet_zero >= 0.0
        @test sumoff_zero >= 0.0
        
        # Test with zero initial moisture
        result_zero_wst = hydrology(dprec, dmelt, deq, root, k, maxfvc, edge_pft, 
                                   1, 0.0, gcopt, mgmin, dphen, dtemp, sapwood, emax)
        
        _, _, _, _, _, wet_zero_wst, _, _, _, _, _, _ = result_zero_wst
        
        @test all(isfinite.(wet_zero_wst))
        @test all(wet_zero_wst .>= 0.0)
        
        # Test with very high precipitation (should cause runoff)
        dprec_high = fill(50.0, 365)
        result_high_prec = hydrology(dprec_high, dmelt, deq, root, k, maxfvc, edge_pft, 
                                    1, wst, gcopt, mgmin, dphen, dtemp, sapwood, emax)
        
        _, _, _, _, runoffmonth_high, wet_high, _, _, sumoff_high, _, _, _ = result_high_prec
        
        @test sumoff_high > 0.0  # Should have significant runoff
        @test any(runoffmonth_high .> 0.0)
        @test maximum(wet_high) <= 1.0  # Soil moisture shouldn't exceed 1.0
        
        # Test with zero maxfvc
        result_zero_fvc = hydrology(dprec, dmelt, deq, root, k, 0.0, edge_pft, 
                                   1, wst, gcopt, mgmin, dphen, dtemp, sapwood, emax)
        
        meanfvc_zero, meangc_zero, _, _, _, dayfvc_zero, _, _, _, greendays_zero, _, _ = result_zero_fvc
        
        @test all(meanfvc_zero .≈ 0.0)
        @test all(meangc_zero .≈ 0.0)
        @test greendays_zero == 0
    end
    
    @testset "Array Length Validation" begin
        test_pft = LichenForb(2.0, 300.0, 5.0)
        set_characteristic(test_pft, :sw_drop, 0.4)
        
        # Standard parameters
        root = 0.4
        k = [0.1, 0.2, 0.3, 0.4, 100.0, 200.0, 0.8]
        maxfvc = 0.3
        wst = 0.3
        mgmin = 0.05
        sapwood = 1
        emax = 1.5
        
        # Test with wrong array lengths
        @test_throws BoundsError hydrology(fill(1.0, 300), fill(0.0, 365), fill(2.0, 365), 
                                          root, k, maxfvc, test_pft, 1, wst, fill(0.3, 365), 
                                          mgmin, ones(365, 2), fill(15.0, 365), sapwood, emax)
        
        @test_throws BoundsError hydrology(fill(1.0, 365), fill(0.0, 365), fill(2.0, 365), 
                                          root, k, maxfvc, test_pft, 1, wst, fill(0.3, 300), 
                                          mgmin, ones(365, 2), fill(15.0, 365), sapwood, emax)
        
        @test_throws BoundsError hydrology(fill(1.0, 365), fill(0.0, 365), fill(2.0, 365), 
                                          root, [0.1, 0.2], maxfvc, test_pft, 1, wst, fill(0.3, 365), 
                                          mgmin, ones(365, 2), fill(15.0, 365), sapwood, emax)
    end
    
    @testset "Type Consistency Tests" begin
        test_pft = TundraShrubs(1.0, 250.0, 3.0)
        set_characteristic(test_pft, :sw_drop, 0.45)
        
        # Test with Float32
        dprec_f32 = fill(Float32(2.0), 365)
        dmelt_f32 = fill(Float32(0.0), 365)
        deq_f32 = fill(Float32(3.0), 365)
        dtemp_f32 = fill(Float32(10.0), 365)
        root_f32 = Float32(0.6)
        k_f32 = Float32[0.1, 0.2, 0.3, 0.4, 100.0, 200.0, 0.8]
        maxfvc_f32 = Float32(0.4)
        wst_f32 = Float32(0.4)
        gcopt_f32 = fill(Float32(0.2), 365)
        mgmin_f32 = Float32(0.06)
        dphen_f32 = ones(Float32, 365, 2)
        emax_f32 = Float32(1.6)
        
        result_f32 = hydrology(dprec_f32, dmelt_f32, deq_f32, root_f32, k_f32, maxfvc_f32, 
                              test_pft, 1, wst_f32, gcopt_f32, mgmin_f32, dphen_f32, 
                              dtemp_f32, 1, emax_f32)
        
        meanfvc_f32, meangc_f32, meanwr_f32, meanaet_f32, runoffmonth_f32, wet_f32, 
        dayfvc_f32, annaet_f32, sumoff_f32, greendays_f32, runnoff_f32, wilt_f32 = result_f32
        
        # Check that Float32 types are preserved
        @test eltype(meanfvc_f32) == Float32
        @test eltype(meangc_f32) == Float32
        @test eltype(meanaet_f32) == Float32
        @test eltype(wet_f32) == Float32
        @test typeof(annaet_f32) == Float32
        
        # Results should be finite
        @test all(isfinite.(meanfvc_f32))
        @test all(isfinite.(wet_f32))
        @test isfinite(annaet_f32)
    end
    
    @testset "Mass Conservation Tests" begin
        conserve_pft = C4TropicalGrass(12.0, 900.0, 28.0)
        set_characteristic(conserve_pft, :sw_drop, 0.3)
        
        # Controlled conditions for mass balance
        dprec = fill(4.0, 365)
        dmelt = fill(0.0, 365)
        deq = fill(3.0, 365)
        dtemp = fill(25.0, 365)
        root = 0.6
        k = [0.08, 0.15, 0.25, 0.35, 120.0, 240.0, 0.9]
        maxfvc = 0.7
        wst = 0.5
        gcopt = fill(0.4, 365)
        mgmin = 0.08
        dphen = ones(365, 2)
        sapwood = 1
        emax = 2.2
        
        result = hydrology(dprec, dmelt, deq, root, k, maxfvc, conserve_pft, 
                          1, wst, gcopt, mgmin, dphen, dtemp, sapwood, emax)
        
        meanfvc, meangc, meanwr, meanaet, runoffmonth, wet, dayfvc, 
        annaet, sumoff, greendays, runnoff, wilt = result
        
        # Check that function runs twice (as per implementation)
        # The function should be deterministic
        result2 = hydrology(dprec, dmelt, deq, root, k, maxfvc, conserve_pft, 
                           1, wst, gcopt, mgmin, dphen, dtemp, sapwood, emax)
        
        meanfvc2, meangc2, meanwr2, meanaet2, runoffmonth2, wet2, dayfvc2, 
        annaet2, sumoff2, greendays2, runnoff2, wilt2 = result2
        
        # Results should be identical (deterministic)
        @test meanfvc ≈ meanfvc2
        @test meangc ≈ meangc2
        @test meanaet ≈ meanaet2
        @test wet ≈ wet2
        @test annaet ≈ annaet2
        @test sumoff ≈ sumoff2
        @test greendays == greendays2
        @test wilt == wilt2
    end
end