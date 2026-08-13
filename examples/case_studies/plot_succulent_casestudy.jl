using Rasters
import ArchGDAL
using NCDatasets
using CairoMakie
using Colors

# ---- Font family (single sans-serif, two styles only) ----------------------
const GMD_FONT      = "Helvetica"
const GMD_FONT_BOLD = "Helvetica Bold"

# ---- Page geometry (points: 1 pt = 1/72 inch, 1 cm = 28.3465 pt) -----------
const PT_PER_CM    = 72 / 2.54
const GMD_WIDTH_CM = 24.0
const GMD_WIDTH_PT = GMD_WIDTH_CM * PT_PER_CM

# ---- Spacing / legend geometry ---------------------------------------------
const GAP_PANEL    = 3
const GAP_LABEL    = 2
const LEG_PATCH    = 8
const LEG_PLGAP    = 3
const LEG_ENTRYGAP = 8
const LEG_PAD      = (2, 2, 1, 1)

# ---- Font sizes ------------------------------------------------------------
const GMD_FS_BASE   = 9
const GMD_FS_TICK   = 9
const GMD_FS_AXLAB  = 10
const GMD_FS_TITLE  = 11
const GMD_FS_LABEL  = 9
const GMD_FS_LEGEND = 9

# ---- Raster resolution (300 dpi with points as base unit) ------------------
const GMD_PX_PER_UNIT = 300 / 72

function apply_gmd_theme!()
    CairoMakie.set_theme!(
        fontsize = GMD_FS_BASE,
        font     = GMD_FONT,
        fonts    = (; regular = GMD_FONT, bold = GMD_FONT_BOLD),
        Axis = (
            titlefont      = GMD_FONT_BOLD,
            titlesize      = GMD_FS_TITLE,
            xlabelfont     = GMD_FONT,
            ylabelfont     = GMD_FONT,
            xlabelsize     = GMD_FS_AXLAB,
            ylabelsize     = GMD_FS_AXLAB,
            xticklabelfont = GMD_FONT,
            yticklabelfont = GMD_FONT,
            xticklabelsize = GMD_FS_TICK,
            yticklabelsize = GMD_FS_TICK,
            xgridvisible   = false,
            ygridvisible   = false,
        ),
        Legend = (
            labelfont     = GMD_FONT,
            labelsize     = GMD_FS_LEGEND,
            framevisible  = false,
            titlefont     = GMD_FONT_BOLD,
            titlesize     = GMD_FS_TITLE,
            patchsize     = (LEG_PATCH, LEG_PATCH),
            patchlabelgap = LEG_PLGAP,
            colgap        = LEG_ENTRYGAP,
            rowgap        = 2,
            padding       = LEG_PAD,
        ),
        Label = (
            font     = GMD_FONT,
            fontsize = GMD_FS_LABEL,
        ),
        Colorbar = (
            labelfont     = GMD_FONT,
            labelsize     = GMD_FS_AXLAB,
            ticklabelfont = GMD_FONT,
            ticklabelsize = GMD_FS_TICK,
        ),
    )
    return nothing
end

function save_gmd(basepath::AbstractString, fig)
    pdf_path = basepath * ".pdf"
    png_path = basepath * ".png"
    save(pdf_path, fig)
    save(png_path, fig; px_per_unit = GMD_PX_PER_UNIT)
    println("Saved: ", pdf_path)
    println("Saved: ", png_path)
    return nothing
end

apply_gmd_theme!()

# --- Inputs -----------------------------------------------------------------
# Model biome map: the succulent biome is class 30.
biome_path  = ""
biome_class = 30

# Ringelberg et al. (2020) reference: presence coded as 1.
obs_nc_path = ""
ref_present = 0.1f0

# Region of interest.
lon_min, lon_max = -180.0, 180.0
lat_min, lat_max =  -60.0,  40.0

# Single basepath: save_gmd writes both .pdf and .png.
out_base = ""

# Load both rasters and align onto the model grid (nearest-neighbour, categorical).
biome_raster = Raster(biome_path, name="biome"; lazy=false)
ring_raster  = Raster(obs_nc_path, name="Band1"; lazy=false)

ring_on_grid = resample(ring_raster; to=biome_raster, method=:near)

# Crop both to the ROI with the same bounding box.
biome_roi = biome_raster[X(lon_min .. lon_max), Y(lat_min .. lat_max)]
ring_roi  = ring_on_grid[X(lon_min .. lon_max), Y(lat_min .. lat_max)]

