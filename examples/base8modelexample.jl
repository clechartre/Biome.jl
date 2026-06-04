"""
Example of how to run the Customizable base model.
"""

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
        C4GrassPFT(),
    ]
)

setup = ModelSetup(BaseModel();
                   tas=tas_raster,
                   pr=pr_raster,
                   clt=clt_raster,
                   ksat=ksat_raster,
                   whc= whc_raster,
                   co2=373.8,
                   pftlist = pftlist)

execute(setup; outfile="output_base.nc")
