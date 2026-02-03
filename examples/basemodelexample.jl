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
                   temp=temp_raster,
                   prec=prec_raster,
                   clt= clt_raster,
                   ksat=ksat_raster,
                   whc= whc_raster,
                   co2=373.8,
                   pftlist = pftlist)

execute(setup; coordstring="alldata", outfile="output_BaseModel.nc")
