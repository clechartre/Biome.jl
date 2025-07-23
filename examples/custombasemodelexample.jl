using Biome
using Rasters

tempfile = "/Users/capucinelechartre/Documents/PhD/BIOME4Py/data/generated_data/climatologies/temp_1981-2010.nc"
precfile = "/Users/capucinelechartre/Documents/PhD/BIOME4Py/data/generated_data/climatologies/prec_1981-2010.nc"
cltfile = "/Users/capucinelechartre/Documents/PhD/BIOME4Py/data/generated_data/climatologies/sun_1981-2010.nc"
soilfile = "/Users/capucinelechartre/Documents/PhD//makesoil/output/soils_55km.nc"

temp_raster = Raster(tempfile, name="temp")
prec_raster = Raster(precfile, name="prec")
clt_raster = Raster(cltfile, name="sun")
ksat_raster = Raster(soilfile, name="Ksat")
whc_raster = Raster(soilfile, name="whc")

# Any custom PFT you want
C4Grass = GrassPFT(c4 = true)

TropicalEvergreen = EvergreenPFT(
    name = "TropicalEvergreen",
    phenological_type = 1,
    max_min_canopy_conductance = 0.5,
    Emax = 10.0,
    root_fraction_top_soil     = 0.69,
    optratioa                  = 0.95,
    kk                         = 0.7,
    t0                         = 10.0,
    tcurve                     = 1.0,
    respfact                   = 0.8,
    allocfact                  = 1.0,
    constraints = (
        tcm = [-Inf, +Inf],
        min = [0.0, +Inf],
        gdd = [-Inf, +Inf],
        gdd0 = [-Inf, +Inf],
        twm = [10.0, +Inf],
        snow = [-Inf, +Inf],
        swb = [700.0, +Inf]
    ),
    mean_val = (clt=50.2, prec=169.6, temp=24.7),
    sd_val = (clt=4.9,  prec=41.9,  temp=1.2),
    dominance_factor = 1
)

TemperateDeciduous = DeciduousPFT(
    name = "TemperateDeciduous",
    constraints = (
        tcm=[-Inf, +Inf],
        min=[-8.0, 5.0],
        gdd=[1200, +Inf],
        gdd0=[-Inf, +Inf],
        twm=[10.0, +Inf],
        snow=[-Inf, +Inf],
        swb=[400,+Inf]
    ),
    mean_val = (clt=33.4, prec=106.3, temp=18.7),
    sd_val = (clt=13.3, prec=83.6,  temp=3.2),
    dominance_factor = 1
)

struct Savanna  <: AbstractBiome
    value::Int
    Savanna() = new(6)
  end

struct TropicalEvergreenForest <: AbstractBiome
    value::Int
    TropicalEvergreenForest() = new(7)
  end

  struct TemperateDeciduousForest <: AbstractBiome
    value::Int
    TemperateDeciduousForest() = new(8)
  end
  
  

# 3. redefine for *all* GrassPFT, but branch on the .c4 flag
function my_biome_assign(pft::AbstractPFT;
    subpft,
    wdom,
    gdd0,
    gdd5,
    tcm,
    tmin,
    BIOME4PFTS,
    PFTStates,
    gdom)
    if get_characteristic(pft, :c4)
        return Savanna()
    elseif  get_characteristic(pft, :name) == "TropicalEvergreen"
        return TropicalEvergreenForest()
    elseif get_characteristic(pft, :name) == "TemperateDeciduous"
        return TemperateDeciduousForest()
    else
    # FIXME could we make this fallback silent
        return Biome.assign_biome(pft;
                subpft=subpft, wdom=wdom,
                gdd0=gdd0, gdd5=gdd5,
                tcm=tcm, tmin=tmin,
                BIOME4PFTS=BIOME4PFTS,
                PFTStates=PFTStates, gdom=gdom)
    end
end


PFTList = PFTClassification([
        DeciduousPFT(),
        TundraPFT(),
        GrassPFT(),
        C4Grass,
        TropicalEvergreen,
        TemperateDeciduous
    ]
)
# 1. Build a ModelSetup in one line (all kws, no long positional list)
setup = ModelSetup(BaseModel;
                   temp=temp_raster,
                   prec=prec_raster,
                   sun= clt_raster,
                   ksat=ksat_raster,
                   whc= whc_raster,
                   co2=373.8,
                   PFTList = PFTList,
                   biome_assignment = my_biome_assign)

# 2. Run it in one line
run!(setup; coordstring="-180/0/-90/90", outfile="output_CustomModel.nc")
