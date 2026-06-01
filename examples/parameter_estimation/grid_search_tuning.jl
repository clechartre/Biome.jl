"""
Grid likelihood diagnostic for BorealEvergreen.

For each (param1, delta1) on a GRID_N×GRID_N grid, computes:
  - Fraction of correctly predicted pixels (accuracy proxy)
  - Log-likelihood: Σᵢ [ yᵢ·log(p) + (1−yᵢ)·log(1−p) ]
    where p = SOFT_PROB_CORRECT if pred==obs, else 1−SOFT_PROB_CORRECT

Outputs:
  - grid_loglik_BorealEvergreen.png       : log-likelihood surface
  - grid_accuracy_BorealEvergreen.png     : accuracy surface
  - profile_ll_param1_BorealEvergreen.png : profile likelihood over GDD5_low
  - grid_results_BorealEvergreen.jls      : serialised matrices for downstream reuse
"""

using Biome
using Rasters
using Distributions
using Serialization
using Statistics
using CairoMakie
using Base.Threads
using Random
using StatsBase

# CONSTANTS

const GROUNDTRUTH_PATH       = ""
const ELEVATION_PATH         = ""
const TEMP_PATH              = ""
const PREC_PATH              = ""
const CLT_PATH               = ""
const WHC_PATH               = ""
const KSAT_PATH              = ""
const OUTDIR                 = ""

const BOREAL_EVERGREEN_PFT_IDX = 1

const SOFT_PROB_CORRECT      = 0.85
const PRES_OVERSAMPLE_FACTOR = 5.0
const ELEV_HARD_CUTOFF       = 1300.0
const ELEV_UPPER_CUTOFF      = 2800.0
const N_ELEV_BINS            = 20
const N_PER_BIN              = 40

const GRID_N                 = 100
const PARAM1_RANGE           = range(100.0,  1800.0; length=GRID_N)
const DELTA1_RANGE           = range(50.0,   2000.0; length=GRID_N)

# DATA STRUCTURES

struct BiomeInputs
    temp::Raster
    prec::Raster
    clt::Raster
    ksat::Raster
    whc::Raster
end

# DATA LOADING

function load_inputs()::BiomeInputs
    temp = Raster(TEMP_PATH, name="tas")
    prec = Raster(PREC_PATH, name="pr")
    clt  = Raster(CLT_PATH,  name="clt")
    ksat = Raster(KSAT_PATH, name="Ksat")
    whc  = Raster(WHC_PATH,  name="whc")

    BiomeInputs(temp, prec, clt, ksat, whc)
end

# PIXEL HELPERS

function extract_pixel_timeseries(r::Raster, i::Int, j::Int)
    data = r[i, j, :]
    reshape(data, 1, 1, :)
end

is_valid_series(x)      = !(any(ismissing, x[1,1,:]) ||
                             any(v -> !ismissing(v) && v == -9999, x[1,1,:]))
is_valid_groundtruth(v) = !(ismissing(v) ||
                             (v isa AbstractFloat && isnan(v)) ||
                             v == -9999)
gt_to_binary(v)::Int    = v == 0 ? 0 : 1

