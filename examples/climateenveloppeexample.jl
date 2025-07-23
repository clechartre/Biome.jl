using Biome
using Rasters

tempfile = "/Users/capucinelechartre/Documents/PhD/BIOME4Py/data/generated_data/climatologies/temp_1981-2010.nc"
precfile = "/Users/capucinelechartre/Documents/PhD/BIOME4Py/data/generated_data/climatologies/prec_1981-2010.nc"

temp_raster = Raster(tempfile, name="temp")
prec_raster = Raster(precfile, name="prec")

# 1. Build a ModelSetup in one line (all kws, no long positional list)
setup = ModelSetup(KoppenModel;
                   temp=temp_raster,
                   prec=prec_raster)

# 2. Run it in one line
run!(setup; coordstring="alldata", outfile="output_Koppen.nc")
