"""
Example of running a climate enveloppe model.
"""

using Biome
using Rasters

tempfile = ""
precfile = ""

temp_raster = Raster(tempfile, name="temp")
prec_raster = Raster(precfile, name="prec")

setup = ModelSetup(KoppenModel();
                   temp = temp_raster,
                   prec = prec_raster)

execute(setup; outfile = "output_Koppen.nc")