# ELEVATION-STRATIFIED ECOTONE SAMPLING
"""
Since we don't want to sample all the points available, we bin 
them into elevation bins and sample only a subset of them. 
"""
function stratified_ecotone_sample(y, ij_pairs, elevation;
                                   rng=Random.default_rng())
    @assert length(y) == length(ij_pairs) == length(elevation)

    in_window = findall(e -> ELEV_HARD_CUTOFF <= e <= ELEV_UPPER_CUTOFF, elevation)
    y_w    = y[in_window]
    ij_w   = ij_pairs[in_window]
    elev_w = elevation[in_window]

    @info "Ecotone window [$(ELEV_HARD_CUTOFF), $(ELEV_UPPER_CUTOFF)] m: " *
          "$(length(y_w)) pixels " *
          "(presence=$(count(==(1), y_w))  absence=$(count(==(0), y_w)))"

    bin_edges = range(ELEV_HARD_CUTOFF, ELEV_UPPER_CUTOFF; length=N_ELEV_BINS + 1)
    selected  = Int[]

    for b in 1:N_ELEV_BINS
        lo, hi  = bin_edges[b], bin_edges[b + 1]
        in_bin  = b < N_ELEV_BINS ?
            findall(e -> lo <= e < hi,  elev_w) :
            findall(e -> lo <= e <= hi, elev_w)

        isempty(in_bin) && continue

        pres_idx = filter(i -> y_w[i] == 1, in_bin)
        abs_idx  = filter(i -> y_w[i] == 0, in_bin)

        if isempty(pres_idx)
            n_take = min(length(abs_idx), N_PER_BIN)
            append!(selected, sample(rng, abs_idx, n_take; replace=false))
            @info "  bin $b [$(round(Int,lo))–$(round(Int,hi)) m]: " *
                  "absence-only → $n_take absences sampled"
        else
            n_total            = length(in_bin)
            pres_ratio         = length(pres_idx) / n_total
            boosted_pres_ratio = min(pres_ratio * PRES_OVERSAMPLE_FACTOR, 1.0)
            n_take_pres        = clamp(round(Int, N_PER_BIN * boosted_pres_ratio),
                                       0, length(pres_idx))
            n_take_abs         = clamp(N_PER_BIN - n_take_pres, 0, length(abs_idx))
            n_take_pres > 0 && append!(selected, sample(rng, pres_idx, n_take_pres; replace=false))
            n_take_abs  > 0 && append!(selected, sample(rng, abs_idx,  n_take_abs;  replace=false))
            @info "  bin $b [$(round(Int,lo))–$(round(Int,hi)) m]: " *
                  "mixed → $n_take_pres presences + $n_take_abs absences"
        end
    end

    unique!(selected)

    @info "Stratified ecotone sample: $(length(selected)) pixels " *
          "(presence=$(count(i -> y_w[i]==1, selected))  " *
          "absence=$(count(i -> y_w[i]==0, selected)))"

    return y_w[selected], ij_w[selected], elev_w[selected]
end

# DATA PREPARATION
Random.seed!(127)

@info "Loading inputs..."
const _inputs = load_inputs()

const _groundtruthflat = vec(Raster(GROUNDTRUTH_PATH, name="Band1"))

const _dims_lon    = dims(_inputs.temp, X)
const _dims_lat    = dims(_inputs.temp, Y)
const _nlon, _nlat = length(_dims_lon), length(_dims_lat)
const _ij_grid     = [Tuple(I) for I in CartesianIndices((_nlon, _nlat))]

const _valid_gt_idx = findall(is_valid_groundtruth, _groundtruthflat)
const _y_all        = Int[gt_to_binary(_groundtruthflat[k]) for k in _valid_gt_idx]
const _ij_pairs_all = _ij_grid[_valid_gt_idx]

@info "Valid GT pixels: $(length(_y_all)) " *
      "(absence=$(count(==(0),_y_all)) presence=$(count(==(1),_y_all)))"

const _elevation_raw_raster = Raster(ELEVATION_PATH)
const _elevation_resampled  = resample(_elevation_raw_raster; to=_inputs.temp, method=:bilinear)
const _elevation_raw        = vec(_elevation_resampled)[_valid_gt_idx]

const _elev_ok = findall(e -> !ismissing(e) && e != -9999, _elevation_raw)

const _y_elev        = _y_all[_elev_ok]
const _ij_elev       = _ij_pairs_all[_elev_ok]
const _elevation_all = Float64.(_elevation_raw[_elev_ok])

@info "Valid GT pixels after elevation QC: $(length(_y_elev))"

const _y_sub, _ij_sub, _elev_sub = stratified_ecotone_sample(
    _y_elev, _ij_elev, _elevation_all)

@info "Extracting climate for sampled pixels..."
const _temp_vec_sub = [extract_pixel_timeseries(_inputs.temp, i, j) for (i,j) in _ij_sub]
const _prec_vec_sub = [extract_pixel_timeseries(_inputs.prec, i, j) for (i,j) in _ij_sub]
const _clt_vec_sub  = [extract_pixel_timeseries(_inputs.clt,  i, j) for (i,j) in _ij_sub]
const _ksat_vec_sub = [extract_pixel_timeseries(_inputs.ksat, i, j) for (i,j) in _ij_sub]
const _whc_vec_sub  = [extract_pixel_timeseries(_inputs.whc,  i, j) for (i,j) in _ij_sub]

