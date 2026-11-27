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
    samples = (
        tcm = collect(1.0:10.0),
        tmin = collect(2.0:2.0:20.0),
        gdd5 = collect(10.0:10.0:100.0),
    )
    @test select_noncollinear_predictors(samples; threshold=0.7) == (:gdd5,)

    custom_constraints = (
        tcm = [-Inf, Inf],
        moisture = [0.0, 10.0],
        gdd5 = [-Inf, Inf],
        swb = [-Inf, Inf],
    )
    custom_pft = FitnessMockPFT(PFTCharacteristics(constraints = custom_constraints))
    @test dominance_environment_mv(
        custom_pft;
        tcm = 0.0,
        gdd5 = 0.0,
        moisture = 5.0,
    ) == 1.0
    @test dominance_environment_mv(
        custom_pft;
        tcm = 0.0,
        gdd5 = 0.0,
        moisture = 0.0,
    ) < 1.0

    finite_constraints = (
        tcm = [0.0, 4.0],   # narrower than two decline zones: centred Gaussian
        tmin = [-Inf, Inf],
        gdd5 = [-Inf, Inf],
        gdd0 = [-Inf, Inf],
        twm = [-Inf, Inf],
        maxdepth = [-Inf, Inf],
    )
    finite_pft = FitnessMockPFT(PFTCharacteristics(constraints = finite_constraints))

    @test fitness_value(finite_pft, 2.0) == 1.0
    @test fitness_value(finite_pft, 1.0) < 1.0
    @test fitness_value(finite_pft, 3.0) < 1.0
    @test fitness_value(finite_pft, 1.0) == fitness_value(finite_pft, 3.0)

    # The dominance factor sharpens the fitness decline away from the niche
    # centre; fitness at the centre stays 1 whatever its value.
    low_factor_pft = FitnessMockPFT(PFTCharacteristics(
        constraints = finite_constraints,
        dominance_factor = 1,
    ))
    high_factor_pft = FitnessMockPFT(PFTCharacteristics(
        constraints = finite_constraints,
        dominance_factor = 8,
    ))
    @test fitness_value(low_factor_pft, 2.0) == 1.0
    @test fitness_value(high_factor_pft, 2.0) == 1.0
    @test fitness_value(high_factor_pft, 1.0) < fitness_value(low_factor_pft, 1.0)
    @test fitness_value(low_factor_pft, 0.0) ≈ exp(-2.0)          # D = 1 at a bound
    @test fitness_value(high_factor_pft, 1.0) ≈ max(exp(-4.0), 0.01) # D = 8, half-way

    lower_bounded_constraints = (
        tcm = [0.0, Inf],
        tmin = [-Inf, Inf],
        gdd5 = [-Inf, Inf],
        gdd0 = [-Inf, Inf],
        twm = [-Inf, Inf],
        maxdepth = [-Inf, Inf],
    )
    # One-sided bound: flat (S = 1) beyond a decline zone of width
    # w = ONE_SIDED_ZONE * natural range, declining to exp(-2D) at the bound.
    @test ONE_SIDED_ZONE[] == 0.05
    w_tcm = 0.05 * (NATURAL_LIMITS[:tcm][2] - NATURAL_LIMITS[:tcm][1])
    lower_bounded_pft = FitnessMockPFT(PFTCharacteristics(
        constraints = lower_bounded_constraints,
        dominance_factor = 1,
    ))
    @test fitness_value(lower_bounded_pft, 0.0) ≈ exp(-2.0)          # at the bound
    @test fitness_value(lower_bounded_pft, w_tcm / 2) ≈ exp(-0.5)    # half-way into the zone
    @test fitness_value(lower_bounded_pft, w_tcm) == 1.0             # edge of the zone
    @test fitness_value(lower_bounded_pft, 10.0 * w_tcm) == 1.0      # open side stays flat

    # A wider zone lowers suitability at the same distance from the bound
    ONE_SIDED_ZONE[] = 0.25
    @test fitness_value(lower_bounded_pft, w_tcm) < 1.0
    ONE_SIDED_ZONE[] = 0.05

    # Wide two-sided interval: plateau between the two edge zones
    wide_pft = FitnessMockPFT(PFTCharacteristics(constraints = (
        tcm = [-30.0, 0.0], tmin = [-Inf, Inf], gdd5 = [-Inf, Inf],
        gdd0 = [-Inf, Inf], twm = [-Inf, Inf], maxdepth = [-Inf, Inf],
    ), dominance_factor = 1))
    @test fitness_value(wide_pft, -15.0) == 1.0                      # middle
    @test fitness_value(wide_pft, -30.0 + w_tcm) == 1.0              # edge of lower zone
    @test fitness_value(wide_pft, -30.0) ≈ exp(-2.0)                 # lower bound
    @test fitness_value(wide_pft, 0.0) ≈ exp(-2.0)                   # upper bound
    # Narrow interval ([0, 4] < 2w): zones meet, centred Gaussian
    @test fitness_value(low_factor_pft, 1.0) ≈ exp(-0.5)

    unconstrained_pft = FitnessMockPFT(PFTCharacteristics())
    @test fitness_value(unconstrained_pft, 10_000.0) == 1.0

    one_sided_pft = FitnessMockPFT(PFTCharacteristics(constraints = (
        tcm = [0.0, Inf],
        tmin = [-Inf, Inf],
        gdd5 = [-Inf, Inf],
        gdd0 = [-Inf, Inf],
        twm = [-Inf, 15.0],
        maxdepth = [-Inf, Inf],
    ), dominance_factor = 1))
    @test niche_predictors(one_sided_pft) == (:tcm, :twm)
    @test fitness_value(one_sided_pft, 10.0) == 1.0                  # outside both zones
    @test fitness_value(one_sided_pft, 15.0) ≈ exp(-2.0)             # at the twm bound

    # Custom one-sided predictor without a natural limit: presence filter only
    custom_one_sided = FitnessMockPFT(PFTCharacteristics(constraints = (
        moisture = [0.0, Inf], swb = [-Inf, Inf],
    )))
    @test niche_predictors(custom_one_sided) == ()
    @test dominance_environment_mv(custom_one_sided; moisture = 0.0) == 1.0
end
