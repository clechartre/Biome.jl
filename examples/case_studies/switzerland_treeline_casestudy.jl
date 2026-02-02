"""
Example of adapting the characteristics of a pre-existing PFT 
given regional parameters and running the BIOME4 model with the 
modified characteristics. 
"""

using Biome
using Rasters

tempfile = ""
precfile = ""
cltfile = ""
soilfile = ""

temp_raster = Raster(tempfile, name="temp")
prec_raster =  Raster(precfile, name="prec")
clt_raster =  Raster(cltfile, name="clt")
ksat_raster =  Raster(soilfile, name="Ksat")
whc_raster =  Raster(soilfile, name="whc")

# Load the BIOME4 PFT List
PFTList = BIOME4.PFTClassification{Float64, Int}()
# Custom set the ranges estimated during tuning
set_characteristic!(PFTList, "BorealEvergreen", :gdd5, [350.0, 1200.0])
set_characteristic!(PFTList, "BorealDeciduous", :gdd5, [1250.0, 1750.0])

# Set up the model
setup = ModelSetup(BIOME4Model();
                   temp=temp_raster,
                   prec=prec_raster,
                   clt=sun_raster,
                   ksat=ksat_raster,
                   whc=whc_raster,
                   co2=378.8,
                   pftlist = PFTList)

# Run the model 
run!(setup; coordstring="alldata", outfile="output_switzerland.nc")
