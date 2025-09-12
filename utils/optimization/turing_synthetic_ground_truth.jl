"""
Beginning of a code to run Turing.jl on Biome.jl to estimate parameters 
based on ground truth distribution of a PFT
"""
# --------------------  Imports
using Biome
using Rasters
using UUIDs

# Turing and Distributions
using Turing, Distributions
using MCMCChains, Plots
using Random
using StatsPlots
Random.seed!(42)

# -------------------- Load Ground Truth 
groundtruthpath = "/Users/capucinelechartre/Documents/DocumentsWSLM29592/PhD/BIOME/output_groundtruth.nc"
groundtruth = Raster(groundtruthpath, name="biome")
groundtruth = map(x -> ismissing(x) ? -9999 : (x == 0 ? 0 : 1), groundtruth)

groundtruthflat = vec(groundtruth)
valid_idx = findall(x -> x != -9999, groundtruthflat)
y = Int.(groundtruthflat[valid_idx])
n = length(y)

# -------------------- Load Climate Inputs
struct BiomeInputs
    temp::Raster
    prec::Raster
    clt::Raster
    ksat::Raster
    whc::Raster
end

function load_inputs()::BiomeInputs
    return BiomeInputs(
        Raster("/Users/capucinelechartre/Documents/DocumentsWSLM29592/PhD/BIOME4Py/data/generated_data/climatologies/temp_1981-2010.nc", name="temp"),
        Raster("/Users/capucinelechartre/Documents/DocumentsWSLM29592/PhD/BIOME4Py/data/generated_data/climatologies/prec_1981-2010.nc", name="prec"),
        Raster("/Users/capucinelechartre/Documents/DocumentsWSLM29592/PhD/BIOME4Py/data/generated_data/climatologies/sun_1981-2010.nc", name="sun"),
        Raster("/Users/capucinelechartre/Documents/DocumentsWSLM29592/PhD/makesoil/output/soils_55km.nc", name="Ksat"),
        Raster("/Users/capucinelechartre/Documents/DocumentsWSLM29592/PhD/makesoil/output/soils_55km.nc", name="whc"),
    )
end

inputs = load_inputs()

# -------------------- FIXED: Extract full (1,1,N) climate vectors for valid pixels

# Get the (i, j) indices of valid pixels
dims_lon = dims(inputs.temp, X)
dims_lat = dims(inputs.temp, Y)
nlon, nlat = length(dims_lon), length(dims_lat)

ij_pairs = CartesianIndices((nlon, nlat))
valid_pairs = [Tuple(I) for I in ij_pairs if groundtruth[I] != -9999]


function extract_pixel_timeseries(r::Raster, i::Int, j::Int)
    data = r[i, j, :]
    reshape(data, 1, 1, :)
end

# For each valid pixel, extract (1,1,N) array
temp_vec = [extract_pixel_timeseries(inputs.temp, i, j) for (i, j) in valid_pairs]
prec_vec = [extract_pixel_timeseries(inputs.prec, i, j) for (i, j) in valid_pairs]
clt_vec  = [extract_pixel_timeseries(inputs.clt,  i, j) for (i, j) in valid_pairs]
ksat_vec = [extract_pixel_timeseries(inputs.ksat, i, j) for (i, j) in valid_pairs]
whc_vec  = [extract_pixel_timeseries(inputs.whc,  i, j) for (i, j) in valid_pairs]

