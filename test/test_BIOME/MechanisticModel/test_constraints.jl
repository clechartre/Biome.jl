using Test

# Create mock types for testing
struct MockPFT <: AbstractPFT
    characteristics::PFTCharacteristics
end

struct MockPFTList <: AbstractPFTList
    pft_list::Vector{AbstractPFT}
end

@testset "Constraints Tests" begin
    
    @testset "Positive Test - PFT meets all constraints" begin
        # Create mock PFT with loose constraints that should pass
        ch = PFTCharacteristics()
        ch.constraints = (
            tcm = [-50.0, 50.0],    # Wide temperature range
            min = [-60.0, 40.0],    # Wide min temp range  
            gdd = [0.0, 10000.0],   # Wide GDD range
            gdd0 = [0.0, 15000.0],  # Wide GDD0 range
            twm = [-10.0, 60.0],    # Wide warm month range
            snow = [0.0, 1000.0]    # Wide snow depth range
        )
        mock_pft = MockPFT(ch)
        pft_list = MockPFTList([mock_pft])
        
        # Create PFTStates dictionary
        PFTStates = Dict{AbstractPFT,PFTState}()
        PFTStates[mock_pft] = PFTState(mock_pft)
        
        env_variables = (
            tcm = 10.0,
            twm = 25.0,
            min = 5.0,
            gdd = 2000.0,
            gdd0 = 3000.0,
            snow = 100.0
        )
        
        updated_states = constraints(pft_list, PFTStates, env_variables)
        
        @test updated_states[mock_pft].present == true

    end
    
    @testset "Negative Test - PFT violates constraints" begin
        # Create mock PFT with strict constraints that should fail
        ch = PFTCharacteristics()
        ch.constraints = (
            tcm = [-10.0, -5.0],    # Narrow temperature range
            min = [-60.0, -50.0],    # Narrow min temp range  
            gdd = [100.0, 150.0],   # Narrow GDD range
            gdd0 = [100.0, 150.0],  # Narrow GDD0 range
            twm = [10.0, 15.0],    # Narrow warm month range
            snow = [0.0, 20.0]    # Narrow snow depth range
        )
        mock_pft = MockPFT(ch)
        pft_list = MockPFTList([mock_pft])

        # Create PFTStates dictionary
        PFTStates = Dict{AbstractPFT,PFTState}()
        PFTStates[mock_pft] = PFTState(mock_pft)
        
        env_variables = (
            tcm = 5.0, # Too cold
            twm = 15.0,
            min = 0.0,
            gdd = 1000.0,
            gdd0 = 2000.0, # Too low GDD values
            snow = 200.0  # Too high snow depth
        )

        updated_states = constraints(pft_list, PFTStates, env_variables)
        
        @test updated_states[mock_pft].present == false

    end
    
    @testset "Edge Cases - Boundary Values" begin
        # Test exactly on boundary values
        ch = PFTCharacteristics()
        ch.constraints = (
            tcm = [-10.0, 20.0],
            gdd = [1000.0, 5000.0]
        )
        mock_pft = MockPFT(ch)
        pft_list = MockPFTList([mock_pft])
        PFTStates = Dict{AbstractPFT,PFTState}()
        PFTStates[mock_pft] = PFTState(mock_pft)
        
        # Test lower boundary (should pass: >= lower)
        env_lower = (tcm = -10.0, gdd = 1000.0)
        updated_states = constraints(pft_list, PFTStates, env_lower)
        @test updated_states[mock_pft].present == true
        
        # Test upper boundary (should fail: < upper, not <=)
        env_upper = (tcm = 20.0, gdd = 5000.0)
        updated_states = constraints(pft_list, PFTStates, env_upper)
        @test updated_states[mock_pft].present == false
        
        # Test just below upper (should pass)
        env_just_below = (tcm = 19.9, gdd = 4999.9)
        updated_states = constraints(pft_list, PFTStates, env_just_below)
        @test updated_states[mock_pft].present == true
        
        # Test just below lower (should fail)
        env_just_below_lower = (tcm = -10.1, gdd = 999.9)
        updated_states = constraints(pft_list, PFTStates, env_just_below_lower)
        @test updated_states[mock_pft].present == false
    end
    
    @testset "Edge Cases - Infinite Bounds" begin
        # Test with -Inf and +Inf bounds
        ch = PFTCharacteristics()
        ch.constraints = (
            tcm = [-Inf, Inf],    # No constraints
            twm = [-Inf, 30.0],   # Only upper bound
            gdd = [500.0, Inf]    # Only lower bound
        )
        mock_pft = MockPFT(ch)
        pft_list = MockPFTList([mock_pft])
        PFTStates = Dict{AbstractPFT,PFTState}()
        PFTStates[mock_pft] = PFTState(mock_pft)
        
        # Test extreme values that should pass
        env_extreme = (
            tcm = -1000.0,  # Should pass with -Inf bound
            twm = 25.0,     # Should pass (< 30.0)
            gdd = 10000.0   # Should pass with +Inf bound
        )
        updated_states = constraints(pft_list, PFTStates, env_extreme)
        @test updated_states[mock_pft].present == true
        
        # Test violating the finite bounds
        env_violate = (
            tcm = -500.0,  # Should still pass
            twm = 35.0,    # Should fail (>= 30.0)
            gdd = 100.0    # Should fail (< 500.0)
        )
        updated_states = constraints(pft_list, PFTStates, env_violate)
        @test updated_states[mock_pft].present == false
    end
    
    @testset "Edge Cases - Missing Environment Variables" begin
        # Test when required constraint variables are missing
        ch = PFTCharacteristics()
        ch.constraints = (
            tcm = [-10.0, 20.0],
            missing_var = [0.0, 100.0]  # This var won't be in env_variables
        )
        mock_pft = MockPFT(ch)
        pft_list = MockPFTList([mock_pft])
        PFTStates = Dict{AbstractPFT,PFTState}()
        PFTStates[mock_pft] = PFTState(mock_pft)
        
        env_incomplete = (tcm = 5.0,)  # missing_var not provided
        
        # Should generate warning and set present = false
        updated_states = constraints(pft_list, PFTStates, env_incomplete)
        @test updated_states[mock_pft].present == false

        # Test for warning capture
        @test_logs (:warn, "Missing environment variable for constraint: missing_var")

    end
    
    @testset "Edge Cases - Empty and Single PFT Lists" begin
        # Test with empty PFT list
        empty_pft_list = MockPFTList(AbstractPFT[])
        PFTStates_empty = Dict{AbstractPFT,PFTState}()
        env_variables = (tcm = 10.0, twm = 25.0)
        
        updated_states = constraints(empty_pft_list, PFTStates_empty, env_variables)
        @test isempty(updated_states)
        
        # Test with single PFT
        ch_single = PFTCharacteristics()
        ch_single.constraints = (tcm = [0.0, 30.0],)
        single_pft = MockPFT(ch_single)
        single_pft_list = MockPFTList([single_pft])
        PFTStates_single = Dict{AbstractPFT,PFTState}()
        PFTStates_single[single_pft] = PFTState(single_pft)
        
        updated_states = constraints(single_pft_list, PFTStates_single, env_variables)
        @test length(updated_states) == 1
        @test updated_states[single_pft].present == true
    end
    
    @testset "Edge Cases - Vector Environmental Variables" begin
        # Test with vector environmental data
        ch = PFTCharacteristics()
        ch.constraints = (
            tcm_vec = [-5.0, 25.0],
        )
        mock_pft = MockPFT(ch)
        pft_list = MockPFTList([mock_pft])
        PFTStates = Dict{AbstractPFT,PFTState}()
        PFTStates[mock_pft] = PFTState(mock_pft)
        
        # Test vector where all values meet constraint
        env_vector_pass = (tcm_vec = [10.0, 15.0, 20.0, 5.0],)
        updated_states = constraints(pft_list, PFTStates, env_vector_pass)
        @test updated_states[mock_pft].present == true
        
        # Test vector where some values violate constraint
        env_vector_fail = (tcm_vec = [10.0, 15.0, 30.0, 5.0],)  # 30.0 > 25.0
        updated_states = constraints(pft_list, PFTStates, env_vector_fail)
        @test updated_states[mock_pft].present == false
        
        # Test vector with missing values
        env_vector_missing = (tcm_vec = [10.0, missing, 20.0],)
        updated_states = constraints(pft_list, PFTStates, env_vector_missing)
        @test updated_states[mock_pft].present == true  # Should pass with non-missing values
        
        # Test vector with all missing values
        env_vector_all_missing = (tcm_vec = [missing, missing, missing],)
        updated_states = constraints(pft_list, PFTStates, env_vector_all_missing)
        @test updated_states[mock_pft].present == false  # Should fail
    end
    
    @testset "Type Consistency Tests" begin
        # Test with different numeric types
        ch = PFTCharacteristics()
        ch.constraints = (tcm = [-10.0, 20.0], gdd = [1000.0, 5000.0])
        mock_pft = MockPFT(ch)
        pft_list = MockPFTList([mock_pft])
        PFTStates = Dict{AbstractPFT,PFTState}()
        PFTStates[mock_pft] = PFTState(mock_pft)
        
        # Test Float32 inputs
        env_f32 = (tcm = Float32(5.0), gdd = Float32(2000.0))
        updated_states = constraints(pft_list, PFTStates, env_f32)
        @test updated_states[mock_pft].present == true
        @test typeof(updated_states[mock_pft].present) == Bool
        
        # Test Int inputs (should work due to type promotion)
        env_int = (tcm = 5, gdd = 2000)
        updated_states = constraints(pft_list, PFTStates, env_int)
        @test updated_states[mock_pft].present == true
        
        # Test mixed types
        env_mixed = (tcm = Float32(5.0), gdd = 2000)
        updated_states = constraints(pft_list, PFTStates, env_mixed)
        @test updated_states[mock_pft].present == true
    end
    
    @testset "Multiple PFT Tests" begin
        # Test with multiple PFTs having different constraints
        ch1 = PFTCharacteristics()
        ch1.constraints = (tcm = [0.0, 15.0], gdd = [1000.0, 3000.0])
        pft1 = MockPFT(ch1)
        
        ch2 = PFTCharacteristics()
        ch2.constraints = (tcm = [10.0, 25.0], gdd = [2000.0, 5000.0])
        pft2 = MockPFT(ch2)
        
        ch3 = PFTCharacteristics()
        ch3.constraints = (tcm = [-5.0, 5.0], gdd = [500.0, 1500.0])
        pft3 = MockPFT(ch3)
        
        multi_pft_list = MockPFTList([pft1, pft2, pft3])
        PFTStates = Dict{AbstractPFT,PFTState}()
        PFTStates[pft1] = PFTState(pft1)
        PFTStates[pft2] = PFTState(pft2)
        PFTStates[pft3] = PFTState(pft3)
        
        # Environment that should favor pft1
        env_favor_1 = (tcm = 12.0, gdd = 2500.0)
        updated_states = constraints(multi_pft_list, PFTStates, env_favor_1)
        @test updated_states[pft1].present == true   # tcm=12 ∈ [0,15), gdd=2500 ∈ [1000,3000)
        @test updated_states[pft2].present == true   # tcm=12 ∈ [10,25), gdd=2500 ∈ [2000,5000)
        @test updated_states[pft3].present == false  # tcm=12 ∉ [-5,5), gdd=2500 ∉ [500,1500)
        
        # Environment that should favor pft3
        env_favor_3 = (tcm = 2.0, gdd = 1200.0)
        updated_states = constraints(multi_pft_list, PFTStates, env_favor_3)
        @test updated_states[pft1].present == true   # tcm=2 ∈ [0,15), gdd=1200 ∈ [1000,3000)
        @test updated_states[pft2].present == false  # tcm=2 ∉ [10,25)
        @test updated_states[pft3].present == true   # tcm=2 ∈ [-5,5), gdd=1200 ∈ [500,1500)
        
        # Environment that favors none
        env_favor_none = (tcm = 30.0, gdd = 6000.0)
        updated_states = constraints(multi_pft_list, PFTStates, env_favor_none)
        @test updated_states[pft1].present == false
        @test updated_states[pft2].present == false  # gdd=6000 ∉ [2000,5000)
        @test updated_states[pft3].present == false
    end
    
    @testset "SWB Constraint Skipping" begin
        # Test that swb constraints are properly skipped
        ch = PFTCharacteristics()
        ch.constraints = (
            tcm = [0.0, 20.0],
            swb = [500.0, 1500.0],  # This should be skipped
            gdd = [1000.0, 3000.0]
        )
        mock_pft = MockPFT(ch)
        pft_list = MockPFTList([mock_pft])
        PFTStates = Dict{AbstractPFT,PFTState}()
        PFTStates[mock_pft] = PFTState(mock_pft)
        
        # Don't provide swb in environment (should still pass if other constraints met)
        env_no_swb = (tcm = 10.0, gdd = 2000.0)
        updated_states = constraints(pft_list, PFTStates, env_no_swb)
        @test updated_states[mock_pft].present == true
        
        # Provide swb but it should be ignored
        env_with_swb = (tcm = 10.0, gdd = 2000.0, swb = 100.0)  # swb violates constraint but should be ignored
        updated_states = constraints(pft_list, PFTStates, env_with_swb)
        @test updated_states[mock_pft].present == true
    end
    
    @testset "Return Type Validation" begin
        # Test that function returns correct type
        ch = PFTCharacteristics()
        ch.constraints = (tcm = [0.0, 20.0],)
        mock_pft = MockPFT(ch)
        pft_list = MockPFTList([mock_pft])
        PFTStates = Dict{AbstractPFT,PFTState}()
        PFTStates[mock_pft] = PFTState(mock_pft)
    
        env_variables = (tcm = 10.0,)
        
        updated_states = constraints(pft_list, PFTStates, env_variables)
        
        # Check return type
        @test isa(updated_states, Dict{AbstractPFT,PFTState})
        @test haskey(updated_states, mock_pft)
        @test isa(updated_states[mock_pft], PFTState)
        @test isa(updated_states[mock_pft].present, Bool)
        
        # Check that the original PFTStates dict is modified
        @test PFTStates[mock_pft].present == updated_states[mock_pft].present
    end
end