xs = collect(lookup(biome_roi, X))
ys = collect(lookup(biome_roi, Y))

# --- Presence masks, preserving missing -------------------------------------
biome_pres = map(v -> ismissing(v) ? missing : (v == biome_class), biome_roi)
ring_pres  = map(v -> ismissing(v) ? missing : (v >= ref_present),  ring_roi)

# --- Categorical confusion field over cells valid in BOTH rasters -----------
# 1 = TN, 2 = FP (overpredicted), 3 = FN (underpredicted), 4 = TP.
nx, ny  = size(biome_roi)
cat_obs = Matrix{Float32}(undef, nx, ny)
for i in 1:nx, j in 1:ny
    bp = biome_pres[i, j]
    rp = ring_pres[i, j]
    if ismissing(bp) || ismissing(rp)
        cat_obs[i, j] = NaN32
    else
        pred = bp === true
        pres = rp === true
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

# Ensure ascending latitude for plotting.
ys_plot = ys
if length(ys_plot) ≥ 2 && ys_plot[2] < ys_plot[1]
    ys_plot = reverse(ys_plot)
    cat_obs = reverse(cat_obs, dims=2)
end

# --- Colours: colorblind-safe Wong / Okabe-Ito 4-category palette -----------
const WONG_GREY   = colorant"#DDDDDD"
const WONG_ORANGE = colorant"#E69F00"
const WONG_BLUE   = colorant"#0072B2"
const WONG_GREEN  = colorant"#009E73"

const CAT_CMAP = cgrad(
    [WONG_GREY, WONG_ORANGE, WONG_BLUE, WONG_GREEN],
    4;
    categorical = true,
)

legend_elems = [
    MarkerElement(color = WONG_GREEN,  marker = :rect, markersize = LEG_PATCH),
    MarkerElement(color = WONG_ORANGE, marker = :rect, markersize = LEG_PATCH),
    MarkerElement(color = WONG_BLUE,   marker = :rect, markersize = LEG_PATCH),
    MarkerElement(color = WONG_GREY,   marker = :rect, markersize = LEG_PATCH),
]
legend_labels = [
    "Predicted & observed (TP)",
    "Overpredicted only (FP)",
    "Underpredicted only (FN)",
    "Neither (TN)",
]

# --- Figure: single map panel + legend beneath ------------------------------
fig = Figure(backgroundcolor=:transparent)

ax = Axis(
    fig[1, 1];
    backgroundcolor = :transparent,
    xlabel          = "",
    ylabel          = "",
    xlabelsize      = GMD_FS_AXLAB,
    ylabelsize      = GMD_FS_AXLAB,
    xlabelfont      = GMD_FONT,
    ylabelfont      = GMD_FONT,
    xticklabelsize  = GMD_FS_TICK,
    yticklabelsize  = GMD_FS_TICK,
    xticklabelfont  = GMD_FONT,
    yticklabelfont  = GMD_FONT,
    aspect          = DataAspect(),
    xgridvisible    = false,
    ygridvisible    = false,
)

CairoMakie.heatmap!(
    ax, xs, ys_plot, cat_obs;
    colormap   = CAT_CMAP,
    colorrange = (1, 4),
    nan_color  = :transparent,
    rasterize  = 4,
)

Legend(
    fig[2, 1],
    legend_elems,
    legend_labels;
    orientation  = :horizontal,
    nbanks       = 1,
    tellwidth    = false,
    tellheight   = true,
    labelsize    = GMD_FS_LEGEND,
    labelfont    = GMD_FONT,
    framevisible = false,
    halign       = :center,
    valign       = :top,
)

# ---- Sizing: pin panel width to the shared target, height from DataAspect ---
data_aspect = (lon_max - lon_min) / (lat_max - lat_min)
colsize!(fig.layout, 1, Fixed(GMD_WIDTH_PT))
rowsize!(fig.layout, 1, Aspect(1, 1 / data_aspect))
rowgap!(fig.layout, 1, GAP_PANEL)
fig.layout.alignmode = Outside(4, 4, 4, 6)
resize_to_layout!(fig)

# --- Save both PDF and PNG --------------------------------------------------
save_gmd(out_base, fig)

valid = cat_obs[.!isnan.(cat_obs)]
