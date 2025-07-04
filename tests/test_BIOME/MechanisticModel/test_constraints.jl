using Test


include("../../../src/abstractmodel.jl")
include("../../../src/pfts.jl")
include("../../../src/biomes.jl")
include("../../../src/models/MechanisticModel/pfts.jl")
include("../../../src/models/MechanisticModel/constraints.jl")


# Create mock types for testing
struct MockPFT <: AbstractPFT
    characteristics::Characteristics
end

struct MockPFTList <: AbstractPFTList
    pft_list::Vector{AbstractPFT}
end

@testset "Constraints Tests" begin
    
    @testset "Positive Test - PFT meets all constraints" begin
        # Create mock PFT with loose constraints that should pass
        ch = Characteristics()
        ch.constraints = (
            tcm = Vector{Float64}([-50.0, 50.0]),    # Wide temperature range
            min = Vector{Float64}([-60.0, 40.0]),    # Wide min temp range  
            gdd = Vector{Float64}([0.0, 10000.0]),   # Wide GDD range
            gdd0 = Vector{Float64}([0.0, 15000.0]),  # Wide GDD0 range
            twm = Vector{Float64}([-10.0, 60.0]),    # Wide warm month range
            snow = Vector{Float64}([0.0, 1000.0])    # Wide snow depth range
        )
        mock_pft = MockPFT(ch)
        pft_list = MockPFTList([mock_pft])
        
        # Input values that should satisfy all constraints
        tcm, twm, tminin = 10.0, 25.0, 5.0
        gdd5, rad0, gdd0 = 2000.0, 150.0, 3000.0
        maxdepth = 100.0
        
        tmin, updated_pfts = constraints(tcm, twm, tminin, gdd5, rad0, gdd0, maxdepth, pft_list)
        
        @test get_characteristic(updated_pfts.pft_list[1], :present) == true
        @test tmin == tminin  # Since tminin <= tcm
    end
    
    @testset "Negative Test - PFT violates constraints" begin
        # Create mock PFT with strict constraints that should fail
        ch = Characteristics()
        ch.constraints = (
            tcm = Vector{Float64}([-10.0, -5.0]),    # Narrow temperature range
            min = Vector{Float64}([-60.0, -50.0]),    # Narrow min temp range  
            gdd = Vector{Float64}([100.0, 150.0]),   # Narrow GDD range
            gdd0 = Vector{Float64}([100.0, 150.0]),  # Narrow GDD0 range
            twm = Vector{Float64}([10.0, 15.0]),    # Narrow warm month range
            snow = Vector{Float64}([0.0, 20.0])    # Narrow snow depth range
        )
        mock_pft = MockPFT(ch)
        pft_list = MockPFTList([mock_pft])

        # Input values that violate multiple constraints
        tcm, twm, tminin = 5.0, 15.0, 0.0  # Too cold
        gdd5, rad0, gdd0 = 1000.0, 150.0, 2000.0  # Too low GDD values
        maxdepth = 200.0  # Too high snow depth
        
        tmin, updated_pfts = constraints(tcm, twm, tminin, gdd5, rad0, gdd0, maxdepth, pft_list)
        
        @test get_characteristic(updated_pfts.pft_list[1], :present) == false
        @test tmin == tcm - 5.0  # Since tminin > tcm, tmin = tcm - 5.0
    end
end