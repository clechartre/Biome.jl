# Custom mechanistic model setup

If you want to build your own mechanistic vegetation model, the package is designed to let you replace the PFT set and the competition logic without rewriting the whole BIOME-style pipeline.

The workflow is:

1. Build a `PFTClassification` with your own PFTs.
2. Add and tighten constraints for each PFT with `add_constraint!` and `set_characteristic!`.
3. Define a custom model subtype `MyModel <: MechanisticModel`.
4. Define a custom `competition` method and, if needed, a custom `runmodel` method for that model.
    - If you want to only add PFTs but fallback to the model's original competition module, don't forget to add the `else return Biome.assign_biome ...` (see below)
5. Pass your custom PFT list to `ModelSetup` and run `execute`.

This gives you a clean way to test a new vegetation scheme while reusing the climate preprocessing, phenology, growth, and biome assignment infrastructure already in the package.

---

## 1) Defining your own PFTs

The foundation is a PFT list. You can start from the generic built-ins and then customize them in place.

```julia
using Biome
using Rasters

pfts = PFTClassification([
    BroadleafEvergreenPFT(
        name = "TropicalEvergreen",
        c4 = false,
        phenological_type = 1,
        constraints = (
            tcm = [-Inf, +Inf],
            tmin = [8.0, +Inf],
            gdd5 = [1500.0, +Inf],
            gdd0 = [600.0, +Inf],
            twm = [12.0, +Inf],
            maxdepth = [-Inf, +Inf],
            swb = [0.0, 100.0]
        ),
        dominance_factor = 2,
        minimum_lai = 1.0
    ),
    C4GrassPFT(
        name = "DryC4Grass",
        c4 = true,
        phenological_type = 3,
        constraints = (
            tcm = [-Inf, +Inf],
            tmin = [0.0, +Inf],
            gdd5 = [400.0, +Inf],
            gdd0 = [0.0, +Inf],
            twm = [10.0, +Inf],
            maxdepth = [-Inf, +Inf],
            swb = [0.0, 55.0]
        ),
        dominance_factor = 3,
        minimum_lai = 0.5
    )
])
```

You can also modify an existing PFT after construction:

```julia
set_characteristic!(pfts, "DryC4Grass", :Emax, 12.0)
set_characteristic!(pfts, "TropicalEvergreen", :gdd5, [1800.0, Inf])
```

And you can add new environmental filters to a PFT:

```julia
add_constraint!(pfts, "TropicalEvergreen", :sand_content, (0.0, 60.0))
```

This is useful when your model includes a custom variable such as a soil sand content, or anything you can pass as an additional raster.

---

## 2) Custom biome assignment

The standard `ModelSetup` workflow accepts a custom `biome_assignment` callback. This is the easiest way to map your own winning PFT to a new biome class.
Give your biome a numerical value for mapping later. You'll get a raster of integers you can map to a key. 

```julia
using Biome

# Biome definition - add a biome that includes this PFT
struct SavannaBiome  <: AbstractBiome
    value::Int
    SucculentBiome() = new(1000)
end

struct TropicalForestBiome <: AbstractBiome
    value::Int
    SucculentBiome() = new(1001)
end

function my_biome_assign(pft::AbstractPFT;
    subpft,
    wdom,
    gdd0,
    gdd5,
    tcm,
    tmin,
    pftlist,
    pftstates,
    gdom,
    env_variables)

    name = get_characteristic(pft, :name)

    if name == "TropicalEvergreen"
        return TropicalForestBiome()
    elseif name == "DryC4Grass"
        return SavannaBiome()
    else
        return Biome.assign_biome(
            pft;
            subpft=subpft,
            wdom=wdom,
            gdd0=gdd0,
            gdd5=gdd5,
            tcm=tcm,
            tmin=tmin,
            pftlist=pftlist,
            pftstates=pftstates,
            gdom=gdom,
            env_variables=env_variables
        )
    end
end
```

This allows your custom PFT list to produce its own biome identities without altering the rest of the mechanistic model machinery.

