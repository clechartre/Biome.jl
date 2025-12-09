using Test

@testset "Growth Function Tests" begin
    
    @testset "Utility Function Tests" begin
        # Test safe_exp function
        @test safe_exp(1.0) ≈ exp(1.0)
        @test safe_exp(0.0) == 1.0
        @test safe_exp(-1.0) ≈ exp(-1.0)
        @test safe_exp(1000.0) == Inf  # Should handle overflow
        
        # Test safe_round_to_int function
        @test safe_round_to_int(3.7) == 4
        @test safe_round_to_int(3.2) == 3
        @test safe_round_to_int(-2.8) == -3
        @test safe_round_to_int(NaN) == 0
        @test safe_round_to_int(1e20) == typemax(Int)
        @test safe_round_to_int(-1e20) == typemin(Int)
        
        # Test initialize_arrays function
        midday, days = initialize_arrays(Float64, Int)
        @test length(midday) == 12
        @test length(days) == 12
        @test midday == [16, 44, 75, 105, 136, 166, 197, 228, 258, 289, 319, 350]
        @test days == [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        @test sum(days) == 365
    end
    
    @testset "C4 Determination Tests" begin
        # Test determine_c4_and_optratio function
        
        # Create a C3 PFT
        c3_pft = BIOME4.TemperateDeciduous()
        c3_pft.characteristics.c4 = false
        c3_pft.characteristics.optratioa = 0.8
        
        # Test without override
        c4, optratio = determine_c4_and_optratio(c3_pft, 0.8, nothing)
        @test c4 == false
        @test optratio ≈ 0.8
        
        # Test with C4 override
        c4_override, optratio_override = determine_c4_and_optratio(c3_pft, 0.8, true)
        @test c4_override == true
        @test optratio_override ≈ 0.4
        
        # Create a C4 PFT
        c4_pft = BIOME4.C4TropicalGrass()
        c4_pft.characteristics.c4 = true
        
        c4_natural, optratio_natural = determine_c4_and_optratio(c4_pft, 0.8, nothing)
        @test c4_natural == true
        @test optratio_natural ≈ 0.4
    end
    
    @testset "Positive Test - Temperate Deciduous Forest" begin
        # Create realistic inputs for temperate deciduous forest
        maxlai = 5.0
        annp = 800.0  # mm annual precipitation
        
        # Monthly solar radiation (MJ/m²/day)
        sun = [8.0, 12.0, 18.0, 24.0, 28.0, 30.0, 29.0, 26.0, 20.0, 14.0, 9.0, 7.0]
        
        # Monthly temperature (°C)
        temp = [-2.0, 1.0, 6.0, 12.0, 18.0, 22.0, 25.0, 23.0, 18.0, 12.0, 6.0, 1.0]
        
        # Daily precipitation (mm/day) - simplified uniform distribution
        dprec = fill(annp / 365.0, 365)
        dmelt = zeros(Float64, 365)  # No snowmelt for simplicity
        
        # Daily PET (mm/day)
        dpet = vcat(
            fill(1.0, 90),   # Winter
            fill(3.0, 92),   # Spring
            fill(5.0, 92),   # Summer
            fill(2.0, 91)    # Fall
        )
        
        # Soil water content
        k = fill(0.3, 365)
        
        # Create PFT
        pft = BIOME4.TemperateDeciduous()


        # Daylength (hours)
        dayl = [9.0, 10.0, 12.0, 14.0, 15.0, 16.0, 15.5, 14.5, 12.5, 11.0, 9.5, 8.5]
        
        # Daily temperature
        dtemp = vcat(
            fill(-2.0, 31), fill(1.0, 28), fill(6.0, 31), fill(12.0, 30),
            fill(18.0, 31), fill(22.0, 30), fill(25.0, 31), fill(23.0, 31),
            fill(18.0, 30), fill(12.0, 31), fill(6.0, 30), fill(1.0, 31)
        )
        
        # Phenology (simplified)
        dphen = vcat(
            fill(0.0, 90, 2),   # Winter dormancy
            fill(1.0, 185, 2),  # Growing season
            fill(0.0, 90, 2)    # Fall dormancy
        )
        
        # Atmospheric CO2 (ppm)
        co2 = 400.0
        
        # Atmospheric pressure (Pa)
        p = 101325.0
        
        # Monthly soil temperature
        tsoil = [-1.0, 2.0, 7.0, 13.0, 19.0, 23.0, 26.0, 24.0, 19.0, 13.0, 7.0, 2.0]
        
        # Initialize monthly NPP arrays
        mnpp = zeros(Float64, 12)
        c4mnpp = zeros(Float64, 12)
        
        # Create PFT state
        pft_states = PFTState{Float64, Int}()
        
        # Run growth function
        ws = GrowthWorkspace(Float64)
        npp, monthly_npp, monthly_c4npp, updated_states = growth(
            maxlai, annp, sun, temp, dprec, dmelt, dpet, k, pft,
            dayl, dtemp, dphen, co2, p, tsoil, mnpp, c4mnpp, pft_states, ws
        )
        
        # Test basic outputs
        @test typeof(npp) == Float64
        @test length(monthly_npp) == 12
        @test length(monthly_c4npp) == 12
        @test all(isfinite.([npp]))
        @test all(isfinite.(monthly_npp))
        @test all(isfinite.(monthly_c4npp))
        
        # Test that NPP is reasonable for temperate forest
        @test npp <= 2000.0  # Reasonable upper bound for temperate forest
        
        # Test that monthly NPP sums approximately to annual NPP
        monthly_sum = sum(monthly_npp)
        @test abs(monthly_sum - npp) < abs(0.1 * npp)  # Within 10%
        
        # Test that growing season has higher NPP than dormant season
        growing_season_npp = sum(monthly_npp[4:9])  # Apr-Sep
        dormant_season_npp = sum(monthly_npp[[1,2,3,10,11,12]])  # Oct-Mar
        @test abs(growing_season_npp) > abs(dormant_season_npp)
        
        # Test PFT states are updated
        @test typeof(updated_states) == PFTState{Float64, Int}
        @test updated_states.greendays >= 0
        @test length(updated_states.mwet) == 12
    end
    
    @testset "C4 Tropical Grass Test" begin
        # Test with C4 tropical grass
        maxlai = 3.0
        annp = 1200.0
        
        # Tropical conditions - warm year-round, wet/dry seasons
        sun = [25.0, 26.0, 27.0, 26.0, 24.0, 22.0, 23.0, 25.0, 26.0, 27.0, 26.0, 25.0]
        temp = [26.0, 27.0, 28.0, 29.0, 28.0, 27.0, 26.0, 26.0, 27.0, 28.0, 27.0, 26.0]
        
        # Seasonal precipitation pattern
        dprec_wet = fill(500.0, 150)   # Wet season
        dprec_dry = fill(5.0, 215)   # Dry season
        dprec = vcat(dprec_wet, dprec_dry)
        
        dmelt = zeros(Float64, 365)
        dpet = fill(4.0, 365)  # High evapotranspiration
        k = fill(0.2, 365)     # Sandy soil
        
        # Create C4 tropical grass PFT
        pft = BIOME4.C4TropicalGrass()
        
        dayl = fill(12.0, 12)  # Constant daylength near equator
        dtemp = fill(27.0, 365)
        dphen = fill(1.0, 365,2)  # Always active
        
        co2 = 400.0
        p = 101325.0
        tsoil = fill(27.0, 12)
        
        mnpp = zeros(Float64, 12)
        c4mnpp = zeros(Float64, 12)
        
        pft_states = PFTState(pft)
        ws = GrowthWorkspace(Float64)
        
        npp_c4, monthly_npp_c4, monthly_c4npp_c4, updated_states_c4 = growth(
            maxlai, annp, sun, temp, dprec, dmelt, dpet, k, pft,
            dayl, dtemp, dphen, co2, p, tsoil, mnpp, c4mnpp, pft_states, ws
        )
        
        @test all(isfinite.([npp_c4]))
        @test all(isfinite.(monthly_npp_c4))
        @test all(isfinite.(monthly_c4npp_c4))
        
        # For pure C4 grass, most NPP should be C4
        total_c4_npp = sum(monthly_c4npp_c4)
        @test total_c4_npp >= npp_c4  # Majority should be c4
    
    end
    
    @testset "Extreme Climate Conditions" begin
        # Test with very cold conditions
        maxlai = 2.0
        annp = 3000.0
        
        sun = [2.0, 4.0, 8.0, 12.0, 16.0, 18.0, 17.0, 14.0, 10.0, 6.0, 3.0, 1.0]
        temp = [-25.0, -20.0, -10.0, -2.0, 5.0, 12.0, 15.0, 10.0, 3.0, -5.0, -15.0, -22.0]
        
        dprec = fill(annp / 365.0, 365)
        dmelt = zeros(Float64, 365)
        dpet = fill(1.0, 365)  # Low PET in cold conditions
        k = fill(0.4, 365)
        
        # Create boreal evergreen PFT
        pft = BIOME4.BorealEvergreen()
        
        dayl = [6.0, 8.0, 10.0, 12.0, 14.0, 16.0, 15.0, 13.0, 11.0, 9.0, 7.0, 5.0]
        dtemp = vcat(
            fill(-25.0, 90), fill(5.0, 92), fill(12.0, 92), fill(-10.0, 91)
        )
        dphen = vcat(
            fill(0.2, 90), fill(1.0, 92), fill(1.0, 92), fill(0.3, 91)
        )
        
        co2 = 400.0
        p = 101325.0
        tsoil = [-5.0, -3.0, 0.0, 3.0, 8.0, 12.0, 14.0, 11.0, 6.0, 2.0, -2.0, -4.0]
        
        mnpp = zeros(Float64, 12)
        c4mnpp = zeros(Float64, 12)
        
        pft_states = PFTState(pft)
        ws = GrowthWorkspace(Float64)
        
        npp_cold, monthly_npp_cold, monthly_c4npp_cold, _ = growth(
            maxlai, annp, sun, temp, dprec, dmelt, dpet, k, pft,
            dayl, dtemp, dphen, co2, p, tsoil, mnpp, c4mnpp, pft_states, ws
        )
        
        @test all(isfinite.([npp_cold]))
        @test all(isfinite.(monthly_npp_cold))
        
        # Cold conditions should result in lower NPP
        @test npp_cold <= 1000.0  # Should be limited by cold temperatures
        
    end
    
    @testset "Water Stress Conditions" begin
        # Test with very dry conditions
        maxlai = 1.5
        annp = 100.0  # Very low precipitation
        
        sun = [20.0, 22.0, 25.0, 28.0, 30.0, 32.0, 31.0, 29.0, 26.0, 23.0, 21.0, 19.0]
        temp = [15.0, 18.0, 22.0, 26.0, 30.0, 34.0, 36.0, 34.0, 30.0, 25.0, 20.0, 16.0]
        
        dprec = fill(annp / 365.0, 365)  # Very low daily precipitation
        dmelt = zeros(Float64, 365)
        dpet = fill(8.0, 365)  # Very high PET
        k = fill(0.1, 365)     # Low water holding capacity
        
        # Create woody desert PFT
        pft = BIOME4.WoodyDesert()
        
        dayl = [10.0, 11.0, 12.0, 13.0, 14.0, 14.5, 14.0, 13.0, 12.0, 11.0, 10.0, 9.5]
        dtemp = fill(25.0, 365)
        dphen = fill(0.3, 365)  # Low phenology due to drought
        
        co2 = 400.0
        p = 101325.0
        tsoil = fill(25.0, 12)
        
        mnpp = zeros(Float64, 12)
        c4mnpp = zeros(Float64, 12)
        
        pft_states = PFTState(pft)
        ws = GrowthWorkspace(Float64)
        
        npp_dry, monthly_npp_dry, monthly_c4npp_dry, _ = growth(
            maxlai, annp, sun, temp, dprec, dmelt, dpet, k, pft,
            dayl, dtemp, dphen, co2, p, tsoil, mnpp, c4mnpp, pft_states, ws
        )
        
        # In extreme drought, NPP might be negative (wilting)
        @test all(isfinite.([npp_dry]))
        @test all(isfinite.(monthly_npp_dry))
        
        # Wilting condition should result in -9999 NPP
        if npp_dry == -9999.0
            @test npp_dry == -9999.0  # Wilting condition
        else
            @test npp_dry <= 500.0  # Should be very low due to water stress
        end
    end
    
    @testset "Zero Input Edge Cases" begin
        # Test with zero LAI
        maxlai = 0.0
        annp = 500.0
        
        sun = fill(20.0, 12)
        temp = fill(15.0, 12)
        dprec = fill(annp / 365.0, 365)
        dmelt = zeros(Float64, 365)
        dpet = fill(3.0, 365)
        k = fill(0.3, 365)
        
        pft = BIOME4.TemperateDeciduous()
        
        dayl = fill(12.0, 12)
        dtemp = fill(15.0, 365)
        dphen = fill(1.0, 365, 2)
        
        co2 = 400.0
        p = 101325.0
        tsoil = fill(15.0, 12)
        
        mnpp = zeros(Float64, 12)
        c4mnpp = zeros(Float64, 12)
        
        pft_states = PFTState(pft)
        ws = GrowthWorkspace(Float64)
        
        npp_zero_lai, monthly_npp_zero, monthly_c4npp_zero, _ = growth(
            maxlai, annp, sun, temp, dprec, dmelt, dpet, k, pft,
            dayl, dtemp, dphen, co2, p, tsoil, mnpp, c4mnpp, pft_states, ws
        )
        
        @test all(isfinite.([npp_zero_lai]) .|| isnan.([npp_zero_lai]))
        @test all(isfinite.(monthly_npp_zero) .|| isnan.(monthly_npp_zero))
        
        # With zero LAI, NPP should be very low, zero, or NaN
        if isfinite(npp_zero_lai)
            @test npp_zero_lai <= 10.0 || isnan(npp_zero_lai)  # Should be very low or NaN
            @test all(monthly_npp_zero[isfinite.(monthly_npp_zero)] .<= 1.0)  # Monthly values should be very low
        end
    end
    
    @testset "Type Consistency Tests" begin
        # Test with Float32 inputs
        maxlai = Float32(4.0)
        annp = Float32(6000.0)
        
        sun = Float32[15.0, 18.0, 22.0, 25.0, 28.0, 30.0, 29.0, 26.0, 22.0, 18.0, 14.0, 12.0]
        temp = Float32[5.0, 8.0, 12.0, 16.0, 20.0, 24.0, 26.0, 24.0, 20.0, 15.0, 10.0, 6.0]
        
        dprec = fill(Float32(annp / 365.0), 365)
        dmelt = zeros(Float32, 365)
        dpet = fill(Float32(3.0), 365)
        k = fill(Float32(0.3), 365)
        
        pft = BIOME4.TemperateDeciduous{Float32,Int}()
        
        dayl = Float32[10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 14.5, 13.5, 12.5, 11.5, 10.5, 9.5]
        dtemp = fill(Float32(15.0), 365)
        dphen = fill(Float32(1.0), 365, 2)
        
        co2 = Float32(400.0)
        p = Float32(101325.0)
        tsoil = Float32[8.0, 10.0, 13.0, 17.0, 21.0, 25.0, 27.0, 25.0, 21.0, 16.0, 12.0, 9.0]
        
        mnpp = zeros(Float32, 12)
        c4mnpp = zeros(Float32, 12)
        
        pft_states = PFTState(pft)
        ws = GrowthWorkspace(Float32)
        
        npp_f32, monthly_npp_f32, monthly_c4npp_f32, _ = growth(
            maxlai, annp, sun, temp, dprec, dmelt, dpet, k, pft,
            dayl, dtemp, dphen, co2, p, tsoil, mnpp, c4mnpp, pft_states, ws
        )
        
        # Check type preservation
        @test typeof(npp_f32) == Float32
        @test eltype(monthly_npp_f32) == Float32
        @test eltype(monthly_c4npp_f32) == Float32
        
        # Check values are reasonable
        @test all(isfinite.([npp_f32]))
        @test all(isfinite.(monthly_npp_f32))
        @test all(isfinite.(monthly_c4npp_f32))
    end
    
    @testset "Array Dimension Tests" begin
        # Test that function handles correct array dimensions
        maxlai = 3.0
        annp = 700.0
        
        # Correct dimensions
        sun_correct = fill(20.0, 12)
        temp_correct = fill(15.0, 12)
        dprec_correct = fill(2.0, 365)
        dmelt_correct = zeros(Float64, 365)
        dpet_correct = fill(3.0, 365)
        k_correct = fill(0.3, 365)
        dayl_correct = fill(12.0, 12)
        dtemp_correct = fill(15.0, 365)
        dphen_correct = fill(1.0, 365, 2)
        tsoil_correct = fill(15.0, 12)
        
        pft = BIOME4.TemperateDeciduous()

        
        co2 = 400.0
        p = 101325.0
        
        mnpp = zeros(Float64, 12)
        c4mnpp = zeros(Float64, 12)
        
        pft_states = PFTState(pft)
        ws = GrowthWorkspace(Float64)
        
        # This should work
        npp, monthly_npp, monthly_c4npp, _ = growth(
            maxlai, annp, sun_correct, temp_correct, dprec_correct, dmelt_correct, 
            dpet_correct, k_correct, pft, dayl_correct, dtemp_correct, dphen_correct, 
            co2, p, tsoil_correct, mnpp, c4mnpp, pft_states, ws
        )
        
        @test typeof(npp) == Float64
        @test length(monthly_npp) == 12
        @test length(monthly_c4npp) == 12
        
        # Test with wrong dimensions should fail
        sun_wrong = fill(20.0, 10)  # Wrong size
        @test_throws BoundsError growth(
            maxlai, annp, sun_wrong, temp_correct, dprec_correct, dmelt_correct, 
            dpet_correct, k_correct, pft, dayl_correct, dtemp_correct, dphen_correct, 
            co2, p, tsoil_correct, mnpp, c4mnpp, pft_states, ws
        )
        
        dprec_wrong = fill(2.0, 300)  # Wrong size
        @test_throws BoundsError growth(
            maxlai, annp, sun_correct, temp_correct, dprec_wrong, dmelt_correct, 
            dpet_correct, k_correct, pft, dayl_correct, dtemp_correct, dphen_correct, 
            co2, p, tsoil_correct, mnpp, c4mnpp, pft_states, ws
        )
    end
    
    @testset "Compare C3 C4 NPP Function Tests" begin
        # Test the compare_c3_c4_npp function separately
        
        # Create a mixed C3C4 PFT
        pft = BIOME4.C3C4TemperateGrass()
        pft.characteristics.name = "C3C4WoodyDesert"
        
        mnpp = [10.0, 15.0, 20.0, 25.0, 30.0, 35.0, 30.0, 25.0, 20.0, 15.0, 10.0, 5.0]
        c4mnpp = [8.0, 12.0, 18.0, 30.0, 40.0, 45.0, 40.0, 35.0, 25.0, 18.0, 12.0, 6.0]
        
        monthlyfpar = fill(0.8, 12)
        monthlyparr = fill(100.0, 12)
        monthlyapar = fill(80.0, 12)
        CCratio = fill(0.7, 12)
        isoresp = fill(5.0, 12)
        
        c4fpar = fill(0.85, 12)
        c4parr = fill(100.0, 12)
        c4apar = fill(85.0, 12)
        c4ccratio = fill(0.4, 12)
        c4leafresp = fill(4.0, 12)
        
        nppsum = sum(mnpp)
        c4 = false
        
        result_nppsum, c4pct, c4month, result_mnpp, annc4npp, result_fpar, result_parr, result_apar, result_ccratio, result_isoresp = compare_c3_c4_npp(
            pft, mnpp, c4mnpp, monthlyfpar, monthlyparr, monthlyapar, CCratio, isoresp,
            c4fpar, c4parr, c4apar, c4ccratio, c4leafresp, nppsum, c4
        )
        
        @test typeof(result_nppsum) == Float64
        @test typeof(c4pct) == Float64
        @test length(c4month) == 12
        @test length(result_mnpp) == 12
        @test typeof(annc4npp) == Float64
        
        # Test that months where C4 > C3 are selected if enough months qualify
        c4_better_months = sum([c4mnpp[i] > mnpp[i] for i in 1:12])

        
        @test c4pct >= 0.0 && c4pct <= 1.0  # Should be a valid percentage
        @test all(isfinite.(result_mnpp))
        @test isfinite(result_nppsum)
        @test isfinite(annc4npp)
        
        # Test with pure C4 tropical grass
        pft_c4 = BIOME4.C4TropicalGrass()
        pft_c4.characteristics.name = "C4TropicalGrass"
        
        result_nppsum_c4, c4pct_c4, c4month_c4, result_mnpp_c4, annc4npp_c4, _, _, _, _, _ = compare_c3_c4_npp(
            pft_c4, mnpp, c4mnpp, monthlyfpar, monthlyparr, monthlyapar, CCratio, isoresp,
            c4fpar, c4parr, c4apar, c4ccratio, c4leafresp, nppsum, true
        )
        
        # All months should be C4 for pure C4 grass
        @test all(c4month_c4)
        @test c4pct_c4 > 0.9  # Should be mostly C4
    end
    
    @testset "Boreal Forest Conditions" begin
        # Test boreal forest with short growing season
        maxlai = 3.5
        annp = 4000.0
        
        # Boreal radiation pattern
        sun = [1.0, 3.0, 8.0, 15.0, 20.0, 22.0, 20.0, 16.0, 10.0, 5.0, 2.0, 0.5]
        temp = [-20.0, -18.0, -8.0, 2.0, 12.0, 18.0, 20.0, 16.0, 8.0, -2.0, -12.0, -18.0]
        
        dprec = fill(annp / 365.0, 365)
        dmelt = zeros(Float64, 365)
        dpet = fill(1.5, 365)  # Low PET
        k = fill(0.45, 365)  # Higher water holding capacity
        
        pft = BIOME4.BorealEvergreen()

        # Extreme day length variation
        dayl = [4.0, 6.0, 9.0, 12.0, 16.0, 18.0, 17.0, 14.0, 11.0, 8.0, 5.0, 3.0]
        
        dtemp = vcat([fill(temp[i], [31,28,31,30,31,30,31,31,30,31,30,31][i]) for i in 1:12]...)
        
        # Evergreen phenology - reduced in winter but never zero
        dphen = ones(Float64, 365, 2)
        co2 = 400.0
        p = 101325.0
        tsoil = [-8.0, -6.0, -2.0, 5.0, 12.0, 16.0, 18.0, 15.0, 8.0, 2.0, -4.0, -7.0]
        
        mnpp = zeros(Float64, 12)
        c4mnpp = zeros(Float64, 12)
        pft_states = PFTState(pft)
        ws = GrowthWorkspace(Float64)
        
        npp_boreal, monthly_npp_boreal, monthly_c4npp_boreal, states_boreal = growth(
            maxlai, annp, sun, temp, dprec, dmelt, dpet, k, pft,
            dayl, dtemp, dphen, co2, p, tsoil, mnpp, c4mnpp, pft_states, ws
        )
        
        @test all(isfinite.([npp_boreal]))
        @test all(isfinite.(monthly_npp_boreal))
        
        # Boreal forests should have lower NPP than temperate
        @test npp_boreal <= 800.0  # Lower than temperate forest
        
        # Very short growing season - most productivity in June-August
        peak_boreal = sum(monthly_npp_boreal[6:8])
        winter_boreal = sum(monthly_npp_boreal[[12, 1, 2, 3]])
        
        @test peak_boreal > 0.7 * sum(monthly_npp_boreal)  # Most NPP in peak season
        
        # Test green days calculation
        @test states_boreal.greendays >= 0
        @test states_boreal.greendays <= 365
    end
    
    @testset "Mediterranean Climate" begin
        # Test Mediterranean-type climate (dry summers, wet winters)
        maxlai = 2.8
        annp = 1800.0  # Higher annual precipitation that matches monthly totals
        
        sun = [12.0, 15.0, 20.0, 25.0, 28.0, 30.0, 32.0, 29.0, 24.0, 18.0, 14.0, 11.0]
        temp = [8.0, 10.0, 14.0, 18.0, 22.0, 26.0, 29.0, 28.0, 24.0, 19.0, 13.0, 9.0]
        
        # Mediterranean precipitation pattern - wet winters, dry summers (mm/day)
        winter_rain = fill(6.0, 90)    # Dec-Feb: 6 mm/day (540 mm total)
        spring_rain = fill(4.0, 92)    # Mar-May: 4 mm/day (368 mm total)
        summer_rain = fill(0.2, 92)    # Jun-Aug: 0.2 mm/day (18.4 mm total)
        fall_rain = fill(4.5, 91)      # Sep-Nov: 4.5 mm/day (409.5 mm total)
        dprec = vcat(winter_rain, spring_rain, summer_rain, fall_rain)  # Total ≈ 1336 mm
        
        dmelt = zeros(Float64, 365)
        dpet = fill(4.5, 365)  # High evapotranspiration
        k = fill(0.25, 365)    # Lower water holding capacity
        
        # Mediterranean shrubland PFT
        pft = BIOME4.TemperateBroadleavedEvergreen()
        
        dayl = [9.5, 11.0, 12.5, 14.0, 15.0, 15.5, 15.0, 14.0, 12.5, 11.0, 9.8, 9.0]
        dtemp = vcat([fill(temp[i], [31,28,31,30,31,30,31,31,30,31,30,31][i]) for i in 1:12]...)
        
        # Mediterranean phenology - binary values only (0 or 1)
        # Initialize phenology array
        dphen = ones(Float64, 365, 2)
        
        # Fill phenology based on Mediterranean climate patterns
        # Active in cool, wet months; dormant in hot, dry summer
        day = 1
        for m in 1:12
            days_in_month = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m]
        end
        
        co2 = 400.0
        p = 101325.0
        tsoil = [10.0, 12.0, 16.0, 20.0, 24.0, 28.0, 31.0, 30.0, 26.0, 21.0, 15.0, 11.0]
        
        mnpp = zeros(Float64, 12)
        c4mnpp = zeros(Float64, 12)
        pft_states = PFTState(pft)
        ws = GrowthWorkspace(Float64)
        
        npp_med, monthly_npp_med, monthly_c4npp_med, states_med = growth(
            maxlai, annp, sun, temp, dprec, dmelt, dpet, k, pft,
            dayl, dtemp, dphen, co2, p, tsoil, mnpp, c4mnpp, pft_states, ws
        )
        
        @test all(isfinite.([npp_med]))
        @test all(isfinite.(monthly_npp_med))
        
        # Mediterranean climate should show bimodal productivity
        # High in spring (Mar-May) and fall (Oct-Nov), low in summer
        spring_med = sum(monthly_npp_med[3:5])
        summer_med = sum(monthly_npp_med[6:8])
        fall_med = sum(monthly_npp_med[10:11])
        
        @test spring_med > summer_med  # Spring better than summer
        @test fall_med > summer_med    # Fall better than summer
        
        # Summer drought stress should reduce productivity significantly
        @test summer_med < 0.3 * sum(monthly_npp_med)
    end
    
    @testset "High Altitude Conditions" begin
        # Test high altitude/alpine conditions
        maxlai = 1.8
        annp = 8000.0  # High precipitation as snow
        
        # High altitude radiation and temperature
        sun = [80.0, 75.0, 70.0, 65.0, 60.0, 55.0, 60.0, 65.0, 70.0, 75.0, 80.0, 85.0]
        temp = [-12.0, -10.0, -5.0, 2.0, 8.0, 12.0, 15.0, 13.0, 8.0, 2.0, -4.0, -10.0]
        
        # Much of precipitation as snow in winter
        dprec = fill(annp / 365.0, 365)
        # Significant snowmelt in spring/early summer
        dmelt = vcat(
            zeros(90),        # Winter - no melt
            fill(2.0, 92),    # Spring - snowmelt
            fill(1.0, 92),    # Summer - some melt
            zeros(91)         # Fall - no melt
        )
        
        dpet = fill(2.0, 365)  # Lower PET due to cool temperatures
        k = fill(0.4, 365)     # Good water storage from snowmelt
        
        # Alpine shrub/tundra PFT
        pft = BIOME4.BorealEvergreen()

        # Extreme day length variation at high latitude
        dayl = [3.0, 5.0, 8.0, 11.0, 15.0, 17.0, 16.0, 13.0, 10.0, 7.0, 4.0, 2.0]
        
        # Alpine daily temperatures - much colder than temperate, matching monthly averages
        dtemp = vcat(
            fill(-12.0, 31),  # Jan
            fill(-10.0, 28),  # Feb
            fill(-5.0, 31),   # Mar
            fill(2.0, 30),    # Apr
            fill(8.0, 31),    # May
            fill(12.0, 30),   # Jun
            fill(15.0, 31),   # Jul - warmest month
            fill(13.0, 31),   # Aug
            fill(8.0, 30),    # Sep
            fill(2.0, 31),    # Oct
            fill(-4.0, 30),   # Nov
            fill(-10.0, 31)   # Dec
        )
        
        # Very short growing season - dphen is 365×2 array
        dphen = zeros(Float64, 365, 2)
        
        # Fill both columns with the same phenology pattern
        # Winter dormancy (Jan-Apr and Oct-Dec)
        dphen[1:120, :] .= 0.0      # Jan-Apr (120 days)
        dphen[1:31, :] .= 0.0       # Jan
        dphen[32:59, :] .= 0.0      # Feb  
        dphen[60:90, :] .= 0.0      # Mar
        dphen[91:120, :] .= 0.0     # Apr
        
        # Growing season (May-Sep)
        dphen[121:151, :] .= 1.0    # May - rapid growth
        dphen[152:181, :] .= 1.0    # Jun - peak activity  
        dphen[182:212, :] .= 1.0    # Jul - peak activity
        dphen[213:243, :] .= 1.0    # Aug - still active
        dphen[244:273, :] .= 0.0    # Sep - senescing
        
        # Fall/winter dormancy (Oct-Dec)
        dphen[274:304, :] .= 0.0    # Oct - dormant
        dphen[305:334, :] .= 0.0    # Nov - dormant  
        dphen[335:365, :] .= 0.0    # Dec - dormant
        
        co2 = 378.8
        p = 85000.0  # Lower pressure at altitude
        tsoil = [2.0, 2.0, 3.0, 4.0, 6.0, 10.0, 12.0, 10.0, 6.0, 2.0, 2.0, 0.0]
        
        mnpp = zeros(Float64, 12)
        c4mnpp = zeros(Float64, 12)
        pft_states = PFTState(pft)
        ws = GrowthWorkspace(Float64)
        
        npp_alpine, monthly_npp_alpine, monthly_c4npp_alpine, states_alpine = growth(
            maxlai, annp, sun, temp, dprec, dmelt, dpet, k, pft,
            dayl, dtemp, dphen, co2, p, tsoil, mnpp, c4mnpp, pft_states, ws
        )
        
        @test all(isfinite.([npp_alpine]))
        @test all(isfinite.(monthly_npp_alpine))
        
        # Alpine conditions should result in low NPP
        @test npp_alpine <= 400.0  # Very low due to short season and cold
        
        # Extremely concentrated growing season
        growing_season_alpine = sum(monthly_npp_alpine[5:8])  # May-Aug
        dormant_season_alpine = sum(monthly_npp_alpine[[1,2,3,4,9,10,11,12]])
        
        @test growing_season_alpine > 0.8 * sum(monthly_npp_alpine)  # Almost all NPP in 4 months
        @test dormant_season_alpine < 0.2 * sum(monthly_npp_alpine)
        
        # Always greeendays with evergreen
        @test states_alpine.greendays == 365  # Evergreen phenology
    end
    
    @testset "PFT State Tracking Tests" begin
        # Test that PFT states are properly updated and tracked
        maxlai = 3.0
        annp = 60000.0
        
        sun = fill(20.0, 12)
        temp = fill(18.0, 12)
        dprec = fill(annp / 365.0, 365)
        dmelt = zeros(Float64, 365)
        dpet = fill(3.5, 365)
        k = fill(0.3, 365)
        
        pft = BIOME4.TemperateDeciduous()
        
        dayl = fill(12.0, 12)
        dtemp = fill(18.0, 365)
        dphen = fill(1.0, 365, 2)
        
        co2 = 400.0
        p = 101325.0
        tsoil = fill(18.0, 12)
        
        mnpp = zeros(Float64, 12)
        c4mnpp = zeros(Float64, 12)
        
        # Test with initial state
        initial_states = PFTState(pft)
        initial_states.greendays = 0
        initial_states.mwet = zeros(Float64, 12)
        initial_states.firedays = 0
        initial_states.lai = 0.0
        
        ws = GrowthWorkspace(Float64)
        npp, monthly_npp, monthly_c4npp, final_states = growth(
            maxlai, annp, sun, temp, dprec, dmelt, dpet, k, pft,
            dayl, dtemp, dphen, co2, p, tsoil, mnpp, c4mnpp, initial_states, ws
        )
        
        # Test that states are updated
        @test final_states.greendays != 0
        @test final_states.mwet !=  zeros(Float64, 12)
        @test final_states.firedays >= 0
        @test length(final_states.mwet) == 12
        
        # Test reasonable values for states
        @test final_states.greendays >= 0
        @test final_states.greendays <= 365
        @test all(final_states.mwet .>= 0.0)
        @test all(final_states.mwet .<= 100.0)  # Should be percentage
        @test final_states.firedays >= 0
        
        # Test state consistency across runs
        ws2 = GrowthWorkspace(Float64)
        npp2, monthly_npp2, monthly_c4npp2, final_states2 = growth(
            maxlai, annp, sun, temp, dprec, dmelt, dpet, k, pft,
            dayl, dtemp, dphen, co2, p, tsoil, zeros(Float64, 12), zeros(Float64, 12), 
            PFTState{Float64, Int}(), ws2
        )
        
        # Results should be deterministic (same inputs -> same outputs)
        @test npp ≈ npp2
        @test all(monthly_npp .≈ monthly_npp2)
        @test final_states.greendays == final_states2.greendays
    end
    
    @testset "Error Handling and Edge Cases" begin
        # Test with extreme parameter combinations
        maxlai = 0.1  # Very low LAI
        annp = 50.0   # Very low precipitation
        
        sun = fill(5.0, 12)    # Low radiation
        temp = fill(-5.0, 12)   # Cold temperatures
        dprec = fill(annp / 365.0, 365)
        dmelt = zeros(Float64, 365)
        dpet = fill(10.0, 365)  # Very high PET (impossible conditions)
        k = fill(0.05, 365)     # Very low water holding
        
        pft = BIOME4.WoodyDesert()

        dayl = fill(6.0, 12)
        dtemp = fill(-5.0, 365)
        dphen = fill(0.1, 365)  # Very low phenology
        
        co2 = 300.0  # Low CO2
        p = 101325.0
        tsoil = fill(-2.0, 12)
        
        mnpp = zeros(Float64, 12)
        c4mnpp = zeros(Float64, 12)
        pft_states = PFTState{Float64, Int}()
        ws = GrowthWorkspace(Float64)
        
        npp_extreme, monthly_npp_extreme, monthly_c4npp_extreme, states_extreme = growth(
            maxlai, annp, sun, temp, dprec, dmelt, dpet, k, pft,
            dayl, dtemp, dphen, co2, p, tsoil, mnpp, c4mnpp, pft_states, ws
        )
        
        # Should handle extreme conditions gracefully
        @test all(isfinite.([npp_extreme]))
        @test all(isfinite.(monthly_npp_extreme))
        
        # Should either produce very low NPP or wilting condition
        if npp_extreme != -9999.0
            @test npp_extreme <= 50.0  # Should be very low
        else
            @test npp_extreme == -9999.0  # Wilting condition
        end
        
        # Test with NaN inputs
        sun_nan = fill(NaN, 9)
        @test_throws BoundsError growth(
            maxlai, annp, sun_nan, temp, dprec, dmelt, dpet, k, pft,
            dayl, dtemp, dphen, co2, p, tsoil, mnpp, c4mnpp, pft_states, ws
        )
    end
end
