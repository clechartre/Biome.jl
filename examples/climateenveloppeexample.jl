"""
Example of running a climate enveloppe model.
"""

using Biome
using Rasters

tasfile = ""
prfile = ""

tas_raster = Raster(tasfile, name="tas")
pr_raster = Raster(prfile, name="pr")

setup = ModelSetup(KoppenModel();
                   tas = tas_raster,
                   pr = pr_raster)

execute(setup; outfile = "output_Koppen.nc")
