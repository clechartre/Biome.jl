using Rasters
import ArchGDAL
using NCDatasets
using CairoMakie
using Plots
using Colors
Plots.gr(fontfamily="Times New Roman")
CairoMakie.set_theme!(fontsize=20, font="Times New Roman")

nc_path      = "output_succulent_biome.nc"
varname      = "npp"
pft_index    = 14

obs_nc_path  = "/Users/capucinelechartre/Documents/DocumentsWSLM29592/PhD/BIOME/succulent_biome/doi_10_5061_dryad_08kprr4zs__v20200310/Succulent_biome_map_coarsened.nc"

lon_min, lon_max = -180.0, 180.0
lat_min, lat_max =  -60.0,  40.0

npp_threshold = 0.0

out_fig = "/Users/capucinelechartre/Documents/DocumentsWSLM29592/PhD/BIOME/succulent_biome/code/pft_npp_with_points.svg"
out_leg = "/Users/capucinelechartre/Documents/DocumentsWSLM29592/PhD/BIOME/succulent_biome/code/legend_pft_npp.svg"

function nearest_index(v::AbstractVector{<:Real}, x::Real)
    i = searchsortedfirst(v, x)
    if i ≤ 1
        return 1
    elseif i > length(v)
        return length(v)
    else
        return abs(v[i] - x) < abs(v[i-1] - x) ? i : (i-1)
    end
end

obs_present(v) = !isnan(v) && v > 0f0

r     = Raster(nc_path, name=varname; lazy=false)
r_pft = r[:, :, pft_index]

r_arr   = collect(r_pft)
r_arr   = map(x -> (ismissing(x) || x == -9999) ? missing : float(x), r_arr)
r_clean = Raster(r_arr, dims(r_pft); name=:npp_pft_clean)

r_roi = r_clean[X(lon_min .. lon_max), Y(lat_min .. lat_max)]
xs    = collect(lookup(r_roi, X))
ys    = collect(lookup(r_roi, Y))

obs_ds  = NCDataset(obs_nc_path, "r")
obs_lon = collect(obs_ds["lon"][:])
obs_lat = collect(obs_ds["lat"][:])
obs_raw = collect(obs_ds["Band1"][:,:])
close(obs_ds)

obs_mat_raw = map(x -> (ismissing(x) || x == -9999f0) ? NaN32 : Float32(x), obs_raw)

lon_idx = findall(lon_min .≤ obs_lon .≤ lon_max)
lat_idx = findall(lat_min .≤ obs_lat .≤ lat_max)

obs_lon_roi = obs_lon[lon_idx]
obs_lat_roi = obs_lat[lat_idx]
obs_roi     = obs_mat_raw[lon_idx, lat_idx]

obs_land(v) = !isnan(v)

model_mat = collect(r_roi)

ix_map = [nearest_index(xs, lon) for lon in obs_lon_roi]
iy_map = [nearest_index(ys, lat) for lat in obs_lat_roi]

n_lon_obs = length(obs_lon_roi)
n_lat_obs = length(obs_lat_roi)

model_pred_resampled = Matrix{Union{Missing,Bool}}(missing, n_lon_obs, n_lat_obs)
for i in 1:n_lon_obs
    for j in 1:n_lat_obs
        v = model_mat[ix_map[i], iy_map[j]]
        if !ismissing(v)
            model_pred_resampled[i, j] = v > npp_threshold
        end
    end
end

cat_obs = Matrix{Float32}(undef, n_lon_obs, n_lat_obs)
for i in 1:n_lon_obs
    for j in 1:n_lat_obs
        ov = obs_roi[i, j]
        mp = model_pred_resampled[i, j]

        if isnan(ov) || ismissing(mp)
            cat_obs[i, j] = NaN32
        else
            pred = mp === true
            pres = obs_present(ov)
            if pred && pres
                cat_obs[i, j] = 4f0
            elseif pred && !pres
                cat_obs[i, j] = 2f0
            elseif !pred && pres
                cat_obs[i, j] = 3f0
            else
                cat_obs[i, j] = 1f0
            end
        end
    end
end

obs_lat_plot = obs_lat_roi
if length(obs_lat_plot) ≥ 2 && obs_lat_plot[2] < obs_lat_plot[1]
    obs_lat_plot = reverse(obs_lat_plot)
    cat_obs      = reverse(cat_obs, dims=2)
end

wong_grey   = colorant"#DDDDDD"
wong_orange = colorant"#E69F00"
wong_blue   = colorant"#0072B2"
wong_green  = colorant"#009E73"

cat_cmap = cgrad(
    [wong_grey, wong_orange, wong_blue, wong_green],
    4;
    categorical = true
)

fig = Figure(backgroundcolor=:transparent, size=(1400, 700))
ax = Axis(
    fig[1, 1];
    backgroundcolor = :transparent,
    xlabel          = "Longitude",
    ylabel          = "Latitude",
    xlabelsize      = 30,
    ylabelsize      = 30,
    xlabelfont      = "Times New Roman",
    ylabelfont      = "Times New Roman",
    xticklabelsize  = 20,
    yticklabelsize  = 20,
    xticklabelfont  = "Times New Roman",
    yticklabelfont  = "Times New Roman",
    aspect          = DataAspect(),
    xgridvisible    = false,
    ygridvisible    = false
)

CairoMakie.heatmap!(
    ax, obs_lon_roi, obs_lat_plot, cat_obs;
    colormap   = cat_cmap,
    colorrange = (1, 4),
    nan_color  = :transparent
)

display(fig)
save(out_fig, fig; px_per_unit=2)

p_leg = Plots.plot(
    xlim=(0,1), ylim=(0,1),
    framestyle=:none, xticks=false, yticks=false,
    legend=:topleft, legendfontsize=11,
    legend_background_color=:transparent,
    backgroundcolor=:transparent
)

legend_items = [
    ("Predicted & observed (TP)",  RGB(0/255,  158/255, 115/255)),
    ("Over-predicted only (FP)",   RGB(230/255,159/255,   0/255)),
    ("Under-predicted only (FN)",  RGB(0/255,  114/255, 178/255)),
    ("Neither (TN)",               RGB(221/255,221/255, 221/255)),
]

for (label, color) in legend_items
    Plots.scatter!(p_leg, [0.0], [0.0];
        label=label, color=color, shape=:rect,
        markersize=12, markerstrokewidth=0
    )
end

display(p_leg)
savefig(p_leg, out_leg)

println("TP (predicted & observed): ", count(==(4f0), cat_obs[.!isnan.(cat_obs)]))
println("FP (over-predicted)      : ", count(==(2f0), cat_obs[.!isnan.(cat_obs)]))
println("FN (under-predicted)     : ", count(==(3f0), cat_obs[.!isnan.(cat_obs)]))
println("TN (neither)             : ", count(==(1f0), cat_obs[.!isnan.(cat_obs)]))