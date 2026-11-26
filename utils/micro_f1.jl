# =============================================================================
# Master script — reproduces Table 2 (micro-F1 and per-class F1) for
#   ground truth  ∈ {GLCNMO, RESOLVE}
#   grouping      ∈ {Tree/Grass, Forest types (GLCNMO) / Biome types (RESOLVE)}
#   resolution    ∈ {0.5° global (55 km), 30" continental (1 km Europe)}
#   model         ∈ {BIOME4 with dominance-based competition, BIOME4}
#
# Conventions:
#   * micro-F1 is computed over ALL classes of a grouping, including "Other"
#     where the grouping has one (Tree/Grass, GLCNMO forest types). For single-
#     label multiclass data micro-F1 == overall accuracy.
#   * Per-class F1 = 2·TP / (2·TP + FP + FN), reported for the named classes.
#   * A class with no ground-truth cells in the domain is reported "Not tested".
#   * Both models are evaluated on the SAME set of cells (common mask).
#
# Output: printed table + CSV (micro_f1_master_table.csv).
# Run:    julia micro_f1_master_table.jl
# =============================================================================

using Rasters
import ArchGDAL
import NCDatasets
using Printf

const KS = "/lud11/lechartr/kappa_statistics"

# =============================================================================
# Files (same as the plotting script)
# =============================================================================
const FILES = Dict(
    # ---- 0.5° global ---------------------------------------------------------
    :global => (
        biome4       = ("$KS/55km/output_biome4.nc",                    "biome"),
        dominance    = ("$KS/55km/output_BIOME4_new_dominance.nc",      "biome"),
        glcnmo_all   = ("$KS/55km/ground_truth_glcnmo_all_categories_55km.nc", "Band1"),
        glcnmo_tg    = ("$KS/55km/ground_truth_glcnmo_tree_grass_55k.nc", "Band1"),
        resolve      = ("$KS/55km/ecoregions_global_55km_remapped.nc",  "Band1"),
        landmask     = ("$KS/output_Wissmann.nc",                       "climate_zone"),
    ),
    # ---- 30" Europe ----------------------------------------------------------
    :europe => (
        biome4       = ("$KS/1km/new/output_biome4_1km_europe_filled_int16.nc",        "Band1"),
        dominance    = ("$KS/1km/new/output_biomedominance_1km_europe_1981-2010_raw.nc", "biome"),
        glcnmo_all   = ("$KS/1km/glncmo/ground_truth_glcnmo_all_categories_europe.nc", "Band1"),
        glcnmo_tg    = ("$KS/1km/glncmo/ground_truth_clcnmo_grass_tree_shrubs2_europe_remapped.nc", "Band1"),
        resolve      = ("$KS/1km/new/ecoregions_europe_1km_remapped.nc",               "Band1"),
        landmask     = ("$KS/1km/new/output_biome4_1km_europe_filled_int16.nc",        "Band1"),  # BIOME4 extent
    ),
)

# =============================================================================
# Loading — returns an Int16 matrix (X, Y) with -9999 for missing/fill,
# oriented like the reference grid (Y flipped if needed).
# =============================================================================
const NODATA = Int16(-9999)

function load_int(path::AbstractString, var::AbstractString; ref=nothing)
    r  = Raster(path; name=var, lazy=false)
    r  = permutedims(r, (X, Y))
    mv = missingval(r)
    A  = Array(read(r))
    out = Matrix{Int16}(undef, size(A))
    @inbounds for i in eachindex(A)
        v = A[i]
        if ismissing(v) || (mv !== nothing && !ismissing(mv) && v == mv)
            out[i] = NODATA
        else
            f = Float64(v)
            out[i] = (isnan(f) || abs(f) > 1e6) ? NODATA : Int16(round(f))
        end
    end
    xs = collect(lookup(r, X)); ys = collect(lookup(r, Y))
    if ref !== nothing
        rxs, rys = ref
        size(out) == (length(rxs), length(rys)) ||
            error("Grid size mismatch: $path $(size(out)) vs reference $((length(rxs), length(rys)))")
        if !isapprox(xs, rxs; atol=1e-3)
            if isapprox(reverse(xs), rxs; atol=1e-3)
                out = out[end:-1:1, :]; xs = reverse(xs)
            else
                error("X coordinates differ: $path")
            end
        end
        if !isapprox(ys, rys; atol=1e-3)
            if isapprox(reverse(ys), rys; atol=1e-3)
                out = out[:, end:-1:1]; ys = reverse(ys)
            else
                error("Y coordinates differ: $path")
            end
        end
    end
    return out, (xs, ys)
end

# =============================================================================
# Reclassification schemes
# =============================================================================

# ---- Tree / Grass (1 = Tree, 2 = Grass/Shrub, 3 = Other) ---------------------
const TG_TREE_BIOMES  = Set([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 15, 17, 18])
const TG_GRASS_BIOMES = Set([12, 13, 14, 16, 19, 20, 22, 23, 24, 25])
tg_biome(v) = v in TG_TREE_BIOMES ? 1 : v in TG_GRASS_BIOMES ? 2 : 3

