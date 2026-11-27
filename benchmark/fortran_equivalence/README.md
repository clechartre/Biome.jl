# Biome.jl vs the original Fortran BIOME4

This benchmark runs two models on the same global 0.5° inputs:

- the original Fortran BIOME4 (Kaplan, https://github.com/jedokaplan/BIOME4, commit `4ad9dff`, Nov 2025);
- the Biome.jl `BIOME4Model`.

It compares them cell by cell and times both.

## Run

Run it from the repository root. It needs `gfortran`, `git` and Julia.

```sh
sh benchmark/fortran_equivalence/run.sh [climatology dir]
```

The climatology directory defaults to `data_biome4py/generated_data/climatologies`. It must contain:

- `temp_1981-2010.nc`;
- `prec_1981-2010.nc`;
- `sun_1981-2010.nc`, which holds cloud cover in %;
- `soils_55km.nc`.

Every cell uses CO2 = 324 ppm and sea-level pressure. All outputs go to `work/`, which git ignores.

## Files

| File | Role |
|---|---|
| `run.sh` | Clones and compiles BIOME4, then runs every step below. |
| `build_inputs.jl` | Writes the BIOME4 input vector (`vars_in`, 50 values) and the 6-layer soil for each land cell. |
| `biome4_driver.f90` | Calls the unmodified Fortran `biome4` subroutine on each cell. |
| `run_biomejl.jl` | Runs Biome.jl on each cell, following the same steps as `Biome.runmodel`. |
| `compare.jl` | Reports biome agreement and NPP/LAI agreement for each PFT. |

Both models write 27 Float32 values per cell: the biome, the NPP of the 13 PFTs and the LAI of the 13 PFTs. `compare.jl` rounds NPP to 1 gC m⁻² yr⁻¹ and LAI to 0.01 before comparing.

## Results (27 Nov 2026)

These results come from 60,036 land cells, 1981–2010 climate.

**Biome:** the two models assign the same biome in 99.82% of cells (111 differ).

- 110 of the 111 differing cells differ only through the tropical evergreen PFT. Biome.jl runs it, while the Fortran switches it off. In 62 of these cells, hyper-arid tropical land becomes desert instead of barren.
- The remaining cell is a temperate deciduous forest in Fortran and a temperate grassland in Biome.jl. Its largest NPP difference is 0.2 gC m⁻² yr⁻¹.

**Per-PFT NPP and LAI:** for each PFT, the table gives the share of cells with identical values after rounding and the correlation between the two models.

| PFT | Cells | NPP identical | NPP r | LAI identical | LAI r |
|---|---|---|---|---|---|
| Tropical evergreen | 15790 | present in Biome.jl only | | | |
| Tropical drought-deciduous | 13534 | 99.91% | 1.0000 | 99.31% | 1.0000 |
| Temperate broadleaved evergreen | 10244 | 99.97% | 1.0000 | 99.85% | 1.0000 |
| Temperate summergreen | 15010 | 99.89% | 1.0000 | 99.82% | 1.0000 |
| Cool conifer | 21757 | 99.93% | 1.0000 | 99.83% | 1.0000 |
| Boreal evergreen | 19850 | 99.96% | 1.0000 | 99.86% | 1.0000 |
| Boreal deciduous | 25098 | 99.96% | 1.0000 | 99.75% | 1.0000 |
| C3/C4 temperate grass | 29627 | 99.96% | 1.0000 | 99.67% | 1.0000 |
| C4 tropical grass | 15316 | 99.99% | 1.0000 | 99.10% | 1.0000 |
| Woody desert | 42702 | 99.98% | 1.0000 | 99.84% | 1.0000 |
| Tundra shrub | 12313 | 99.17% | 1.0000 | 99.72% | 1.0000 |
| Cold herbaceous | 13169 | 99.14% | 1.0000 | 99.61% | 1.0000 |
| Lichen/forb | 14353 | 96.04% | 1.0000 | 98.42% | 0.9999 |

The remaining mismatches are small:

- **Tree and grass PFTs:** NPP differs by at most 1.5 gC m⁻² yr⁻¹.
- **Tundra PFTs:** NPP differs by up to 7 gC m⁻² yr⁻¹ (in 442 of about 40,000 PFT-cells), and lichen/forb shows most of these.
- **LAI:** it differs by at most 0.19, in under 0.3% of cells for each PFT.

These differences are consistent with single-precision arithmetic done in a different order in the two codes. That order can shift which LAI the optimisation picks when two LAI values give nearly the same NPP. The tundra cases have not been traced individually.

**Runtime:** measured on an Apple M3 Pro with gfortran 15.2 (`-O2`) and Julia 1.10.5.

| Model | Threads | Time per cell |
|---|---|---|
| Fortran BIOME4 | 1 | 2.4 ms |
| Biome.jl | 1 | 4.6 ms |
| Biome.jl | 5 | 1.4 ms |

## Biome.jl changes to match BIOME4

Biome.jl includes the bug fixes Kaplan made to the Fortran in Nov 2025:

- growth respiration uses the same month's terms;
- three hydrology guards;
- competition considers grass only when grass NPP > 0.

It also corrects three porting errors:

- the woody-desert `tune` value in `c4photo`;
- the subdominant-PFT check in `competition`;
- fire and green days taken at the optimal LAI in `findnpp`.
