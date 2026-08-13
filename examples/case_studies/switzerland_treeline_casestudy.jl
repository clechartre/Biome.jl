"""
Example of adapting the characteristics of a pre-existing PFT 
given regional parameters and running the BIOME4 model with the 
modified characteristics. 
"""

using Biome
using Rasters

tasfile = ""
prfile = ""
cltfile = ""
soilfile = ""

tas_raster = Raster(tempfile, name="tas")
pr_raster =  Raster(precfile, name="pr")
clt_raster =  Raster(cltfile, name="clt")
ksat_raster =  Raster(soilfile, name="Ksat")
whc_raster =  Raster(soilfile, name="whc")

# Load the BIOME4 PFT List
PFTList = BIOME4.PFTClassification{Float64, Int}()
# Custom set the ranges estimated during tuning
set_characteristic!(PFTList, "BorealEvergreen", :gdd5, [443.0, +Inf])
set_characteristic!(PFTList, "BorealDeciduous", :gdd5, [873.0, +Inf])

# Set up the model
setup = ModelSetup(BIOME4Model();
                   tas=tas_raster,
                   pr=pr_raster,
                   clt=sun_raster,
                   ksat=ksat_raster,
                   whc=whc_raster,
                   co2=378.8,
                   pftlist = PFTList)

# Run the model 
execute(setup; outfile="output_switzerland.nc")
