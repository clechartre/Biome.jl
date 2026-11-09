using Test

struct FitnessMockPFT <: AbstractPFT
    characteristics::PFTCharacteristics
end

function fitness_environment(value)
    (
        tcm = value,
        tmin = value,
        gdd5 = value,
        gdd0 = value,
        twm = value,
        maxdepth = value,
    )
end

function fitness_value(pft, value)
    env = fitness_environment(value)
    dominance_environment_mv(
        pft;
        tcm = env.tcm,
        tmin = env.tmin,
        gdd5 = env.gdd5,
        gdd0 = env.gdd0,
        twm = env.twm,
        maxdepth = env.maxdepth,
    )
end

@testset "Niche fitness" begin
    finite_constraints = (
        tcm = [0.0, 10.0],
        tmin = [-Inf, Inf],
        gdd5 = [-Inf, Inf],
        gdd0 = [-Inf, Inf],
        twm = [-Inf, Inf],
        maxdepth = [-Inf, Inf],
    )
    finite_pft = FitnessMockPFT(PFTCharacteristics(constraints = finite_constraints))

    @test fitness_value(finite_pft, 5.0) == 1.0
    @test fitness_value(finite_pft, 2.5) < 1.0
    @test fitness_value(finite_pft, 7.5) < 1.0
    @test fitness_value(finite_pft, 2.5) == fitness_value(finite_pft, 7.5)

    dominant_pft = FitnessMockPFT(PFTCharacteristics(
        constraints = finite_constraints,
        dominance_factor = 1,
    ))
    selective_pft = FitnessMockPFT(PFTCharacteristics(
        constraints = finite_constraints,
        dominance_factor = 8,
    ))
    @test fitness_value(dominant_pft, 5.0) == 1.0
    @test fitness_value(selective_pft, 5.0) == 1.0
    @test fitness_value(selective_pft, 2.5) < fitness_value(dominant_pft, 2.5)

    lower_bounded_constraints = (
        tcm = [0.0, Inf],
        tmin = [-Inf, Inf],
        gdd5 = [-Inf, Inf],
        gdd0 = [-Inf, Inf],
        twm = [-Inf, Inf],
        maxdepth = [-Inf, Inf],
    )
    lower_bounded_pft = FitnessMockPFT(PFTCharacteristics(constraints = lower_bounded_constraints))
    @test fitness_value(lower_bounded_pft, 0.0) == 1.0
    @test fitness_value(lower_bounded_pft, 10.0) == 1.0
    @test fitness_value(lower_bounded_pft, -10.0) == 1.0

    unconstrained_pft = FitnessMockPFT(PFTCharacteristics())
    @test fitness_value(unconstrained_pft, 10_000.0) == 1.0

    one_sided_pft = FitnessMockPFT(PFTCharacteristics(constraints = (
        tcm = [0.0, Inf],
        tmin = [-Inf, Inf],
        gdd5 = [-Inf, Inf],
        gdd0 = [-Inf, Inf],
        twm = [-Inf, 15.0],
        maxdepth = [-Inf, Inf],
    )))
    @test fitness_value(one_sided_pft, 10_000.0) == 1.0
end