const _usable = findall(i ->
    is_valid_series(_temp_vec_sub[i]) &&
    is_valid_series(_prec_vec_sub[i]) &&
    is_valid_series(_clt_vec_sub[i]),
    eachindex(_y_sub))

const Y_GRID    = _y_sub[_usable]
const TEMP_GRID = _temp_vec_sub[_usable]
const PREC_GRID = _prec_vec_sub[_usable]
const CLT_GRID  = _clt_vec_sub[_usable]
const KSAT_GRID = _ksat_vec_sub[_usable]
const WHC_GRID  = _whc_vec_sub[_usable]
const N_GRID    = length(Y_GRID)

@info "After climate QC: $N_GRID pixels " *
      "($(count(==(0), Y_GRID)) zeros / $(count(==(1), Y_GRID)) ones)"
@assert N_GRID > 0 "No usable samples after subsampling"

# FORWARD MODEL
function runmodel_pixel(temp, prec, clt, ksat, whc,
                        param1::Float64, param2::Float64)::Bool
    PFTList = BIOME4.PFTClassification()
    set_characteristic!(PFTList, "BorealEvergreen", :gdd5, [param1, param2])

    lon_r = [0.0]; lat_r = [0.0]
    T  = size(temp, 3); Ts = size(ksat, 3)

    temp_r = Raster(temp, dims=(X(lon_r), Y(lat_r), Ti(1:T)),  name="tas")
    prec_r = Raster(prec, dims=(X(lon_r), Y(lat_r), Ti(1:T)),  name="pr")
    clt_r  = Raster(clt,  dims=(X(lon_r), Y(lat_r), Ti(1:T)),  name="clt")
    ksat_r = Raster(ksat, dims=(X(lon_r), Y(lat_r), Ti(1:Ts)), name="Ksat")
    whc_r  = Raster(whc,  dims=(X(lon_r), Y(lat_r), Ti(1:Ts)), name="whc")

    setup = ModelSetup(BIOME4Model();
        temp=temp_r, prec=prec_r, clt=clt_r, ksat=ksat_r, whc=whc_r,
        co2=373.8, pftlist=PFTList)

    output = execute(setup;
                     pft_parametrization=true)

    return Bool(output[:pft_present][BOREAL_EVERGREEN_PFT_IDX])
end

# GRID EVALUATION
loglik_grid   = fill(NaN, GRID_N, GRID_N)
accuracy_grid = fill(NaN, GRID_N, GRID_N)

total_points = GRID_N * GRID_N
counter      = Threads.Atomic{Int}(0)

@info "Starting grid evaluation: $(GRID_N)×$(GRID_N) = $total_points points " *
      "on $(Threads.nthreads()) threads"

t_start = time()

Threads.@threads for idx in 1:total_points
    ip = (idx - 1) ÷ GRID_N + 1
    id = (idx - 1) % GRID_N + 1

    p1 = PARAM1_RANGE[ip]
    d1 = DELTA1_RANGE[id]
    p2 = p1 + d1

    ll  = 0.0
    acc = 0

    for i in 1:N_GRID
        pred    = runmodel_pixel(TEMP_GRID[i], PREC_GRID[i], CLT_GRID[i],
                                 KSAT_GRID[i], WHC_GRID[i], p1, p2)
        correct = (Int(pred) == Y_GRID[i])
        prob    = correct ? SOFT_PROB_CORRECT : (1.0 - SOFT_PROB_CORRECT)
        ll     += log(clamp(prob, 1e-6, 1.0 - 1e-6))
        acc    += Int(correct)
    end

    loglik_grid[ip, id]   = ll
    accuracy_grid[ip, id] = acc / N_GRID

    c = Threads.atomic_add!(counter, 1) + 1
    if c % 500 == 0
        elapsed = time() - t_start
        rate    = c / elapsed
        eta     = (total_points - c) / rate
        @info "  $c / $total_points  ($(round(rate; digits=1)) pts/s, " *
              "ETA $(round(Int, eta)) s)"
    end
end

@info "Grid evaluation complete in $(round(time() - t_start; digits=1)) s"

# SAVE RAW RESULTS
results = (;
    param1_range  = collect(PARAM1_RANGE),
    delta1_range  = collect(DELTA1_RANGE),
    loglik_grid,
    accuracy_grid,
    y = Y_GRID,
    n = N_GRID)

