using Biome
using Rasters

tasfile = ""
prfile = ""
cltfile = ""
soilfile = ""

tas_raster = Raster(tasfile, name="tas")
pr_raster = Raster(prfile, name="pr")
clt_raster = Raster(cltfile, name="clt")
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

# Optional: select specific coordinates
# See Rasters.jl documentation for how to select bounds
nz_bounds = X(165 .. 180), Y(-50 .. -32)

execute(setup; bounds=nz_bounds, outfile="output_BaseModel.nc")

# Optional: return an object and don't write to disk

output = execute(setup; bounds=nz_bounds)