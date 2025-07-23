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
PFTList = PFTClassification([
        EvergreenPFT(),
        DeciduousPFT(),
        TundraPFT(),
        GrassPFT(),
    ]
)
setup = ModelSetup(BaseModel;
                   temp=temp_raster,
                   prec=prec_raster,
                   sun= clt_raster,
                   ksat=ksat_raster,
                   whc= whc_raster,
                   co2=373.8,
                   PFTList = PFTList)

run!(setup; coordstring="-180/0/-90/90", outfile="output_BaseModelSavanna.nc")
