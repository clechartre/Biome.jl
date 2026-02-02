"""
Example of fitting the customizable base. 

Values are not ecologically relevant but only serve illustration.

"""

using Biome
using Rasters

tempfile = ""
precfile = ""
cltfile = ""
soilfile = ""

temp_raster = Raster(tempfile, name="temp")
prec_raster = Raster(precfile, name="prec")
clt_raster = Raster(cltfile, name="sun")
ksat_raster = Raster(soilfile, name="Ksat")
whc_raster = Raster(soilfile, name="whc")

# Any custom PFT you want
C4Grass = C4GrassPFT()

TropicalEvergreen = BroadleafEvergreenPFT(
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
        tmin = [0.0, +Inf],
        gdd5 = [-Inf, +Inf],
        gdd0 = [-Inf, +Inf],
        twm = [10.0, +Inf],
        maxdepth  = [-Inf, +Inf],
        swb = [700.0, +Inf]
    ),
    dominance_factor = 1
)

TemperateDeciduous = BroadleafDeciduousPFT(
    name = "TemperateDeciduous",
    constraints = (
        tcm=[-Inf, +Inf],
        tmin=[-8.0, 5.0],
        gdd5=[1200, +Inf],
        gdd0=[-Inf, +Inf],
        twm=[10.0, +Inf],
        maxdepth =[-Inf, +Inf],
        swb=[400,+Inf]
    ),
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
    env_variables)
    if get_characteristic(pft, :c4)
        return Savanna()
    elseif  get_characteristic(pft, :name) == "TropicalEvergreen"
        return TropicalEvergreenForest()
    elseif get_characteristic(pft, :name) == "TemperateDeciduous"
        return TemperateDeciduousForest()
    else
        return Biome.assign_biome(pft;
                subpft=subpft,
                wdom=wdom,
                gdd0=gdd0,
                gdd5=gdd5,
                tcm=tcm,
                tmin=tmin,
                pftlist=pftlist,
                pftstates=pftstates,
                gdom=gdom,
                env_variables=env_variables)
    end
end

PFTList = PFTClassification([
        BroadleafDeciduousPFT(),
        C3GrassPFT(),
        C4GrassPFT(),
        TropicalEvergreen,
        TemperateDeciduous
    ]
)

setup = ModelSetup(BaseModel();
                   temp=temp_raster,
                   prec=prec_raster,
                   clt= clt_raster,
                   ksat=ksat_raster,
                   whc= whc_raster,
                   co2=373.8,
                   pftlist = PFTList,
                   biome_assignment = my_biome_assign)

run!(setup; coordstring="alldata", outfile="output_CustomModel3.nc")