# -------------------- Run Model for a Single Pixel
function runmodel_pixel(temp, prec, clt, ksat, whc, param1, param2, param3, param4, param5,
                              param6, param7, param8, param9, param10,
                              param11, param12, param13, param14)
    PFTList = PFTClassification([
        BIOME4.BorealEvergreen()
        ]
    )

    set_characteristic!(PFTList, "BorealEvergreen", :tcm, [param1, param2])
    set_characteristic!(PFTList, "BorealEvergreen", :tmin, [param3, param4])
    set_characteristic!(PFTList, "BorealEvergreen", :gdd5, [param5, param6]) 
    set_characteristic!(PFTList, "BorealEvergreen", :gdd0, [param7, param8])
    set_characteristic!(PFTList, "BorealEvergreen", :twm, [param9, param10])
    set_characteristic!(PFTList, "BorealEvergreen", :maxdepth, [param11, param12])
    set_characteristic!(PFTList, "BorealEvergreen", :swb, [param13, param14])

    lon = [0.0]; lat = [0.0]

    temp_r = Raster(temp, dims=(X(lon), Y(lat), Ti(1:size(temp, 3))), name="tas")
    prec_r = Raster(prec, dims=(X(lon), Y(lat), Ti(1:size(prec, 3))), name="pr")
    clt_r  = Raster(clt,  dims=(X(lon), Y(lat), Ti(1:size(clt, 3))), name="clt")
    ksat_r = Raster(ksat, dims=(X(lon), Y(lat), Ti(1:size(ksat, 3))), name="Ksat")
    whc_r  = Raster(whc,  dims=(X(lon), Y(lat), Ti(1:size(whc, 3))), name="whc")

    setup = ModelSetup(BIOME4Model();
        temp=temp_r, prec=prec_r, clt=clt_r,
        ksat=ksat_r, whc=whc_r,
        co2=373.8, pftlist=PFTList)

    uuid = string(uuid4())
    outfile = "output_$(uuid).nc"
    output = run!(setup; coordstring="alldata", outfile=outfile)
    println("output", output)
    biome_val = output[:biome]

    # biome_val = Raster(outfile, name="biome")[1, 1]
    # rm(outfile, force=true)

    return biome_val # Return presence (1) or absence (0)
end

# -------------------- Turing Model
@model function param_estimation(y, temp, prec, clt, ksat, whc, n)
    param1 ~ Uniform(-90, 100)
    delta1 ~ Uniform(10, 100)
    param2 = param1 + delta1

    param3 ~ Uniform(-90, 100)
    delta2 ~ Uniform(10, 100)
    param4 = param3 + delta2

    param5 ~ Uniform(0, 2000)
    delta3 ~ Uniform(100, 2000)
    param6 = param5 + delta3

    param7 ~ Uniform(0, 2000)
    delta4 ~ Uniform(100, 3000)
    param8 = param7 + delta4

    param9 ~ Uniform(-10, 30)
    delta5 ~ Uniform(5, 30)
    param10 = param9 + delta5

    param11 ~ Uniform(0, 3)
    delta6 ~ Uniform(0.5, 3)
    param12 = param11 + delta6

    param13 ~ Uniform(0, 2000)
    delta7 ~ Uniform(0, 2000)
    param14 = param13 + delta7

    for i in 1:n
        prob = runmodel_pixel(temp[i], prec[i], clt[i], ksat[i], whc[i],
                              param1, param2, param3, param4, param5,
                              param6, param7, param8, param9, param10,
                              param11, param12, param13, param14
                              )
        # prob = pred == 1 ? 0.95 : 0.05
        y[i] ~ Bernoulli(prob)
    end
end

model = param_estimation(y, temp_vec, prec_vec, clt_vec, ksat_vec, whc_vec, n)

# -------------------- Sampling
setprogress!(false)
# chain = sample(model, SMC(), 200)  # Use SMC since gradients don't work well here
# chain = sample(model, SMC(), 500, 3)  does not work because SMC only supports a single thread
# chain = sample(model, NUTS(), MCMCThreads(), 1_500, 3)
chain = sample(model, SMC(), MCMCThreads(), 5, 4)

# -------------------- Plotting
p = plot(chain)
try
    savefig(p, "/Users/capucinelechartre/Documents/DocumentsWSLM29592/PhD/BIOME/utils/optimization/synthetic/chain_plot_evergreen_100.png")
    savefig(p, "/Users/capucinelechartre/Documents/DocumentsWSLM29592/PhD/BIOME/utils/optimization/synthetic/chain_plot_evergreen_100.svg")
catch e
    @warn "Saving SVG failed. Falling back to PNG only: $e"
    savefig(p, "/Users/capucinelechartre/Documents/DocumentsWSLM29592/PhD/BIOME/utils/optimization/synthetic/chain_plot_evergreen_100.png")
end

c = corner(chain)
savefig(c, "/Users/capucinelechartre/Documents/DocumentsWSLM29592/PhD/BIOME/utils/optimization/synthetic/chain_corner_evergreen_100.svg")

# d = describe(chain)
# open("chain_description.txt", "w") do file
#     write(file, d)
# end
d = summary(chain)
open("/Users/capucinelechartre/Documents/DocumentsWSLM29592/PhD/BIOME/utils/optimization/synthetic/chain_description_evergreen_100.txt", "w") do file
    write(file, d)
    e = describe(chain)
    write(file, e)
end

