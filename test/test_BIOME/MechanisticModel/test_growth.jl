using Test

include("../../../src/abstractmodel.jl")
include("../../../src/pfts.jl")
include("../../../src/models/MechanisticModel/pfts.jl")

include("../../../src/models/MechanisticModel/growth.jl")
include("../../../src/models/MechanisticModel/constants.jl")
using .Constants: T, P0, CP, T0, G, M, R0,
    QEFFC3, DRESPC3, DRESPC4, ABS1, TETA, SLO2, JTOE, OPTRATIO,
    KO25, KC25, TAO25, CMASS, KCQ10, KOQ10, TAOQ10,
    TWIGLOSS, TUNE, LEAFRESP,
    MAXTEMP,
    LN, Y, M10, P1, STEMCARBON,
    E0, TREF, TEMP0,
    A, ES, A1, B3, B
include("../../../src/models/MechanisticModel/utils.jl")

include("../../../src/models/MechanisticModel/growth_subroutines/c4photo.jl")
include("../../../src/models/MechanisticModel/growth_subroutines/calcphi.jl")
include("../../../src/models/MechanisticModel/growth_subroutines/daily.jl")
include("../../../src/models/MechanisticModel/growth_subroutines/fire.jl")
include("../../../src/models/MechanisticModel/growth_subroutines/hetresp.jl")
include("../../../src/models/MechanisticModel/growth_subroutines/hydrology.jl")
include("../../../src/models/MechanisticModel/growth_subroutines/isotope.jl")
include("../../../src/models/MechanisticModel/growth_subroutines/photosynthesis.jl")
include("../../../src/models/MechanisticModel/growth_subroutines/respiration.jl")

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
        c3_pft = TemperateDeciduous(40.0, 800.0, 10.0)
        set_characteristic(c3_pft, :c4, false)
        set_characteristic(c3_pft, :optratioa, 0.8)
        
        # Test without override
        c4, optratio = determine_c4_and_optratio(c3_pft, 0.8, nothing)
        @test c4 == false
        @test optratio ≈ 0.8
        
        # Test with C4 override
        c4_override, optratio_override = determine_c4_and_optratio(c3_pft, 0.8, true)
        @test c4_override == true
        @test optratio_override ≈ 0.4
        
        # Create a C4 PFT
        c4_pft = C4TropicalGrass(10.0, 800.0, 24.0)
        set_characteristic(c4_pft, :c4, true)
        
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
        pft = TemperateDeciduous(40.0, 800.0, 10.0)
        set_characteristic(pft, :optratioa, 0.8)
        set_characteristic(pft, :kk, 0.5)
        set_characteristic(pft, :phenological_type, 2)
        set_characteristic(pft, :max_min_canopy_conductance, 0.01)
        set_characteristic(pft, :root_fraction_top_soil, 0.9)
        set_characteristic(pft, :leaf_longevity, 1.0)
        set_characteristic(pft, :sapwood_respiration, 0.1)
        set_characteristic(pft, :Emax, 5.0)
        set_characteristic(pft, :c4, false)
        set_characteristic(pft, :grass, false)
        
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
            fill(0.0, 90),   # Winter dormancy
            fill(1.0, 185),  # Growing season
            fill(0.0, 90)    # Fall dormancy
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
        
        # Run growth function
        npp, monthly_npp, monthly_c4npp = growth(
            maxlai, annp, sun, temp, dprec, dmelt, dpet, k, pft,
            dayl, dtemp, dphen, co2, p, tsoil, mnpp, c4mnpp
        )
        
        # Test basic outputs
        @test typeof(npp) == Float64
        @test length(monthly_npp) == 12
        @test length(monthly_c4npp) == 12
        @test all(isfinite.([npp]))
        @test all(isfinite.(monthly_npp))
        @test all(isfinite.(monthly_c4npp))
        
        # Test that NPP is reasonable for temperate forest
        @test npp >= 0.0  # Should be positive for productive ecosystem
        @test npp <= 2000.0  # Reasonable upper bound for temperate forest
        
        # Test that monthly NPP sums approximately to annual NPP
        monthly_sum = sum(monthly_npp)
        @test abs(monthly_sum - npp) < 0.1 * npp  # Within 10%
        
        # Test that growing season has higher NPP than dormant season
        growing_season_npp = sum(monthly_npp[4:9])  # Apr-Sep
        dormant_season_npp = sum(monthly_npp[[1,2,3,10,11,12]])  # Oct-Mar
        @test growing_season_npp > dormant_season_npp
        
        # For C3 plant, C4 NPP should be mostly zero
        @test sum(monthly_c4npp) <= 0.1 * sum(monthly_npp)
    end
    
    @testset "C4 Tropical Grass Test" begin
        # Test with C4 tropical grass
        maxlai = 3.0
        annp = 1200.0
        
        # Tropical conditions - warm year-round, wet/dry seasons
        sun = [25.0, 26.0, 27.0, 26.0, 24.0, 22.0, 23.0, 25.0, 26.0, 27.0, 26.0, 25.0]
        temp = [26.0, 27.0, 28.0, 29.0, 28.0, 27.0, 26.0, 26.0, 27.0, 28.0, 27.0, 26.0]
        
        # Seasonal precipitation pattern
        dprec_wet = fill(5.0, 150)   # Wet season
        dprec_dry = fill(0.5, 215)   # Dry season
        dprec = vcat(dprec_wet, dprec_dry)
        
        dmelt = zeros(Float64, 365)
        dpet = fill(4.0, 365)  # High evapotranspiration
        k = fill(0.2, 365)     # Sandy soil
        
        # Create C4 tropical grass PFT
        pft = C4TropicalGrass(10.0, 800.0, 24.0)
        set_characteristic(pft, :c4, true)
        set_characteristic(pft, :grass, true)
        set_characteristic(pft, :optratioa, 0.8)
        set_characteristic(pft, :kk, 0.7)
        set_characteristic(pft, :phenological_type, 1)  # Evergreen
        set_characteristic(pft, :max_min_canopy_conductance, 0.02)
        set_characteristic(pft, :root_fraction_top_soil, 0.8)
        set_characteristic(pft, :leaf_longevity, 1.5)
        set_characteristic(pft, :sapwood_respiration, 0.05)
        set_characteristic(pft, :Emax, 6.0)
        
        dayl = fill(12.0, 12)  # Constant daylength near equator
        dtemp = fill(27.0, 365)
        dphen = fill(1.0, 365)  # Always active
        
        co2 = 400.0
        p = 101325.0
        tsoil = fill(27.0, 12)
        
        mnpp = zeros(Float64, 12)
        c4mnpp = zeros(Float64, 12)
        
        npp_c4, monthly_npp_c4, monthly_c4npp_c4 = growth(
            maxlai, annp, sun, temp, dprec, dmelt, dpet, k, pft,
            dayl, dtemp, dphen, co2, p, tsoil, mnpp, c4mnpp
        )
        
        @test npp_c4 >= 0.0
        @test all(isfinite.([npp_c4]))
        @test all(isfinite.(monthly_npp_c4))
        @test all(isfinite.(monthly_c4npp_c4))
        
        # For pure C4 grass, most NPP should be C4
        total_c4_npp = sum(monthly_c4npp_c4)
        @test total_c4_npp > 0.5 * npp_c4  # At least 50% should be C4
        
        # C4 plants should be more productive in hot conditions
        @test npp_c4 > 0.0
    end
    
    @testset "Extreme Climate Conditions" begin
        # Test with very cold conditions
        maxlai = 2.0
        annp = 300.0
        
        sun = [2.0, 4.0, 8.0, 12.0, 16.0, 18.0, 17.0, 14.0, 10.0, 6.0, 3.0, 1.0]
        temp = [-25.0, -20.0, -10.0, -2.0, 5.0, 12.0, 15.0, 10.0, 3.0, -5.0, -15.0, -22.0]
        
        dprec = fill(annp / 365.0, 365)
        dmelt = zeros(Float64, 365)
        dpet = fill(1.0, 365)  # Low PET in cold conditions
        k = fill(0.4, 365)
        
        # Create boreal evergreen PFT
        pft = BorealEvergreen(50.0, 500.0, -3.0)
        set_characteristic(pft, :c4, false)
        set_characteristic(pft, :grass, false)
        set_characteristic(pft, :optratioa, 0.7)
        set_characteristic(pft, :kk, 0.6)
        set_characteristic(pft, :phenological_type, 1)  # Evergreen
        set_characteristic(pft, :max_min_canopy_conductance, 0.005)
        set_characteristic(pft, :root_fraction_top_soil, 0.7)
        set_characteristic(pft, :leaf_longevity, 3.0)
        set_characteristic(pft, :sapwood_respiration, 0.08)
        set_characteristic(pft, :Emax, 3.0)
        
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
        
        npp_cold, monthly_npp_cold, monthly_c4npp_cold = growth(
            maxlai, annp, sun, temp, dprec, dmelt, dpet, k, pft,
            dayl, dtemp, dphen, co2, p, tsoil, mnpp, c4mnpp
        )
        
        @test all(isfinite.([npp_cold]))
        @test all(isfinite.(monthly_npp_cold))
        
        # Cold conditions should result in lower NPP
        @test npp_cold >= 0.0
        @test npp_cold <= 1000.0  # Should be limited by cold temperatures
        
        # Summer months should have higher NPP than winter
        summer_npp = sum(monthly_npp_cold[5:8])
        winter_npp = sum(monthly_npp_cold[[1,2,11,12]])
        @test summer_npp >= winter_npp
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
        pft = WoodyDesert(15.0, 200.0, 25.0)
        set_characteristic(pft, :c4, false)
        set_characteristic(pft, :grass, false)
        set_characteristic(pft, :optratioa, 0.9)
        set_characteristic(pft, :kk, 0.3)
        set_characteristic(pft, :phenological_type, 3)  # Drought deciduous
        set_characteristic(pft, :max_min_canopy_conductance, 0.001)
        set_characteristic(pft, :root_fraction_top_soil, 0.5)
        set_characteristic(pft, :leaf_longevity, 0.5)
        set_characteristic(pft, :sapwood_respiration, 0.12)
        set_characteristic(pft, :Emax, 2.0)
        
        dayl = [10.0, 11.0, 12.0, 13.0, 14.0, 14.5, 14.0, 13.0, 12.0, 11.0, 10.0, 9.5]
        dtemp = fill(25.0, 365)
        dphen = fill(0.3, 365)  # Low phenology due to drought
        
        co2 = 400.0
        p = 101325.0
        tsoil = fill(25.0, 12)
        
        mnpp = zeros(Float64, 12)
        c4mnpp = zeros(Float64, 12)
        
        npp_dry, monthly_npp_dry, monthly_c4npp_dry = growth(
            maxlai, annp, sun, temp, dprec, dmelt, dpet, k, pft,
            dayl, dtemp, dphen, co2, p, tsoil, mnpp, c4mnpp
        )
        
        # In extreme drought, NPP might be negative (wilting)
        @test all(isfinite.([npp_dry]))
        @test all(isfinite.(monthly_npp_dry))
        
        # Wilting condition should result in -9999 NPP
        if npp_dry == -9999.0
            @test npp_dry == -9999.0  # Wilting condition
        else
            @test npp_dry >= 0.0
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
        
        pft = TemperateDeciduous(40.0, 800.0, 10.0)
        set_characteristic(pft, :c4, false)
        set_characteristic(pft, :grass, false)
        set_characteristic(pft, :optratioa, 0.8)
        set_characteristic(pft, :kk, 0.5)
        set_characteristic(pft, :phenological_type, 2)
        set_characteristic(pft, :max_min_canopy_conductance, 0.01)
        set_characteristic(pft, :root_fraction_top_soil, 0.9)
        set_characteristic(pft, :leaf_longevity, 1.0)
        set_characteristic(pft, :sapwood_respiration, 1)
        set_characteristic(pft, :Emax, 5.0)
        
        dayl = fill(12.0, 12)
        dtemp = fill(15.0, 365)
        dphen = fill(1.0, 365)
        
        co2 = 400.0
        p = 101325.0
        tsoil = fill(15.0, 12)
        
        mnpp = zeros(Float64, 12)
        c4mnpp = zeros(Float64, 12)
        
        npp_zero_lai, monthly_npp_zero, monthly_c4npp_zero = growth(
            maxlai, annp, sun, temp, dprec, dmelt, dpet, k, pft,
            dayl, dtemp, dphen, co2, p, tsoil, mnpp, c4mnpp
        )
        
        @test all(isfinite.([npp_zero_lai]))
        @test all(isfinite.(monthly_npp_zero))
        
        # With zero LAI, NPP should be very low or zero
        @test npp_zero_lai <= 10.0  # Should be very low
        @test all(monthly_npp_zero .<= 1.0)  # Monthly values should be very low
    end
    
    @testset "Type Consistency Tests" begin
        # Test with Float32 inputs
        maxlai = Float32(4.0)
        annp = Float32(600.0)
        
        sun = Float32[15.0, 18.0, 22.0, 25.0, 28.0, 30.0, 29.0, 26.0, 22.0, 18.0, 14.0, 12.0]
        temp = Float32[5.0, 8.0, 12.0, 16.0, 20.0, 24.0, 26.0, 24.0, 20.0, 15.0, 10.0, 6.0]
        
        dprec = fill(Float32(annp / 365.0), 365)
        dmelt = zeros(Float32, 365)
        dpet = fill(Float32(3.0), 365)
        k = fill(Float32(0.3), 365)
        
        pft = TemperateDeciduous(Float32(40.0), Float32(800.0), Float32(10.0))
        set_characteristic(pft, :c4, false)
        set_characteristic(pft, :grass, false)
        set_characteristic(pft, :optratioa, Float32(0.8))
        set_characteristic(pft, :kk, Float32(0.5))
        set_characteristic(pft, :phenological_type, 2)
        set_characteristic(pft, :max_min_canopy_conductance, Float32(0.01))
        set_characteristic(pft, :root_fraction_top_soil, Float32(0.9))
        set_characteristic(pft, :leaf_longevity, Float32(1.0))
        set_characteristic(pft, :sapwood_respiration, Float32(0.1))
        set_characteristic(pft, :Emax, Float32(5.0))
        
        dayl = Float32[10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 14.5, 13.5, 12.5, 11.5, 10.5, 9.5]
        dtemp = fill(Float32(15.0), 365)
        dphen = fill(Float32(1.0), 365)
        
        co2 = Float32(400.0)
        p = Float32(101325.0)
        tsoil = Float32[8.0, 10.0, 13.0, 17.0, 21.0, 25.0, 27.0, 25.0, 21.0, 16.0, 12.0, 9.0]
        
        mnpp = zeros(Float32, 12)
        c4mnpp = zeros(Float32, 12)
        
        npp_f32, monthly_npp_f32, monthly_c4npp_f32 = growth(
            maxlai, annp, sun, temp, dprec, dmelt, dpet, k, pft,
            dayl, dtemp, dphen, co2, p, tsoil, mnpp, c4mnpp
        )
        
        # Check type preservation
        @test typeof(npp_f32) == Float32
        @test eltype(monthly_npp_f32) == Float32
        @test eltype(monthly_c4npp_f32) == Float32
        
        # Check values are reasonable
        @test all(isfinite.([npp_f32]))
        @test all(isfinite.(monthly_npp_f32))
        @test all(isfinite.(monthly_c4npp_f32))
        @test npp_f32 >= Float32(0.0)
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
        dphen_correct = fill(1.0, 365)
        tsoil_correct = fill(15.0, 12)
        
        pft = TemperateDeciduous(40.0, 800.0, 10.0)
        set_characteristic(pft, :c4, false)
        set_characteristic(pft, :grass, false)
        set_characteristic(pft, :optratioa, 0.8)
        set_characteristic(pft, :kk, 0.5)
        set_characteristic(pft, :phenological_type, 2)
        set_characteristic(pft, :max_min_canopy_conductance, 0.01)
        set_characteristic(pft, :root_fraction_top_soil, 0.9)
        set_characteristic(pft, :leaf_longevity, 1.0)
        set_characteristic(pft, :sapwood_respiration, 1)
        set_characteristic(pft, :Emax, 5.0)
        
        co2 = 400.0
        p = 101325.0
        
        mnpp = zeros(Float64, 12)
        c4mnpp = zeros(Float64, 12)
        
        # This should work
        npp, monthly_npp, monthly_c4npp = growth(
            maxlai, annp, sun_correct, temp_correct, dprec_correct, dmelt_correct, 
            dpet_correct, k_correct, pft, dayl_correct, dtemp_correct, dphen_correct, 
            co2, p, tsoil_correct, mnpp, c4mnpp
        )
        
        @test typeof(npp) == Float64
        @test length(monthly_npp) == 12
        @test length(monthly_c4npp) == 12
        
        # Test with wrong dimensions should fail
        sun_wrong = fill(20.0, 10)  # Wrong size
        @test_throws BoundsError growth(
            maxlai, annp, sun_wrong, temp_correct, dprec_correct, dmelt_correct, 
            dpet_correct, k_correct, pft, dayl_correct, dtemp_correct, dphen_correct, 
            co2, p, tsoil_correct, mnpp, c4mnpp
        )
        
        dprec_wrong = fill(2.0, 300)  # Wrong size
        @test_throws BoundsError growth(
            maxlai, annp, sun_correct, temp_correct, dprec_wrong, dmelt_correct, 
            dpet_correct, k_correct, pft, dayl_correct, dtemp_correct, dphen_correct, 
            co2, p, tsoil_correct, mnpp, c4mnpp
        )
    end
    
    @testset "Compare C3 C4 NPP Function Tests" begin
        # Test the compare_c3_c4_npp function separately
        
        # Create a mixed C3C4 PFT
        pft = C3C4TemperateGrass(20.0, 400.0, 18.0)
        set_characteristic(pft, :name, "C3C4WoodyDesert")
        
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
        if c4_better_months >= 3
            @test sum(c4month) >= 2  # Should use C4 for some months
        end
        
        @test c4pct >= 0.0 && c4pct <= 1.0  # Should be a valid percentage
        @test all(isfinite.(result_mnpp))
        @test isfinite(result_nppsum)
        @test isfinite(annc4npp)
        
        # Test with pure C4 tropical grass
        pft_c4 = C4TropicalGrass(10.0, 800.0, 24.0)
        set_characteristic(pft_c4, :name, "C4TropicalGrass")
        
        result_nppsum_c4, c4pct_c4, c4month_c4, result_mnpp_c4, annc4npp_c4, _, _, _, _, _ = compare_c3_c4_npp(
            pft_c4, mnpp, c4mnpp, monthlyfpar, monthlyparr, monthlyapar, CCratio, isoresp,
            c4fpar, c4parr, c4apar, c4ccratio, c4leafresp, nppsum, true
        )
        
        # All months should be C4 for pure C4 grass
        @test all(c4month_c4)
        @test c4pct_c4 > 0.9  # Should be mostly C4
    end
end