---

## 3) Defining a custom competition routine

The built-in competition step is implemented as a function called `competition` and is dispatched on the model type. To replace the default ranking logic, define a new model subtype and a custom method for `competition`.

```julia
using Biome
import Biome: competition

struct MyMechanisticModel <: MechanisticModel end

function competition(
    m::MyMechanisticModel,
    tmin::T,
    tpr::T,
    numofpfts::U,
    gdd0::T,
    gdd5::T,
    tcm::T,
    pftlist::AbstractPFTList,
    pftstates::Dict{AbstractPFT,PFTState},
    biome_assignment::Function,
    env_variables::NamedTuple
) where {T<:Real, U<:Int}

    winner = nothing
    best_score = -Inf

    for pft in pftlist.pft_list
        if !pftstates[pft].present || pftstates[pft].npp <= 0
            continue
        end

        score = pftstates[pft].npp * pftstates[pft].fitness / get_characteristic(pft, :dominance_factor)

        if score > best_score
            best_score = score
            winner = pft
        end
    end

    if winner === nothing
        return Biome.assign_biome(
            Default();
            subpft=NONE_INSTANCE,
            wdom=NONE_INSTANCE,
            gdd0=gdd0,
            gdd5=gdd5,
            tcm=tcm,
            tmin=tmin,
            pftlist=pftlist,
            pftstates=pftstates,
            gdom=DEFAULT_INSTANCE,
            env_variables=env_variables
        ), DEFAULT_INSTANCE, zero(T)
    end

    return biome_assignment(
        winner;
        subpft=NONE_INSTANCE,
        wdom=winner,
        gdom=DEFAULT_INSTANCE,
        gdd0=gdd0,
        gdd5=gdd5,
        tcm=tcm,
        tmin=tmin,
        pftlist=pftlist,
        pftstates=pftstates,
        env_variables=env_variables
    ), winner, best_score
end
```

This custom routine keeps the same overall model flow but changes the selection rule from the default BIOME-style logic to a simple weighted score based on NPP and fitness.

---

## 4) Running the custom model

Once the custom model and PFTs are defined, you can run them with the regular driver interface.

```julia
using Biome
using Rasters

# Example climate inputs
# tas_r  = Raster("tas.nc", name="tas")
# pr_r   = Raster("pr.nc", name="pr")
# clt_r  = Raster("clt.nc", name="clt")
# ksat_r = Raster("ksat.nc", name="Ksat")
# whc_r  = Raster("whc.nc", name="whc")

setup = ModelSetup(
    MyMechanisticModel();
    tas=tas_r,
    pr=pr_r,
    clt=clt_r,
    ksat=ksat_r,
    whc=whc_r,
    co2=378.0,
    pftlist=pfts,
    biome_assignment=my_biome_assign
)

execute(setup; outfile="output_custom_mechanistic.nc")
```

This is the same pattern used by the built-in mechanistic models, but with your own PFT definitions, fitness rules, and winner selection logic.

---

## 5) Practical advice

- Start from a minimal PFT set and a single custom rule.
- Keep `constraints` physically interpretable: temperature, growing degree days, soil moisture, and snow limits are easier to diagnose than a large opaque score.
- When building a custom competition function, log the best and second-best PFTs for a few test pixels to make sure your model behaves sensibly.
- If you are tuning the competition routine, keep the PFT-level productivity calculations unchanged and vary only the decision rule first; this isolates the effect of the competition step.

The package is intentionally modular here: the PFT list defines what can grow, while the competition routine defines who wins.

---

## 7) Summary

To set up your own mechanistic model:

- define a custom `PFTClassification`,
- modify PFT characteristics and constraints with `set_characteristic!` and `add_constraint!`,
- define a custom `biome_assignment`,
- add a `MyModel <: MechanisticModel` with custom `competition` and/or `runmodel` methods,
- then run it through `ModelSetup` and `execute`.

This is the recommended route when you want to explore a new ecological scheme without rewriting the climate and growth engine.
