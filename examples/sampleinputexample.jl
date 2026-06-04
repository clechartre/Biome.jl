using Biome
using Rasters

tasfile = "sample_input/temp_leemans.nc"
prfile = "sample_input/prec_leemans.nc"
cltfile = "sample_input/sun_leemans.nc"
soilfile = "sample_input/soils_55km.nc"

tas_raster = Raster(tasfile, name="temp")
pr_raster = Raster(prfile, name="prec")
clt_raster = Raster(cltfile, name="sun")
ksat_raster = Raster(soilfile, name="Ksat")
whc_raster = Raster(soilfile, name="whc")

# BasePTS
pftlist = PFTClassification([
    NeedleleafEvergreenPFT(),
    BroadleafEvergreenPFT(),
    NeedleleafDeciduousPFT(),
    BroadleafDeciduousPFT(),
    C3GrassPFT(),
    C4GrassPFT()
])

setup = ModelSetup(BaseModel();
                   tas=tas_raster,
                   pr=pr_raster,
                   clt= clt_raster,
                   ksat=ksat_raster,
                   whc= whc_raster,
                   co2=373.8,
                   pftlist = pftlist)


execute(setup;  outfile="output_sample_inputs.nc")
