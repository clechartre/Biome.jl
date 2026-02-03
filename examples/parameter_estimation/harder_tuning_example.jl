"""
Example of how to use Turing.jl parameter estimation 
on Biome.jl with multiple environmental thresholds
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

# =============================================================================
# Why is this the "harder" example?
# =============================================================================
# I am showing here a tuning framework in which we saved inputs into a structure 
# to optimize overhead. 
# We also have a bit more advanced violin plotting as shown in the paper. 
# The level of complexity you can will really depend on your use case. 
# =============================================================================

# -------------------- Imports
using Biome
using Rasters
using UUIDs
using Turing, Distributions
using MCMCChains, Plots
using Random, StatsPlots, Statistics
using Serialization
Random.seed!(957)  # Fix RNG seed so sampling/repro steps are reproducible


# -------------------- Load Ground Truth 
groundtruthpath = "path/to/ground_truth"
groundtruth = Raster(groundtruthpath, name="Band1") # Load a raster band with the ground truth presence/absence

# Convert ground truth to a binary label raster with a sentinel for missing:
# - missing -> -9999 (sentinel used throughout as "invalid pixel")
# - value == 0 -> 0
# - everything else -> 1
# This makes sure we have presence/absence classification.
groundtruth = map(x -> ismissing(x) ? -9999 : (x == 0 ? 0 : 1), groundtruth)

# Flatten the raster to a 1D vector (row-major linearization of the grid)
groundtruthflat = vec(groundtruth)

# Find indices that are NOT missing (i.e., where sentinel != -9999)
valid_idx = findall(x -> x != -9999, groundtruthflat)

# Observations y: integer labels (0/1) at valid indices only
y = Int.(groundtruthflat[valid_idx])

# Number of observations (valid pixels)
n = length(y)

# -------------------- Load Climate Inputs
# A structure to keep climate rasters together and typed.
# This reduces overhead by not having to load the rasters all the time 
# Those should be in the format of the inputs to Biome.jl
struct BiomeInputs
    temp::Raster   # temperature (12-month climatology)
    prec::Raster   # precipitation (12-month climatology)
    clt::Raster    # cloudiness (here: converted to "sun")
    ksat::Raster   # saturated hydraulic conductivity
    whc::Raster    # water holding capacity
end

# Function that loads all needed inputs and returns them grouped in BiomeInputs.
function load_inputs()::BiomeInputs
    return BiomeInputs(
        Raster("path/to/temp.nc", name="temp"),
        Raster("path/to/prec.nc", name="prec"),
        Raster("path/to/clt.nc", name="clt"),
        Raster("path/to//soils.nc", name="Ksat"),
        Raster("path/to//soils.nc", name="whc"),
    )
end

inputs = load_inputs()  # Load them once and then keep on using

# -------------------- Extract valid pixel timeseries
# Grab the lon/lat dimensions from the temperature raster (NOTE: all inputs have the same shared grid).
dims_lon = dims(inputs.temp, X)
dims_lat = dims(inputs.temp, Y)
nlon, nlat = length(dims_lon), length(dims_lat)

# Iterate over all (i, j) pairs on the 2D grid.
ij_pairs = CartesianIndices((nlon, nlat))

# Keep only the (i, j) pairs where the ground truth pixel is valid (not -9999).
# NOTE: This is selecting valid pixels by *groundtruth raster indexing*.
valid_pairs = [Tuple(I) for I in ij_pairs if groundtruth[I] != -9999]

# Helper: extract the time series at a given pixel (i, j).
# r[i, j, :] returns a 1D time series; reshape to (1, 1, T) so Biome.jl
# can treat it like a 1×1 "mini-raster" through time.
function extract_pixel_timeseries(r::Raster, i::Int, j::Int)
    data = r[i, j, :]
    reshape(data, 1, 1, :)
end

# For each valid (i, j), build a vector of 1×1×T arrays.
# Each element temp_vec[k] corresponds to the k-th valid pixel.
temp_vec = [extract_pixel_timeseries(inputs.temp, i, j) for (i, j) in valid_pairs]
prec_vec = [extract_pixel_timeseries(inputs.prec, i, j) for (i, j) in valid_pairs]
clt_vec  = [extract_pixel_timeseries(inputs.clt,  i, j) for (i, j) in valid_pairs]
ksat_vec = [extract_pixel_timeseries(inputs.ksat, i, j) for (i, j) in valid_pairs]
whc_vec  = [extract_pixel_timeseries(inputs.whc,  i, j) for (i, j) in valid_pairs]


# -------------------- Run Model for a Single Pixel
# Core forward model: given climate time series + threshold parameters,
# run Biome.jl on a 1×1 cell and return the predicted biome value.
function runmodel_pixel(temp, prec, clt, ksat, whc,
                        gdd5_low, gdd5_high,
                        swb_low, swb_high,
                        tcm_low, tcm_high,
                        twm_low, twm_high,
                        tmin_low)

    # Create a list of PFTs to classify.
    # Here you are only allowing one PFT: NeedleleafDeciduousPFT().
    # This is what you are tuning.
    # Depends on your needs. 
    PFTList = PFTClassification([
        NeedleleafDeciduousPFT(),
    ])

    # Overwrite the environmental constraints (characteristics/thresholds)
    # for the base PFT definition "NeedleleafDeciduousBase".
    # Each call sets a min/max range (or lower bound + Inf).
    set_characteristic!(PFTList, "NeedleleafDeciduousBase", :gdd5, [gdd5_low, gdd5_high])
    set_characteristic!(PFTList, "NeedleleafDeciduousBase", :swb,  [swb_low, swb_high])
    set_characteristic!(PFTList, "NeedleleafDeciduousBase", :tcm,  [tcm_low, tcm_high])
    set_characteristic!(PFTList, "NeedleleafDeciduousBase", :twm,  [twm_low, twm_high])
    set_characteristic!(PFTList, "NeedleleafDeciduousBase", :tmin, [tmin_low, Inf])

    # Build "fake" lon/lat for the 1×1 raster. Only the time dimension matters
    # for the pixel-forward run; lon/lat are placeholders.
    lon = [0.0]; lat = [0.0]

    # Wrap raw arrays into Raster objects with explicit dimensions:
    # dims = (X, Y, Ti) where Ti is a simple 1:T index.
    temp_r = Raster(temp, dims=(X(lon), Y(lat), Ti(1:size(temp, 3))), name="temp")
    prec_r = Raster(prec, dims=(X(lon), Y(lat), Ti(1:size(prec, 3))), name="prec")
    clt_r  = Raster(clt,  dims=(X(lon), Y(lat), Ti(1:size(clt, 3))), name="sun")
    ksat_r = Raster(ksat, dims=(X(lon), Y(lat), Ti(1:size(ksat, 3))), name="Ksat")
    whc_r  = Raster(whc,  dims=(X(lon), Y(lat), Ti(1:size(whc, 3))), name="whc")

    # Create Biome.jl model setup:
    # - BaseModel() is the model template. You can also use BIOME4Model or BiomeDominance
    # - provide climate rasters, soil rasters, CO2, and the customized pftlist
    setup = ModelSetup(BaseModel();
        temp=temp_r, prec=prec_r, clt=clt_r,
        ksat=ksat_r, whc=whc_r,
        co2=373.8, pftlist=PFTList)

    # Write output to a unique file to avoid collisions between runs.
    uuid = string(uuid4())
    outfile = "output_$(uuid).nc"

    # Run the model.
    # coordstring="alldata" likely controls metadata naming for the output.
    output = execute(setup; coordstring="alldata", outfile=outfile)

    # Extract the biome field from output.
    # NOTE: biome_val may be an array/raster-like object; downstream you compare `pred == 1`.
    biome_val = output[:biome]
    return biome_val
end


# -------------------- Full Turing Model
# This defines the probabilistic model that Turing will sample from.
# Inputs:
# - y: observed binary labels (0/1) for n pixels
# - temp, prec, ...: vectors of 1×1×T climate arrays for each pixel
# - n: number of pixels / observations (matches length(y))
@model function param_estimation(y, temp, prec, clt, ksat, whc, n)

    # -------- Priors for threshold parameters --------
    # For each "low/high" bound, you sample:
    #   low ~ Uniform(...)
    #   Δ   ~ Uniform(...)
    #   high = low + Δ
    # This enforces high > low automatically.

    # GDD5 thresholds (growing degree days above 5°C, typical)
    gdd5_low ~ Uniform(300, 1800)
    Δgdd5 ~ Uniform(50, 500)
    gdd5_high = gdd5_low + Δgdd5

    # SWB thresholds (soil water balance / water availability proxy)
    swb_low ~ Uniform(0, 500)
    Δswb ~ Uniform(10, 600)
    swb_high = swb_low + Δswb

    # TCM thresholds (temperature coldest month)
    tcm_low ~ Uniform(-40, 5)
    Δtcm ~ Uniform(1, 20)
    tcm_high = tcm_low + Δtcm

    # TWM thresholds (temperature warmest month)
    twm_low ~ Uniform(5, 25)
    Δtwm ~ Uniform(1, 10)
    twm_high = twm_low + Δtwm

    # Tmin: only a lower bound; upper bound is set to Inf in runmodel_pixel
    tmin_low ~ Uniform(-90, 0)

    # Count how many pixels get skipped because of missing climate values.
    unused = 0

    # -------- Likelihood over pixels --------
    # For each pixel:
    # - if any missing in the temperature series, skip it
    # - run the mechanistic model to get a predicted biome value
    # - map prediction to a Bernoulli probability
    # - observe y[i] from that Bernoulli
    for i in 1:n
        if any(ismissing, temp[i][1,1,:])
            unused += 1
            continue
        end

        pred = runmodel_pixel(temp[i], prec[i], clt[i], ksat[i], whc[i],
                              gdd5_low, gdd5_high,
                              swb_low, swb_high,
                              tcm_low, tcm_high,
                              twm_low, twm_high,
                              tmin_low)

        # Hard-coded observation model:
        # - If the model predicts class 1: P(y=1)=0.95
        # - Otherwise:               P(y=1)=0.05
        # So you assume strong but not perfect accuracy.
        prob = pred == 1 ? 0.95 : 0.05

        # Likelihood contribution for this pixel
        y[i] ~ Bernoulli(prob)
    end

    # Debug print each iteration / particle: useful to see how many pixels were used.
    println("Used $(n - unused) pixels in this iteration.")
end

# Instantiate the Turing model with data
model = param_estimation(y, temp_vec, prec_vec, clt_vec, ksat_vec, whc_vec, n)


# -------------------- Sampling
setprogress!(false)  # Disable Turing progress output (helpful on clusters)

# Run SMC twice (500 particles each) to get two chains (or two independent runs)
chain1 = sample(model, SMC(), 500)
serialize("chain1_nd.jls", chain1)  # Save intermediate chain to disk

chain2 = sample(model, SMC(), 500)
serialize("chain2_nd.jls", chain2)

# Concatenate the two chains into one Chains object
chain = chainscat(chain1, chain2)

# -------------------- Plotting and Output
outdir = "path/to/outdir"

# Standard trace/density plots for all parameters in the chain
p = plot(chain)
try
    savefig(p, joinpath(outdir, "chain_plot_nd.png"))
    savefig(p, joinpath(outdir, "chain_plot_nd.svg"))
catch e
    # If SVG export fails (common in headless environments), fall back to PNG
    @warn "Saving SVG failed. Falling back to PNG only: $e"
    savefig(p, joinpath(outdir, "chain_plot_nd.png"))
end

# Corner plot (pairwise joint distributions + marginals)
c = corner(chain)
savefig(c, joinpath(outdir, "chain_corner_nd.svg"))


# -------------------- Individual violin plots per variable (aligned)
default(fontfamily = "Helvetica")  # Plotting default font

# Describe each parameter: (symbol in chain, human label, prior definition)
# For "high" bounds, the prior is conditional on the sampled "low" via a function.
param_info = [
    (:gdd5_low, "GDD5 lower", Uniform(300.0, 1800.0)),
    (:gdd5_high, "GDD5 upper", (p -> Uniform(p + 50.0, 500.0 + p))),
    (:swb_low, "SWB lower", Uniform(0.0, 500.0)),
    (:swb_high, "SWB upper", (p -> Uniform(p + 10.0, 600.0 + p))),
    (:tcm_low, "TCM lower", Uniform(-40.0, 5.0)),
    (:tcm_high, "TCM upper", (p -> Uniform(p + 1.0, 20.0 + p))),
    (:twm_low, "TWM lower", Uniform(5.0, 25.0)),
    (:twm_high, "TWM upper", (p -> Uniform(p + 1.0, 10.0 + p))),
    (:tmin_low, "Tmin lower", Uniform(-90.0, 0.0))
]

# Extract posterior samples from the chain into a Dict for convenience.
# For lows: directly from chain.
# For highs: reconstruct from low + Δ (because you sampled Δ, not the high directly).
post_samples = Dict{Symbol, Vector{Float64}}()
post_samples[:gdd5_low] = vec(Array(chain[:gdd5_low]))
post_samples[:swb_low] = vec(Array(chain[:swb_low]))
post_samples[:tcm_low] = vec(Array(chain[:tcm_low]))
post_samples[:twm_low] = vec(Array(chain[:twm_low]))
post_samples[:tmin_low] = vec(Array(chain[:tmin_low]))

post_samples[:gdd5_high] = vec(Array(chain[:gdd5_low])) .+ vec(Array(chain[:Δgdd5]))
post_samples[:swb_high]  = vec(Array(chain[:swb_low])) .+ vec(Array(chain[:Δswb]))
post_samples[:tcm_high]  = vec(Array(chain[:tcm_low])) .+ vec(Array(chain[:Δtcm]))
post_samples[:twm_high]  = vec(Array(chain[:twm_low])) .+ vec(Array(chain[:Δtwm]))


# -------------------- Generate aligned violin plots
ns = 4000  # number of prior samples to draw for the prior violin

for (param, label, prior_def) in param_info
    # ----- Prior sampling -----
    # Build a sample from the prior distribution for each parameter so you can
    # overlay prior vs posterior in the violin plot.
    prior_vals = Float64[]

    for _ in 1:ns
        # If prior_def is a function, it is a conditional prior for "high" bounds.
        # You must first sample a "base" low bound, then sample high ~ Uniform(low+Δmin, low+Δmax).
        if typeof(prior_def) <: Function
            base = rand(param == :gdd5_high ? Uniform(300, 1800) :
                        param == :swb_high ? Uniform(-300, 0) :
                        param == :tcm_high ? Uniform(-40, 5) :
                        param == :twm_high ? Uniform(5, 25) : 0)
            push!(prior_vals, rand(prior_def(base)))
        else
            # Unconditional prior: just sample directly
            push!(prior_vals, rand(prior_def))
        end
    end

    # ----- Posterior summary -----
    posterior_vals = post_samples[param]
    mean_val = mean(posterior_vals)
    lo, hi = quantile(posterior_vals, [0.025, 0.975])  # 95% credible interval

    # Create a single violin plot comparing prior vs posterior
    pplt = plot(size=(700, 600), legend=:topleft, title="Parameter Distribution: $label",
                xlabel="", ylabel="Value", framestyle=:box, grid=:y)

    # Draw prior (wider, more transparent) then posterior (narrower, more opaque)
    violin!([1], prior_vals; width=0.35, fillalpha=0.25, linewidth=0, color=:gray, label="Prior")
    violin!([1], posterior_vals; width=0.25, fillalpha=0.45, linewidth=0, color=:dodgerblue, label="Posterior")

    # Add posterior mean and 95% interval as a point with error bars
    scatter!([1], [mean_val]; yerror=([mean_val-lo], [hi-mean_val]),
             color=:dodgerblue, ms=6, label="Posterior mean ±95% CI")

    # Label the x-axis (single category)
    xticks!([1], ["Prior & Posterior"])

    # Save both PNG and SVG
    savefig(pplt, joinpath(outdir, "$(label)_violin.png"))
    savefig(pplt, joinpath(outdir, "$(label)_violin.svg"))
end


# -------------------- Chain summary
# summary(chain) returns a text summary table of diagnostics and moments.
d = summary(chain)

# Write chain summary to a text file for later inspection.
open(joinpath(outdir, "chain_description_nd.txt"), "w") do file
    write(file, d)
end
