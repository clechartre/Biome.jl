"""
Example of how to run the BIOME4 model.
"""

using Biome
using Rasters

tempfile = ""
precfile = ""
cltfile = ""
soilfile = ""

temp_raster =  Raster(tempfile, name="tas")
prec_raster =  Raster(precfile, name="pr")
clt_raster =  Raster(cltfile, name="clt")
ksat_raster =  Raster(soilfile, name="Ksat")
whc_raster =  Raster(soilfile, name="whc")

PFTList = BIOME4.PFTClassification()

setup = ModelSetup(BIOME4Model();
                   temp = temp_raster,
                   prec = prec_raster,
                   clt = clt_raster,
                   ksat = ksat_raster,
                   whc = whc_raster,
                   co2 = 373.8,
                   PFTList = PFTList)

# Optional: select specific coordinates
# See Rasters.jl documentation for how to select bounds
nz_bounds = X(165 .. 180), Y(-50 .. -32)

execute(setup; bounds = nz_bounds, outfile = "output_BIOME4.nc")
