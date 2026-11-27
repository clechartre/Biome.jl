#!/bin/sh
# Run the original Fortran BIOME4 and Biome.jl on identical inputs and compare them.
# Needs gfortran, git and Julia. Run from the repository root:
#   sh benchmark/fortran_equivalence/run.sh [climatology dir]
set -e
here=benchmark/fortran_equivalence
clim=${1:-data_biome4py/generated_data/climatologies}
work=$here/work
commit=4ad9dff   # BIOME4 master, Nov 2025 (Kaplan's bug fixes)
mkdir -p $work

# 1. Fortran BIOME4, compiled with our driver
[ -d $work/BIOME4 ] || git clone -q https://github.com/jedokaplan/BIOME4.git $work/BIOME4
git -C $work/BIOME4 checkout -q $commit
gfortran -O2 -std=legacy $work/BIOME4/biome4.f $here/biome4_driver.f90 -o $work/biome4_driver

# 2. Shared inputs
julia --project=. $here/build_inputs.jl $clim $work

# 3. Run both models (Fortran is single-threaded)
echo "Fortran BIOME4, 1 thread:"
/usr/bin/time -p $work/biome4_driver $work $work/fortran.f32
julia --project=. -t 1 $here/run_biomejl.jl $work $work/biomejl.f32
julia --project=. -t auto $here/run_biomejl.jl $work $work/biomejl_threads.f32

# 4. Compare
julia --project=. $here/compare.jl $work $work/fortran.f32 $work/biomejl.f32
