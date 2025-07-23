using Biome
using Rasters

tempfile = ""
precfile = ""

temp_raster = Raster(tempfile, name="temp")
prec_raster = Raster(precfile, name="prec")

setup = ModelSetup(KoppenModel;
                   temp=temp_raster,
                   prec=prec_raster)

run!(setup; coordstring="alldata", outfile="output_Koppen.nc")
