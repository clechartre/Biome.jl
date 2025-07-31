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

PFTList = PFTClassification([
        EvergreenPFT(),
        DeciduousPFT(),
        TundraPFT(),
        GrassPFT(),
    ]
)

setup = ModelSetup(BIOME4Model;
                   temp=temp_raster,
                   prec=prec_raster,
                   sun=clt_raster,
                   ksat=ksat_raster,
                   whc=whc_raster,
                   co2=373.8,
                   PFTList = PFTList)

run!(setup; coordstring="alldata", outfile="output_biome4t.nc")
