"""
Example of setting up a succulent PFT and a succulent biome and runnign the model on it.
"""

using Biome
using Rasters

tempfile = "/Users/capucinelechartre/Documents/DocumentsWSLM29592/PhD/BIOME/data_biome4py/generated_data/climatologies/temp_1981-2010.nc"
precfile = "/Users/capucinelechartre/Documents/DocumentsWSLM29592/PhD/BIOME/data_biome4py/generated_data/climatologies/prec_1981-2010.nc"
cltfile  = "/Users/capucinelechartre/Documents/DocumentsWSLM29592/PhD/BIOME/data_biome4py/generated_data/climatologies/sun_1981-2010.nc"
soilfile = "/Users/capucinelechartre/Documents/DocumentsWSLM29592/PhD/BIOME/data_biome4py/generated_data/climatologies/soils_55km.nc"

temp_raster = Raster(tempfile, name="temp")
prec_raster = Raster(precfile, name="prec")
clt_raster  = Raster(cltfile, name="sun")
sun_raster  = copy(clt_raster)
sun_raster .= ifelse.(coalesce.(clt_raster, -9999) .!= -9999, 100 .- coalesce.(clt_raster, -9999), -9999)
ksat_raster = Raster(soilfile, name="Ksat")
whc_raster  = Raster(soilfile, name="whc")

# Fire-prone climate mask, derived from monthly precipitation
# 1 where the driest consecutive 3 months get < DRY_QUARTER_MAX mm AND the
# wettest month gets > WET_PEAK_MIN mm; 0 elsewhere; -9999 where no data.
const DRY_QUARTER_MAX = 4.0   # mm over the driest 3 months
const WET_PEAK_MIN    = 80.0  # mm in the wettest month

P = collect(parent(prec_raster))
nx, ny = size(P, 1), size(P, 2)
fire_prone_data = fill(-9999.0, nx, ny)
for i in 1:nx, j in 1:ny
    p = P[i, j, :]
    any(ismissing, p) && continue
    p = Float64.(p)
    dry_quarter = minimum(sum(p[mod1(m + k, 12)] for k in 0:2) for m in 1:12)
    wet_peak    = maximum(p)
    fire_prone_data[i, j] = Float64(dry_quarter < DRY_QUARTER_MAX && wet_peak > WET_PEAK_MIN)
end
fire_prone = Raster(fire_prone_data;
                    dims=(dims(temp_raster, X), dims(temp_raster, Y)),
                    name="fire_prone")

# --- Succulent PFT ------------------------------------------------------------
SucculentPFT = BroadleafDeciduousPFT(
    name = "Succulent",
    phenological_type           = 2,    # 1: evergreen, 2: deciduous, many are deciduous
    max_min_canopy_conductance  = 0.05, # Same value as C3C4WoodyDesert
    Emax                        = 8.0,
    sw_drop                     = -99.9,
    sw_appear                   = -99.9,
    root_fraction_top_soil      = 0.9, # Wide, shallow root systems, sometimes with a central taproot
    # The diffuse, shallow roots of storage succulents are extremely well adapted for rapid rehydration  
    leaf_longevity              = 30.0,
    GDD5_full_leaf_out          = -99.9,
    GDD0_full_leaf_out          = -99.9,
    sapwood_respiration         = 2,    # CAM, non-woody
    optratioa                   = 0.7,
    kk                          = 0.3,
    c4                          = false,
    threshold                   = 0.25, # They are NOT fire resistant
    tcurve                      = 1.0,
    respfact                    = 1.6,
    allocfact                   = 1.0,
    grass                       = false,
    constraints = (
            tcm        = [5, +Inf],
            tmin       = [-8, +Inf],
            gdd5       = [-Inf, +Inf],
            gdd0       = [-Inf, +Inf],
            twm        = [-Inf, +Inf],
            maxdepth   = [-Inf, +Inf],
            swb        = [5, 44],
            tpr        = [0, 1200],
            fire_prone = [-Inf, 0.5],     # fire sensitivity: absent where fire_prone == 1
    ),
    dominance_factor = 1,
    minimum_lai = 0.5
)

 
# Add the PFT to the PFT list
PFTList = BIOME4.PFTClassification()
push!(PFTList.pft_list, SucculentPFT)

# Biome definition - add a biome that includes this PFT
struct SucculentBiome  <: AbstractBiome
    value::Int
    SucculentBiome() = new(30)
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
    env_variables
    )

    if get_characteristic(pft, :name) == "Succulent"
        return SucculentBiome()
    else
        return BIOME4.assign_biome(pft;
            subpft=subpft,
            wdom=wdom,
            gdom=gdom,
            gdd0=gdd0,
            gdd5=gdd5,
            tcm=tcm,
            tmin=tmin,
            pftlist=pftlist,
            pftstates=pftstates)
    end
end

setup = ModelSetup(BIOMEDominanceModel();
                   tas=temp_raster,
                   pr=prec_raster,
                   clt=sun_raster,
                   ksat=ksat_raster,
                   whc=whc_raster,
                   fire_prone=fire_prone,
                   co2=Float64(373.0),
                   pftlist=PFTList,
                   biome_assignment=my_biome_assign)

execute(setup; outfile="output_succulent.nc")
