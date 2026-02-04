"""
Getting started: Turing.jl parameter estimation on Biome.jl
(single PFT, multiple environmental thresholds, minimal diagnostics)
"""
# =============================================================================
# High-level idea
# -----------------------------------------------------------------------------
# - You have a binary "ground truth" raster (presence/absence of something).
# - You extract the climate time series for the same pixels where ground truth
#   is valid.
# - You define a Biome.jl model where the *thresholds* of a PFT are parameters.
# - Turing samples those thresholds, and for each proposed parameter set it:
#     (1) runs Biome.jl for each pixel (1×1×time),
#     (2) converts the predicted biome output into a Bernoulli probability,
#     (3) scores it against the observed label y[i].
# =============================================================================

using Biome
using Rasters
using UUIDs
using Turing, Distributions
using MCMCChains, Plots
using Random, Statistics
Random.seed!(957) # Fix RNG seed so sampling/repro steps are reproducible

# -------------------- Paths (edit these)
groundtruthpath = "path/to/ground_truth"  # or .nc etc
temp_path  = "path/to/temp.nc"
prec_path  = "path/to/prec.nc"
clt_path   = "path/to/clt.nc"
soils_path = "path/to/soils.nc"
outdir     = "path/to/outdir"

# -------------------- Ground truth -> y (0/1) + valid pixels
groundtruth = Raster(groundtruthpath, name="Band1")

# missing -> -9999, 0 -> 0, else -> 1
groundtruth = map(x -> ismissing(x) ? -9999 : (x == 0 ? 0 : 1), groundtruth)

# find valid pixels (in 2D grid)
dims_lon = dims(groundtruth, X)
dims_lat = dims(groundtruth, Y)
nlon, nlat = length(dims_lon), length(dims_lat)
ij_pairs = CartesianIndices((nlon, nlat))
valid_pairs = [Tuple(I) for I in ij_pairs if groundtruth[I] != -9999]

# y in the same order as valid_pairs
y = Int[groundtruth[i, j] for (i, j) in valid_pairs]
n = length(y)

# -------------------- Load climate inputs (shared grid)
temp_raster = Raster(temp_path,  name="temp")
prec_raster = Raster(prec_path,  name="prec")
clt_raster  = Raster(clt_path,   name="clt")
ksat_raster = Raster(soils_path, name="Ksat")
whc_raster  = Raster(soils_path, name="whc")

function extract_pixel_timeseries(r::Raster, i::Int, j::Int)
    data = r[i, j, :]
    reshape(data, 1, 1, :)
end

temp_vec = [extract_pixel_timeseries(temp_raster, i, j) for (i, j) in valid_pairs]
prec_vec = [extract_pixel_timeseries(prec_raster, i, j) for (i, j) in valid_pairs]
clt_vec  = [extract_pixel_timeseries(clt_raster,  i, j) for (i, j) in valid_pairs]
ksat_vec = [extract_pixel_timeseries(ksat_raster, i, j) for (i, j) in valid_pairs]
whc_vec  = [extract_pixel_timeseries(whc_raster,  i, j) for (i, j) in valid_pairs]

# -------------------- Forward model: run Biome.jl on one pixel (1×1×T)
function runmodel_pixel(temp, prec, clt, ksat, whc,
                        gdd5_low, gdd5_high,
                        swb_low, swb_high,
                        tcm_low, tcm_high,
                        twm_low, twm_high,
                        tmin_low)

    PFTList = PFTClassification([NeedleleafDeciduousPFT()])

    set_characteristic!(PFTList, "NeedleleafDeciduousBase", :gdd5, [gdd5_low, gdd5_high])
    set_characteristic!(PFTList, "NeedleleafDeciduousBase", :swb,  [swb_low, swb_high])
    set_characteristic!(PFTList, "NeedleleafDeciduousBase", :tcm,  [tcm_low, tcm_high])
    set_characteristic!(PFTList, "NeedleleafDeciduousBase", :twm,  [twm_low, twm_high])
    set_characteristic!(PFTList, "NeedleleafDeciduousBase", :tmin, [tmin_low, Inf])

    lon = [0.0]; lat = [0.0]
    temp_r = Raster(temp, dims=(X(lon), Y(lat), Ti(1:size(temp, 3))), name="temp")
    prec_r = Raster(prec, dims=(X(lon), Y(lat), Ti(1:size(prec, 3))), name="prec")
    clt_r  = Raster(clt,  dims=(X(lon), Y(lat), Ti(1:size(clt, 3))), name="clt")
    ksat_r = Raster(ksat, dims=(X(lon), Y(lat), Ti(1:size(ksat, 3))), name="Ksat")
    whc_r  = Raster(whc,  dims=(X(lon), Y(lat), Ti(1:size(whc, 3))), name="whc")

    setup = ModelSetup(BaseModel();
        temp=temp_r, prec=prec_r, clt=clt_r,
        ksat=ksat_r, whc=whc_r,
        co2=373.8, pftlist=PFTList)

    outfile = "output_$(uuid4()).nc"
    output = execute(setup; coordstring="alldata", outfile=outfile)
    return output[:biome]
end

# -------------------- Turing model
@model function param_estimation(y, temp, prec, clt, ksat, whc, n)
    gdd5_low ~ Uniform(300, 1800);  Δgdd5 ~ Uniform(50, 500);  gdd5_high = gdd5_low + Δgdd5
    swb_low  ~ Uniform(0, 500);     Δswb  ~ Uniform(10, 600);  swb_high  = swb_low  + Δswb
    tcm_low  ~ Uniform(-40, 5);     Δtcm  ~ Uniform(1, 20);    tcm_high  = tcm_low  + Δtcm
    twm_low  ~ Uniform(5, 25);      Δtwm  ~ Uniform(1, 10);    twm_high  = twm_low  + Δtwm
    tmin_low ~ Uniform(-90, 0)

    for i in 1:n
        # optional skip if missing temp
        if any(ismissing, temp[i][1,1,:])
            continue
        end

        pred = runmodel_pixel(temp[i], prec[i], clt[i], ksat[i], whc[i],
                              gdd5_low, gdd5_high,
                              swb_low, swb_high,
                              tcm_low, tcm_high,
                              twm_low, twm_high,
                              tmin_low)

        # Transform presence/absence 1/0 to probabilities for the model!
        prob = pred == 1 ? 0.95 : 0.05
        y[i] ~ Bernoulli(prob)
    end
end

model = param_estimation(y, temp_vec, prec_vec, clt_vec, ksat_vec, whc_vec, n)

# -------------------- Sample (single run) + quick output
# We don't recommend running a single chain, I'd go for maybe 4. 
# But this is just a conceptual example. 
setprogress!(false)
chain = sample(model, SMC(), 200)

p = plot(chain)
savefig(p, joinpath(outdir, "chain_plot.png"))

open(joinpath(outdir, "chain_summary.txt"), "w") do io
    write(io, string(summary(chain)))
end
