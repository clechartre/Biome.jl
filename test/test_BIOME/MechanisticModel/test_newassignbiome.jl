
using Test

@testset "New Assign Biome Tests" begin
    
    @testset "Tropical Evergreen Assignment Tests" begin
        # Create test PFTs and biome classification
        biome_pfts = PFTClassification()
        tropical_evergreen = TropicalEvergreen()
        
        # Create PFT states dictionary
        pft_states = Dict{AbstractPFT, PFTState{Float64, Int}}()
        pft_states[tropical_evergreen] = PFTState{Float64, Int}()
        
        # Test with high NPP - should return TropicalEvergreenForest
        pft_states[tropical_evergreen].npp = 500.0
        result = assign_biome(tropical_evergreen; PFTStates=pft_states)
        @test isa(result, TropicalEvergreenForest)
        
        # Test with low NPP - should return Desert
        pft_states[tropical_evergreen].npp = 50.0
        result_low = assign_biome(tropical_evergreen; PFTStates=pft_states)
        @test isa(result_low, Desert)
    end
    
    @testset "Tropical Drought Deciduous Assignment Tests" begin
        biome_pfts = PFTClassification()
        tropical_drought = TropicalDroughtDeciduous()
        
        # Create PFT states dictionary
        pft_states = Dict{AbstractPFT, PFTState{Float64, Int}}()
        pft_states[tropical_drought] = PFTState{Float64, Int}()
        
        # Test with high NPP and long green season
        pft_states[tropical_drought].npp = 400.0
        pft_states[tropical_drought].greendays = 320
        result_long = assign_biome(tropical_drought; PFTStates=pft_states)
        @test isa(result_long, TropicalEvergreenForest)
        
        # Test with medium green season
        pft_states[tropical_drought].greendays = 280
        result_medium = assign_biome(tropical_drought; PFTStates=pft_states)
        @test isa(result_medium, TropicalSemiDeciduousForest)
        
        # Test with short green season
        pft_states[tropical_drought].greendays = 200
        result_short = assign_biome(tropical_drought; PFTStates=pft_states)
        @test isa(result_short, TropicalDeciduousForestWoodland)
        
        # Test with low NPP
        pft_states[tropical_drought].npp = 80.0
        result_low_npp = assign_biome(tropical_drought; PFTStates=pft_states)
        @test isa(result_low_npp, Desert)
    end
    
    @testset "Temperate Broadleaved Evergreen Assignment Tests" begin
        temperate_be = TemperateBroadleavedEvergreen()
        
        # Create PFT states dictionary
        pft_states = Dict{AbstractPFT, PFTState{Float64, Int}}()
        pft_states[temperate_be] = PFTState{Float64, Int}()
        
        # Test with high NPP
        pft_states[temperate_be].npp = 300.0
        result_high = assign_biome(temperate_be; PFTStates=pft_states)
        @test isa(result_high, WarmMixedForest)
        
        # Test with low NPP
        pft_states[temperate_be].npp = 80.0
        result_low = assign_biome(temperate_be; PFTStates=pft_states)
        @test isa(result_low, Desert)
    end
    
    @testset "Temperate Deciduous Assignment Tests" begin
        biome_pfts = PFTClassification()
        temperate_dec = TemperateDeciduous()
        
        # Create PFT states dictionary for all PFTs
        pft_states = Dict{AbstractPFT, PFTState{Float64, Int}}()
        for pft in biome_pfts.pft_list
            pft_states[pft] = PFTState{Float64, Int}()
        end
        pft_states[temperate_dec] = PFTState{Float64, Int}()
        
        # Test with high NPP and boreal evergreen present
        pft_states[temperate_dec].npp = 250.0
        
        # Set boreal evergreen as present
        boreal_evergreen = first(pft for pft in biome_pfts.pft_list if get_characteristic(pft, :name) == "BorealEvergreen")
        pft_states[boreal_evergreen].present = true
        
        # Test cold conditions
        result_cold = assign_biome(temperate_dec; gdd5=1200.0, tcm=-20.0, BIOME4PFTS=biome_pfts, PFTStates=pft_states)
        @test isa(result_cold, ColdMixedForest)
        
        # Test warmer conditions
        result_warm = assign_biome(temperate_dec; gdd5=1200.0, tcm=-10.0, BIOME4PFTS=biome_pfts, PFTStates=pft_states)
        @test isa(result_warm, CoolMixedForest)
        
        # Test with temperate broadleaved evergreen present and high GDD5
        temperate_be = first(pft for pft in biome_pfts.pft_list if get_characteristic(pft, :name) == "TemperateBroadleavedEvergreen")
        pft_states[temperate_be].present = true
        pft_states[boreal_evergreen].present = false
        result_tbe = assign_biome(temperate_dec; gdd5=3500.0, tcm=5.0, BIOME4PFTS=biome_pfts, PFTStates=pft_states)
        @test isa(result_tbe, WarmMixedForest)
        
        # Test fallback to temperate deciduous forest
        pft_states[temperate_be].present = false
        pft_states[boreal_evergreen].present = false
        result_fallback = assign_biome(temperate_dec; gdd5=2000.0, tcm=0.0, BIOME4PFTS=biome_pfts, PFTStates=pft_states)
        @test isa(result_fallback, TemperateDeciduousForest)
        
        # Test with low NPP
        pft_states[temperate_dec].npp = 70.0
        result_low_npp = assign_biome(temperate_dec; gdd5=2000.0, tcm=0.0, BIOME4PFTS=biome_pfts, PFTStates=pft_states)
        @test isa(result_low_npp, Desert)
    end
    
    @testset "Cool Conifer Assignment Tests" begin
        biome_pfts = PFTClassification()
        cool_conifer = CoolConifer()
        
        # Create PFT states dictionary
        pft_states = Dict{AbstractPFT, PFTState{Float64, Int}}()
        for pft in biome_pfts.pft_list
            pft_states[pft] = PFTState{Float64, Int}()
        end
        pft_states[cool_conifer] = PFTState{Float64, Int}()
        
        # Test with high NPP and temperate broadleaved evergreen present
        pft_states[cool_conifer].npp = 200.0
        temperate_be = first(pft for pft in biome_pfts.pft_list if get_characteristic(pft, :name) == "TemperateBroadleavedEvergreen")
        pft_states[temperate_be].present = true
        
        result_tbe = assign_biome(cool_conifer; subpft=Default(), BIOME4PFTS=biome_pfts, PFTStates=pft_states)
        @test isa(result_tbe, WarmMixedForest)
        
        # Test with temperate deciduous subdominant
        pft_states[temperate_be].present = false
        temperate_dec = TemperateDeciduous()
        pft_states[temperate_dec] = PFTState{Float64, Int}()
        result_temp_dec = assign_biome(cool_conifer; subpft=temperate_dec, BIOME4PFTS=biome_pfts, PFTStates=pft_states)
        @test isa(result_temp_dec, TemperateConiferForest)
        
        # Test with boreal deciduous subdominant
        boreal_dec = BorealDeciduous()
        pft_states[boreal_dec] = PFTState{Float64, Int}()
        result_boreal_dec = assign_biome(cool_conifer; subpft=boreal_dec, BIOME4PFTS=biome_pfts, PFTStates=pft_states)
        @test isa(result_boreal_dec, ColdMixedForest)
        
        # Test fallback
        result_fallback = assign_biome(cool_conifer; subpft=Default(), BIOME4PFTS=biome_pfts, PFTStates=pft_states)
        @test isa(result_fallback, TemperateConiferForest)
        
        # Test with low NPP
        pft_states[cool_conifer].npp = 60.0
        result_low_npp = assign_biome(cool_conifer; subpft=Default(), BIOME4PFTS=biome_pfts, PFTStates=pft_states)
        @test isa(result_low_npp, Desert)
    end
    
    @testset "Boreal Evergreen Assignment Tests" begin
        biome_pfts = PFTClassification()
        boreal_evergreen = BorealEvergreen()
        
        # Create PFT states dictionary
        pft_states = Dict{AbstractPFT, PFTState{Float64, Int}}()
        for pft in biome_pfts.pft_list
            pft_states[pft] = PFTState{Float64, Int}()
        end
        pft_states[boreal_evergreen] = PFTState{Float64, Int}()
        
        # Test warm conditions with temperate deciduous present
        temperate_dec = first(pft for pft in biome_pfts.pft_list if get_characteristic(pft, :name) == "TemperateDeciduous")
        pft_states[temperate_dec].present = true
        
        result_warm = assign_biome(boreal_evergreen; gdd5=1200.0, tcm=-10.0, BIOME4PFTS=biome_pfts, PFTStates=pft_states)
        @test isa(result_warm, CoolMixedForest)
        
        # Test warm conditions without temperate deciduous
        pft_states[temperate_dec].present = false
        result_warm_no_td = assign_biome(boreal_evergreen; gdd5=1200.0, tcm=-10.0, BIOME4PFTS=biome_pfts, PFTStates=pft_states)
        @test isa(result_warm_no_td, CoolConiferForest)
        
        # Test cold conditions with temperate deciduous present
        pft_states[temperate_dec].present = true
        result_cold = assign_biome(boreal_evergreen; gdd5=600.0, tcm=-25.0, BIOME4PFTS=biome_pfts, PFTStates=pft_states)
        @test isa(result_cold, ColdMixedForest)
        
        # Test cold conditions without temperate deciduous
        pft_states[temperate_dec].present = false
        result_cold_no_td = assign_biome(boreal_evergreen; gdd5=600.0, tcm=-25.0, BIOME4PFTS=biome_pfts, PFTStates=pft_states)
        @test isa(result_cold_no_td, EvergreenTaigaMontaneForest)
    end
    
    @testset "Boreal Deciduous Assignment Tests" begin
        boreal_deciduous = BorealDeciduous()
        
        # Create PFT states dictionary
        pft_states = Dict{AbstractPFT, PFTState{Float64, Int}}()
        pft_states[boreal_deciduous] = PFTState{Float64, Int}()
        
        # Test with temperate deciduous subdominant
        temperate_dec = TemperateDeciduous()
        pft_states[temperate_dec] = PFTState{Float64, Int}()
        result_temp_dec = assign_biome(boreal_deciduous; subpft=temperate_dec, gdd5=1000.0, tcm=-8.0)
        @test isa(result_temp_dec, TemperateDeciduousForest)
        
        # Test with cool conifer subdominant
        cool_conifer = CoolConifer()
        pft_states[cool_conifer] = PFTState{Float64, Int}()
        result_cool_con = assign_biome(boreal_deciduous; subpft=cool_conifer, gdd5=1000.0, tcm=-8.0)
        @test isa(result_cool_con, CoolConiferForest)
        
        # Test warm conditions
        result_warm = assign_biome(boreal_deciduous; subpft=Default(), gdd5=1200.0, tcm=-10.0)
        @test isa(result_warm, CoolConiferForest)
        
        # Test cold conditions
        result_cold = assign_biome(boreal_deciduous; subpft=Default(), gdd5=600.0, tcm=-25.0)
        @test isa(result_cold, DeciduousTaigaMontaneForest)
    end
    
    @testset "Woody Desert Assignment Tests" begin
        woody_desert = WoodyDesert()
        
        # Create PFT states dictionary
        pft_states = Dict{AbstractPFT, PFTState{Float64, Int}}()
        pft_states[woody_desert] = PFTState{Float64, Int}()
        
        subdominant = Default()
        pft_states[subdominant] = PFTState{Float64, Int}()
        
        # Test with high NPP and high LAI subdominant
        pft_states[woody_desert].npp = 150.0
        pft_states[subdominant].lai = 2.0
        
        # Test warm conditions (tmin >= 0)
        result_warm = assign_biome(woody_desert; subpft=subdominant, tmin=5.0, PFTStates=pft_states)
        @test isa(result_warm, TropicalXerophyticShrubland)
        
        # Test cold conditions (tmin < 0)
        result_cold = assign_biome(woody_desert; subpft=subdominant, tmin=-10.0, PFTStates=pft_states)
        @test isa(result_cold, TemperateXerophyticShrubland)
        
        # Test with low LAI subdominant
        pft_states[subdominant].lai = 0.5
        result_low_lai = assign_biome(woody_desert; subpft=subdominant, tmin=5.0, PFTStates=pft_states)
        @test isa(result_low_lai, Desert)
        
        # Test with low NPP
        pft_states[woody_desert].npp = 80.0
        result_low_npp = assign_biome(woody_desert; subpft=subdominant, tmin=5.0, PFTStates=pft_states)
        @test isa(result_low_npp, Desert)
    end
    
    @testset "Grass PFT Assignment Tests" begin
        # Test C3C4 Temperate Grass
        temperate_grass = C3C4TemperateGrass()
        
        # Create PFT states dictionary
        pft_states = Dict{AbstractPFT, PFTState{Float64, Int}}()
        pft_states[temperate_grass] = PFTState{Float64, Int}()
        
        # Test with low NPP and suitable subdominant
        pft_states[temperate_grass].npp = 80.0
        subdominant = Default()
        pft_states[subdominant] = PFTState{Float64, Int}()
        result_low_npp = assign_biome(temperate_grass; subpft=subdominant, gdd0=600.0, PFTStates=pft_states)
        @test isa(result_low_npp, Desert)
        
        # Test with boreal subdominant
        boreal_evergreen = BorealEvergreen()
        pft_states[boreal_evergreen] = PFTState{Float64, Int}()
        result_boreal = assign_biome(temperate_grass; subpft=boreal_evergreen, gdd0=600.0, PFTStates=pft_states)
        @test isa(result_boreal, SteppeTundra)
        
        # Test with sufficient NPP and high GDD0
        pft_states[temperate_grass].npp = 150.0
        result_high_gdd = assign_biome(temperate_grass; subpft=Default(), gdd0=1000.0, PFTStates=pft_states)
        @test isa(result_high_gdd, TemperateGrassland)
        
        # Test with sufficient NPP and low GDD0
        result_low_gdd = assign_biome(temperate_grass; subpft=Default(), gdd0=600.0, PFTStates=pft_states)
        @test isa(result_low_gdd, SteppeTundra)
        
        # Test C4 Tropical Grass
        tropical_grass = C4TropicalGrass()
        pft_states[tropical_grass] = PFTState{Float64, Int}()
        
        # Test with high NPP
        pft_states[tropical_grass].npp = 200.0
        result_tropical = assign_biome(tropical_grass; PFTStates=pft_states)
        @test isa(result_tropical, TropicalGrassland)
        
        # Test with low NPP
        pft_states[tropical_grass].npp = 80.0
        result_tropical_low = assign_biome(tropical_grass; PFTStates=pft_states)
        @test isa(result_tropical_low, Desert)
    end
    
    @testset "Tundra PFT Assignment Tests" begin
        # Test Lichen Forb
        lichen_forb = LichenForb()
        result_lichen = assign_biome(lichen_forb)
        @test isa(result_lichen, Barren)
        
        # Test Tundra Shrubs
        tundra_shrubs = TundraShrubs()
        
        # Test very low GDD0
        result_very_cold = assign_biome(tundra_shrubs; gdd0=150.0)
        @test isa(result_very_cold, CushionForbsLichenMoss)
        
        # Test medium GDD0
        result_medium = assign_biome(tundra_shrubs; gdd0=350.0)
        @test isa(result_medium, ProstateShrubTundra)
        
        # Test higher GDD0
        result_higher = assign_biome(tundra_shrubs; gdd0=600.0)
        @test isa(result_higher, DwarfShrubTundra)
        
        # Test Cold Herbaceous
        cold_herbaceous = ColdHerbaceous()
        result_cold_herb = assign_biome(cold_herbaceous)
        @test isa(result_cold_herb, SteppeTundra)
    end
    
    @testset "Default and None PFT Assignment Tests" begin
        # Test Default PFT with different woody dominants
        default_pft = Default()
        
        # Create PFT states dictionary
        pft_states = Dict{AbstractPFT, PFTState{Float64, Int}}()
        pft_states[default_pft] = PFTState{Float64, Int}()
        
        # Test with tropical woody dominant and high LAI
        tropical_evergreen = TropicalEvergreen()
        pft_states[tropical_evergreen] = PFTState{Float64, Int}()
        pft_states[tropical_evergreen].lai = 5.0
        result_tropical_high_lai = assign_biome(default_pft; wdom=tropical_evergreen, PFTStates=pft_states)
        @test isa(result_tropical_high_lai, TropicalSavanna)
        
        # Test with tropical woody dominant and low LAI
        pft_states[tropical_evergreen].lai = 2.0
        result_tropical_low_lai = assign_biome(default_pft; wdom=tropical_evergreen, PFTStates=pft_states)
        @test isa(result_tropical_low_lai, TropicalXerophyticShrubland)
        
        # Test with temperate broadleaved evergreen
        temperate_be = TemperateBroadleavedEvergreen()
        pft_states[temperate_be] = PFTState{Float64, Int}()
        result_tbe = assign_biome(default_pft; wdom=temperate_be, PFTStates=pft_states)
        @test isa(result_tbe, TemperateSclerophyllWoodland)
        
        # Test with temperate deciduous
        temperate_dec = TemperateDeciduous()
        pft_states[temperate_dec] = PFTState{Float64, Int}()
        result_td = assign_biome(default_pft; wdom=temperate_dec, PFTStates=pft_states)
        @test isa(result_td, TemperateBroadleavedSavanna)
        
        # Test with cool conifer
        cool_conifer = CoolConifer()
        pft_states[cool_conifer] = PFTState{Float64, Int}()
        result_cc = assign_biome(default_pft; wdom=cool_conifer, PFTStates=pft_states)
        @test isa(result_cc, OpenConiferWoodland)
        
        # Test with boreal evergreen
        boreal_evergreen = BorealEvergreen()
        pft_states[boreal_evergreen] = PFTState{Float64, Int}()
        result_be = assign_biome(default_pft; wdom=boreal_evergreen, PFTStates=pft_states)
        @test isa(result_be, BorealParkland)
        
        # Test with no woody dominant
        result_no_woody = assign_biome(default_pft; wdom=Default(), PFTStates=pft_states)
        @test isa(result_no_woody, Barren)
        
        # Test None PFT
        none_pft = None()
        result_none = assign_biome(none_pft)
        @test isa(result_none, Barren)
    end
    
    @testset "Type Consistency Tests" begin
        tropical_evergreen = TropicalEvergreen()
        pft_states = Dict{AbstractPFT, PFTState{Float64, Int}}()
        pft_states[tropical_evergreen] = PFTState{Float64, Int}()
        pft_states[tropical_evergreen].npp = 300.0
        
        # Test with Float32 parameters
        result_f32 = assign_biome(tropical_evergreen; PFTStates=pft_states)
        @test isa(result_f32, AbstractBiome)
        @test isa(result_f32, TropicalEvergreenForest)
        
        # Test with Float64 parameters (default)
        result_f64 = assign_biome(tropical_evergreen; PFTStates=pft_states)
        @test isa(result_f64, AbstractBiome)
        @test isa(result_f64, TropicalEvergreenForest)
        
        # Results should be the same type of biome regardless of input numeric type
        @test typeof(result_f32) == typeof(result_f64)
    end
    
    @testset "Threshold Boundary Tests" begin
        biome_pfts = PFTClassification()
        
        # Test NPP threshold boundary (100.0)
        temperate_dec = TemperateDeciduous()
        pft_states = Dict{AbstractPFT, PFTState{Float64, Int}}()
        for pft in biome_pfts.pft_list
            pft_states[pft] = PFTState{Float64, Int}()
        end
        pft_states[temperate_dec] = PFTState{Float64, Int}()
        
        # Exactly at threshold (NPP <= 100.0 means Desert)
        pft_states[temperate_dec].npp = 100.0
        result_at_threshold = assign_biome(temperate_dec; gdd5=1800.0, tcm=0.0, BIOME4PFTS=biome_pfts, PFTStates=pft_states)
        @test isa(result_at_threshold, Desert)
        
        # Just above threshold
        pft_states[temperate_dec].npp = 100.1
        result_above_threshold = assign_biome(temperate_dec; gdd5=1800.0, tcm=0.0, BIOME4PFTS=biome_pfts, PFTStates=pft_states)
        @test isa(result_above_threshold, TemperateDeciduousForest)
        
        # Just below threshold
        pft_states[temperate_dec].npp = 99.9
        result_below_threshold = assign_biome(temperate_dec; gdd5=1800.0, tcm=0.0, BIOME4PFTS=biome_pfts, PFTStates=pft_states)
        @test isa(result_below_threshold, Desert)
        
        # Test GDD thresholds for boreal evergreen
        boreal_evergreen = BorealEvergreen()
        pft_states[boreal_evergreen] = PFTState{Float64, Int}()
        
        # At GDD5 threshold (900.0) and TCM threshold (-19.0)
        result_gdd_threshold = assign_biome(boreal_evergreen; gdd5=900.0, tcm=-19.0, BIOME4PFTS=biome_pfts, PFTStates=pft_states)
        @test isa(result_gdd_threshold, EvergreenTaigaMontaneForest) # At threshold boundary
        
        # Above GDD5 threshold
        result_gdd_above = assign_biome(boreal_evergreen; gdd5=901.0, tcm=-18.0, BIOME4PFTS=biome_pfts, PFTStates=pft_states)
        @test isa(result_gdd_above, CoolConiferForest) # Above threshold
        
        # Below GDD5 threshold
        result_gdd_below = assign_biome(boreal_evergreen; gdd5=899.0, tcm=-20.0, BIOME4PFTS=biome_pfts, PFTStates=pft_states)
        @test isa(result_gdd_below, EvergreenTaigaMontaneForest) # Below threshold
    end
    
    @testset "Edge Cases and Error Handling" begin
        # Test with extreme climate values
        tropical_evergreen = TropicalEvergreen()
        pft_states = Dict{AbstractPFT, PFTState{Float64, Int}}()
        pft_states[tropical_evergreen] = PFTState{Float64, Int}()
        pft_states[tropical_evergreen].npp = 300.0
        
        # Extreme cold - should still work based on NPP
        result_extreme_cold = assign_biome(tropical_evergreen; PFTStates=pft_states)
        @test isa(result_extreme_cold, TropicalEvergreenForest)
        
        # Extreme hot - should still work based on NPP
        result_extreme_hot = assign_biome(tropical_evergreen; PFTStates=pft_states)
        @test isa(result_extreme_hot, TropicalEvergreenForest)
        
        # Test with zero NPP
        pft_states[tropical_evergreen].npp = 0.0
        result_zero_npp = assign_biome(tropical_evergreen; PFTStates=pft_states)
        @test isa(result_zero_npp, Desert)
        
        # Test with negative NPP
        pft_states[tropical_evergreen].npp = -50.0
        result_negative_npp = assign_biome(tropical_evergreen; PFTStates=pft_states)
        @test isa(result_negative_npp, Desert)
    end
    
    @testset "Complex Interaction Tests" begin
        # Test complex scenarios with multiple PFTs and states
        biome_pfts = PFTClassification()
        
        # Create comprehensive PFT states dictionary
        pft_states = Dict{AbstractPFT, PFTState{Float64, Int}}()
        for pft in biome_pfts.pft_list
            pft_states[pft] = PFTState{Float64, Int}()
        end
        
        # Test scenario: Temperate deciduous with multiple other PFTs present
        temperate_dec = first(pft for pft in biome_pfts.pft_list if get_characteristic(pft, :name) == "TemperateDeciduous")
        boreal_evergreen = first(pft for pft in biome_pfts.pft_list if get_characteristic(pft, :name) == "BorealEvergreen")
        temperate_be = first(pft for pft in biome_pfts.pft_list if get_characteristic(pft, :name) == "TemperateBroadleavedEvergreen")
        cool_conifer = first(pft for pft in biome_pfts.pft_list if get_characteristic(pft, :name) == "CoolConifer")
        
        pft_states[temperate_dec].npp = 200.0
        pft_states[temperate_be].present = true
        pft_states[cool_conifer].present = true
        pft_states[boreal_evergreen].present = false
        
        # With high GDD5 and moderate TCM, should prefer warm mixed forest
        result_complex1 = assign_biome(temperate_dec; gdd5=3500.0, tcm=5.0, BIOME4PFTS=biome_pfts, PFTStates=pft_states)
        @test isa(result_complex1, WarmMixedForest)
        
        # Test scenario: Cool conifer with multiple interactions
        pft_states[cool_conifer].npp = 180.0
        pft_states[temperate_be].present = false
        
        temperate_dec_sub = TemperateDeciduous()
        pft_states[temperate_dec_sub] = PFTState{Float64, Int}()
        
        result_complex2 = assign_biome(cool_conifer; subpft=temperate_dec_sub, BIOME4PFTS=biome_pfts, PFTStates=pft_states)
        @test isa(result_complex2, TemperateConiferForest)
        
        # Test scenario: Woody desert with varying LAI conditions
        woody_desert = WoodyDesert()
        subdominant = Default()
        pft_states[woody_desert] = PFTState{Float64, Int}()
        pft_states[subdominant] = PFTState{Float64, Int}()
        
        pft_states[woody_desert].npp = 120.0
        
        # High LAI, warm conditions
        pft_states[subdominant].lai = 1.5
        result_desert_warm = assign_biome(woody_desert; subpft=subdominant, tmin=8.0, PFTStates=pft_states)
        @test isa(result_desert_warm, TropicalXerophyticShrubland)
        
        # High LAI, cold conditions
        result_desert_cold = assign_biome(woody_desert; subpft=subdominant, tmin=-5.0, PFTStates=pft_states)
        @test isa(result_desert_cold, TemperateXerophyticShrubland)
        
        # Low LAI, any conditions
        pft_states[subdominant].lai = 0.8
        result_desert_low_lai = assign_biome(woody_desert; subpft=subdominant, tmin=8.0, PFTStates=pft_states)
        @test isa(result_desert_low_lai, Desert)
    end
    
    @testset "Grassland Transition Tests" begin
        # Test various grass PFT scenarios
        temperate_grass = C3C4TemperateGrass()
        tropical_grass = C4TropicalGrass()
        
        pft_states = Dict{AbstractPFT, PFTState{Float64, Int}}()
        pft_states[temperate_grass] = PFTState{Float64, Int}()
        pft_states[tropical_grass] = PFTState{Float64, Int}()
        
        # Test temperate grass transitions based on GDD0
        pft_states[temperate_grass].npp = 130.0
        
        # High GDD0 - temperate grassland
        result_grass_warm = assign_biome(temperate_grass; subpft=DEFAULT_INSTANCE, gdd0=850.0, PFTStates=pft_states)
        @test isa(result_grass_warm, TemperateGrassland)
        
        # Medium GDD0 - steppe tundra
        result_grass_med = assign_biome(temperate_grass; subpft=DEFAULT_INSTANCE, gdd0=600.0, PFTStates=pft_states)
        @test isa(result_grass_med, SteppeTundra)
        
        # Low GDD0 - steppe tundra
        result_grass_cold = assign_biome(temperate_grass; subpft=DEFAULT_INSTANCE, gdd0=400.0, PFTStates=pft_states)
        @test isa(result_grass_cold, SteppeTundra)
        
        # Test with boreal subdominant
        boreal_evergreen = BorealEvergreen()
        pft_states[boreal_evergreen] = PFTState{Float64, Int}()
        result_grass_boreal = assign_biome(temperate_grass; subpft=boreal_evergreen, gdd0=600.0, PFTStates=pft_states)
        @test isa(result_grass_boreal, SteppeTundra)
        
        # Test tropical grass
        pft_states[tropical_grass].npp = 160.0
        result_trop_grass = assign_biome(tropical_grass; PFTStates=pft_states)
        @test isa(result_trop_grass, TropicalGrassland)
        
        # Low NPP tropical grass
        pft_states[tropical_grass].npp = 90.0
        result_trop_grass_low = assign_biome(tropical_grass; PFTStates=pft_states)
        @test isa(result_trop_grass_low, Desert)
    end
    
    @testset "Tundra Gradient Tests" begin
        # Test tundra shrubs across GDD0 gradient
        tundra_shrubs = TundraShrubs()
        
        # Very cold conditions (< 200 GDD0)
        result_tundra_1 = assign_biome(tundra_shrubs; gdd0=100.0)
        @test isa(result_tundra_1, CushionForbsLichenMoss)
        
        result_tundra_2 = assign_biome(tundra_shrubs; gdd0=199.0)
        @test isa(result_tundra_2, CushionForbsLichenMoss)
        
        # Medium cold conditions (200-500 GDD0)
        result_tundra_3 = assign_biome(tundra_shrubs; gdd0=200.0)
        @test isa(result_tundra_3, ProstateShrubTundra)
        
        result_tundra_4 = assign_biome(tundra_shrubs; gdd0=350.0)
        @test isa(result_tundra_4, ProstateShrubTundra)
        
        result_tundra_5 = assign_biome(tundra_shrubs; gdd0=499.0)
        @test isa(result_tundra_5, ProstateShrubTundra)
        
        # Warmer conditions (>= 500 GDD0)
        result_tundra_6 = assign_biome(tundra_shrubs; gdd0=500.0)
        @test isa(result_tundra_6, DwarfShrubTundra)
        
        result_tundra_7 = assign_biome(tundra_shrubs; gdd0=750.0)
        @test isa(result_tundra_7, DwarfShrubTundra)
    end
    
    @testset "Forest Type Determination Tests" begin
        # Test various forest type determinations
        biome_pfts = PFTClassification()
        
        # Create comprehensive PFT states
        pft_states = Dict{AbstractPFT, PFTState{Float64, Int}}()
        for pft in biome_pfts.pft_list
            pft_states[pft] = PFTState{Float64, Int}()
        end
        
        # Test boreal evergreen with different climate conditions
        boreal_evergreen = first(pft for pft in biome_pfts.pft_list if get_characteristic(pft, :name) == "BorealEvergreen")
        temperate_deciduous = first(pft for pft in biome_pfts.pft_list if get_characteristic(pft, :name) == "TemperateDeciduous")
        
        # Scenario 1: Warm boreal with temperate deciduous present
        pft_states[temperate_deciduous].present = true
        result_boreal_1 = assign_biome(boreal_evergreen; gdd5=1000.0, tcm=-15.0, BIOME4PFTS=biome_pfts, PFTStates=pft_states)
        @test isa(result_boreal_1, CoolMixedForest)
        
        # Scenario 2: Warm boreal without temperate deciduous
        pft_states[temperate_deciduous].present = false
        result_boreal_2 = assign_biome(boreal_evergreen; gdd5=1000.0, tcm=-15.0, BIOME4PFTS=biome_pfts, PFTStates=pft_states)
        @test isa(result_boreal_2, CoolConiferForest)
        
        # Scenario 3: Cold boreal with temperate deciduous present
        pft_states[temperate_deciduous].present = true
        result_boreal_3 = assign_biome(boreal_evergreen; gdd5=600.0, tcm=-25.0, BIOME4PFTS=biome_pfts, PFTStates=pft_states)
        @test isa(result_boreal_3, ColdMixedForest)
        
        # Scenario 4: Cold boreal without temperate deciduous
        pft_states[temperate_deciduous].present = false
        result_boreal_4 = assign_biome(boreal_evergreen; gdd5=600.0, tcm=-25.0, BIOME4PFTS=biome_pfts, PFTStates=pft_states)
        @test isa(result_boreal_4, EvergreenTaigaMontaneForest)
    end
    
    @testset "Savanna and Woodland Tests" begin
        # Test Default PFT with various woody dominants
        default_pft = Default()
        pft_states = Dict{AbstractPFT, PFTState{Float64, Int}}()
        pft_states[default_pft] = PFTState{Float64, Int}()
        
        # Test tropical drought deciduous as woody dominant
        tropical_drought = TropicalDroughtDeciduous()
        pft_states[tropical_drought] = PFTState{Float64, Int}()
        
        # High LAI tropical savanna
        pft_states[tropical_drought].lai = 5.0
        result_savanna = assign_biome(default_pft; wdom=tropical_drought, PFTStates=pft_states)
        @test isa(result_savanna, TropicalSavanna)
        
        # Low LAI tropical shrubland
        pft_states[tropical_drought].lai = 3.0
        result_shrubland = assign_biome(default_pft; wdom=tropical_drought, PFTStates=pft_states)
        @test isa(result_shrubland, TropicalXerophyticShrubland)
        
        # Test with nothing as woody dominant
        result_no_woody = assign_biome(default_pft; wdom=NONE_INSTANCE, PFTStates=pft_states)
        @test isa(result_no_woody, Barren)
        
        # Test with various other woody dominants
        temperate_be = TemperateBroadleavedEvergreen()
        pft_states[temperate_be] = PFTState{Float64, Int}()
        result_sclerophyll = assign_biome(default_pft; wdom=temperate_be, PFTStates=pft_states)
        @test isa(result_sclerophyll, TemperateSclerophyllWoodland)
        
        temperate_dec = TemperateDeciduous()
        pft_states[temperate_dec] = PFTState{Float64, Int}()
        result_broadleaved_savanna = assign_biome(default_pft; wdom=temperate_dec, PFTStates=pft_states)
        @test isa(result_broadleaved_savanna, TemperateBroadleavedSavanna)
        
        cool_conifer = CoolConifer()
        pft_states[cool_conifer] = PFTState{Float64, Int}()
        result_open_conifer = assign_biome(default_pft; wdom=cool_conifer, PFTStates=pft_states)
        @test isa(result_open_conifer, OpenConiferWoodland)
        
        boreal_deciduous = BorealDeciduous()
        pft_states[boreal_deciduous] = PFTState{Float64, Int}()
        result_parkland = assign_biome(default_pft; wdom=boreal_deciduous, PFTStates=pft_states)
        @test isa(result_parkland, BorealParkland)
    end
end