# GLCNMO tree/grass ground truth: 1 = tree, 2 = grass/shrub, anything else = other
tg_glcnmo(v) = v == 1 ? 1 : v == 2 ? 2 : 3

# RESOLVE ecoregions → tree/grass
#  trees : 1-6 forests, 12 Mediterranean forests/woodlands, 14 mangroves
#  grass : 7-10 grasslands/savannas/shrublands, 11 tundra
#  other : 13 deserts & xeric shrublands
const TG_ECO_TREE  = Set([1, 2, 3, 4, 5, 6, 12, 14])
const TG_ECO_GRASS = Set([7, 8, 9, 10, 11])
tg_resolve(v) = v in TG_ECO_TREE ? 1 : v in TG_ECO_GRASS ? 2 : 3

const TG_LABELS = ["Tree", "Grass/shrub", "Other"]
const TG_REPORT = [1, 2]

# ---- GLCNMO forest types (1 BEF, 2 BDF, 3 NEF, 4 NDF, 5 Mixed, 6 Other) ------
# Same groupings as reclassify_biome_foresttype in the plotting script;
# grass (6) and non-forest land (255) are merged into "Other".
const BEFBIOMES         = Set([1])
const BDFBIOMES         = Set([2, 3, 4])
const NEFBIOMES         = Set([5, 8, 10])
const NDFBIOMES         = Set([11])
const MIXEDFORESTBIOMES = Set([6, 7, 9])
ft_biome(v) = v in BEFBIOMES ? 1 : v in BDFBIOMES ? 2 : v in NEFBIOMES ? 3 :
              v in NDFBIOMES ? 4 : v in MIXEDFORESTBIOMES ? 5 : 6
ft_glcnmo(v) = 1 <= v <= 5 ? Int(v) : 6

const FT_LABELS = ["Broadleaf evergreen", "Broadleaf deciduous", "Needleleaf evergreen",
                   "Needleleaf deciduous", "Mixed forest", "Other"]
const FT_REPORT = [1, 2, 3, 4, 5]

# ---- RESOLVE biome types (plotting script ECOREGION_REMAP / BIOME4_REMAP) ----
const ECOREGION_REMAP = Dict(1=>1, 2=>1, 3=>1, 4=>2, 5=>2, 6=>2, 7=>3, 8=>4, 9=>3,
                             10=>4, 11=>5, 12=>2, 13=>6, 14=>0)
const BIOME4_REMAP = Dict(1=>1, 2=>1, 3=>1, 4=>2, 5=>2, 6=>2, 7=>2, 8=>2, 9=>2, 10=>2, 11=>2,
                          12=>3, 13=>4, 14=>4, 15=>4, 16=>3, 17=>6, 18=>6, 19=>3, 20=>4, 21=>6,
                          22=>5, 23=>5, 24=>5, 25=>5, 26=>5, 27=>0, 28=>0)
bt_biome(v)   = get(BIOME4_REMAP, Int(v), 0)
bt_resolve(v) = get(ECOREGION_REMAP, Int(v), 0)

# Table order: Temperate/Broadleaf, Temp. grassland, Savanna, Tropical forest, Desert, Tundra
const BT_LABELS = ["Tropical forest", "Temperate/Broadleaf forest",
                   "Savanna and tropical grassland", "Temperate grassland and shrubland",
                   "Tundra", "Desert"]
const BT_REPORT = [2, 4, 3, 1, 6, 5]

# =============================================================================
# Metrics
# =============================================================================
function confusion(gt::AbstractVector{<:Integer}, pred::AbstractVector{<:Integer}, nclass::Int)
    C = zeros(Int, nclass, nclass)                 # rows = truth, cols = prediction
    @inbounds for i in eachindex(gt)
        C[gt[i], pred[i]] += 1
    end
    return C
end

function f1_scores(C::Matrix{Int})
    n  = size(C, 1)
    tp = [C[k, k] for k in 1:n]
    fp = [sum(C[:, k]) - C[k, k] for k in 1:n]
    fn = [sum(C[k, :]) - C[k, k] for k in 1:n]
    support = [sum(C[k, :]) for k in 1:n]
    perclass = [support[k] == 0 ? NaN :
                (2tp[k] + fp[k] + fn[k]) == 0 ? 0.0 : 2tp[k] / (2tp[k] + fp[k] + fn[k])
                for k in 1:n]
    micro = 2sum(tp) / (2sum(tp) + sum(fp) + sum(fn))   # == accuracy
    return micro, perclass, support
end