serialize(joinpath(OUTDIR, "grid_results_BorealEvergreen.jls"), results)
@info "Raw grid results saved."

# IDENTIFY OPTIMUM
best_idx = argmax(loglik_grid)
best_p1  = PARAM1_RANGE[best_idx[1]]
best_d1  = DELTA1_RANGE[best_idx[2]]
best_ll  = loglik_grid[best_idx]
best_acc = accuracy_grid[best_idx]

@info "MAP estimate: param1 = $(round(best_p1; digits=1))  " *
      "delta1 = $(round(best_d1; digits=1))  " *
      "(GDD5_hi = $(round(best_p1 + best_d1; digits=1)))  " *
      "loglik = $(round(best_ll; digits=2))  " *
      "accuracy = $(round(100*best_acc; digits=1))%"

# PROFILE LIKELIHOOD FOR param1  (marginalise over delta1)
profile_ll = vec(maximum(loglik_grid; dims=2))
threshold  = maximum(profile_ll) - 1.92   # χ²(1)/2 at 95%
ci_mask    = profile_ll .>= threshold
ci_lo      = PARAM1_RANGE[findfirst(ci_mask)]
ci_hi      = PARAM1_RANGE[findlast(ci_mask)]

@info "param1 profile CI (95%): [$(round(ci_lo; digits=1)), $(round(ci_hi; digits=1))] degree-days"

# PLOT
CairoMakie.set_theme!(fontsize=18, font="Times New Roman")

function make_heatmap(zmat, param1_range, delta1_range, title_str,
                      colormap, best_ip, best_id, outpath)
    fig = Figure(size=(900, 720), backgroundcolor=:white)
    ax  = Axis(fig[1, 1];
        title          = title_str,
        xlabel         = "GDD5_low  (param1, degree-days)",
        ylabel         = "δ  (delta1, degree-days)",
        xticklabelfont = "Times New Roman",
        yticklabelfont = "Times New Roman")

    hm = heatmap!(ax, param1_range, delta1_range, zmat; colormap=colormap)
    Colorbar(fig[1, 2], hm; width=18)

    scatter!(ax, [param1_range[best_ip]], [delta1_range[best_id]];
             color=:white, strokecolor=:black,
             strokewidth=2.5, markersize=18, marker=:star5)

    save(outpath, fig)
    @info "Saved: $outpath"
end

make_heatmap(loglik_grid,
             collect(PARAM1_RANGE), collect(DELTA1_RANGE),
             "Log-likelihood surface — BorealEvergreen\n(param1 = GDD5_low,  param2 = param1 + δ)",
             :viridis,
             best_idx[1], best_idx[2],
             joinpath(OUTDIR, "grid_loglik_BorealEvergreen.png"))

make_heatmap(accuracy_grid,
             collect(PARAM1_RANGE), collect(DELTA1_RANGE),
             "Accuracy surface — BorealEvergreen",
             :magma,
             best_idx[1], best_idx[2],
             joinpath(OUTDIR, "grid_accuracy_BorealEvergreen.png"))

# Profile likelihood plot 
fig_prof = Figure(size=(800, 480), backgroundcolor=:white)
ax_prof  = Axis(fig_prof[1, 1];
    xlabel = "GDD5_low  (param1, degree-days)",
    ylabel = "Profile log-likelihood",
    title  = "Profile likelihood — BorealEvergreen")

lines!(ax_prof, collect(PARAM1_RANGE), profile_ll;
       color=:black, linewidth=2.5)
hlines!(ax_prof, [threshold];
        color=:gray, linestyle=:dash, linewidth=1.5,
        label="95% threshold (−1.92)")
scatter!(ax_prof, [PARAM1_RANGE[argmax(profile_ll)]], [maximum(profile_ll)];
         color=:white, strokecolor=:black, strokewidth=2, markersize=14)
vlines!(ax_prof, [ci_lo, ci_hi];
        color=:steelblue, linestyle=:dot, linewidth=1.5)
axislegend(ax_prof; framevisible=false)

save(joinpath(OUTDIR, "profile_ll_param1_BorealEvergreen.png"), fig_prof)
@info "Saved: profile_ll_param1_BorealEvergreen.png"