"""
Evaluate both models on the same cells.
  gt_raw, b4_raw, dom_raw : Int16 matrices
  domain                  : Bool matrix of cells to evaluate (before class filters)
  gt_f, pred_f            : functions raw code -> class index (0 = drop cell)
"""
function evaluate(gt_raw, b4_raw, dom_raw, domain, gt_f, pred_f, nclass)
    n = length(gt_raw)
    gt = zeros(Int8, n); b4 = zeros(Int8, n); dm = zeros(Int8, n)
    keep = falses(n)
    @inbounds for i in 1:n
        domain[i] || continue
        (gt_raw[i] == NODATA || b4_raw[i] == NODATA || dom_raw[i] == NODATA) && continue
        g = gt_f(gt_raw[i]); p = pred_f(b4_raw[i]); d = pred_f(dom_raw[i])
        (g == 0 || p == 0 || d == 0) && continue
        gt[i] = g; b4[i] = p; dm[i] = d; keep[i] = true
    end
    gtk = gt[keep]
    res_dom = f1_scores(confusion(gtk, dm[keep], nclass))
    res_b4  = f1_scores(confusion(gtk, b4[keep], nclass))
    return (dominance = res_dom, biome4 = res_b4, ncells = count(keep))
end

# =============================================================================
# Run all combinations
# =============================================================================
results = Dict{Tuple{Symbol,Symbol},Any}()   # (block, scale) => evaluate() output

for scale in (:global, :europe)
    F = FILES[scale]
    println("\n=== Loading $(scale) ===")
    b4,  grid = load_int(F.biome4...)
    dom, _    = load_int(F.dominance...;  ref=grid)
    lm,  _    = load_int(F.landmask...;   ref=grid)
    land      = (lm .!= NODATA) .& (lm .!= 0)
    valid_b   = (b4 .>= 1) .& (b4 .<= 28)

    # --- GLCNMO --------------------------------------------------------------
    gl_tg, _  = load_int(F.glcnmo_tg...;  ref=grid)
    results[(:glcnmo_tg, scale)] = evaluate(gl_tg, b4, dom, land .& valid_b, tg_glcnmo, tg_biome, 3)
    gl_tg = nothing

    gl_all, _ = load_int(F.glcnmo_all...; ref=grid)
    results[(:glcnmo_ft, scale)] = evaluate(gl_all, b4, dom, land .& valid_b, ft_glcnmo, ft_biome, 6)
    gl_all = nothing

    # --- RESOLVE -------------------------------------------------------------
    res, _    = load_int(F.resolve...;    ref=grid)
    results[(:resolve_tg, scale)] = evaluate(res, b4, dom, valid_b, tg_resolve, tg_biome, 3)
    results[(:resolve_bt, scale)] = evaluate(res, b4, dom, valid_b, bt_resolve, bt_biome, 6)
    res = nothing; b4 = nothing; dom = nothing
    GC.gc()
end

# =============================================================================
# Print Table 2 + write CSV
# =============================================================================
const BLOCKS = [
    ("GLCNMO",  "Tree/Grass",   :glcnmo_tg,  TG_LABELS, TG_REPORT),
    ("GLCNMO",  "Forest types", :glcnmo_ft,  FT_LABELS, FT_REPORT),
    ("RESOLVE", "Tree/Grass",   :resolve_tg, TG_LABELS, TG_REPORT),
    ("RESOLVE", "Biome types",  :resolve_bt, BT_LABELS, BT_REPORT),
]

fmt(x) = isnan(x) ? "Not tested" : @sprintf("%.2f", x)

rows = Vector{Vector{String}}()
for (gtname, grouping, key, labels, report) in BLOCKS
    rg, re = results[(key, :global)], results[(key, :europe)]
    push!(rows, [gtname, grouping, "", "microF1",
                 fmt(rg.dominance[1]), fmt(rg.biome4[1]), fmt(re.dominance[1]), fmt(re.biome4[1])])
    for k in report
        push!(rows, [gtname, grouping, labels[k], "Per-class F1",
                     fmt(rg.dominance[2][k]), fmt(rg.biome4[2][k]),
                     fmt(re.dominance[2][k]), fmt(re.biome4[2][k])])
    end
end

header = ["Ground truth", "Grouping", "Class", "Metric",
          "Global_Dominance", "Global_BIOME4", "Europe_Dominance", "Europe_BIOME4"]

println("\n", "="^118)
println("Table 2 — microF1 and per-class F1")
println("="^118)
@printf("%-8s %-13s %-34s %-13s | %-12s %-12s | %-12s %-12s\n",
        "GT", "Grouping", "Class", "Metric", "Glob Dom", "Glob BIOME4", "Eur Dom", "Eur BIOME4")
println("-"^118)
for r in rows
    @printf("%-8s %-13s %-34s %-13s | %-12s %-12s | %-12s %-12s\n", r...)
end
println("-"^118)
println("Cells evaluated (global / Europe):")
for (gtname, grouping, key, _, _) in BLOCKS
    @printf("  %-8s %-13s %10d / %d\n", gtname, grouping,
            results[(key, :global)].ncells, results[(key, :europe)].ncells)
end

csvfile = "$KS/micro_f1_master_table.csv"
open(csvfile, "w") do io
    println(io, join(header, ","))
    for r in rows
        println(io, join(map(s -> occursin(',', s) ? "\"$s\"" : s, r), ","))
    end
end
println("\nWritten: $csvfile")
