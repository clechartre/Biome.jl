using Biome
using Rasters

tempfile = "/Users/capucinelechartre/Documents/PhD/BIOME4Py/data/generated_data/climatologies/temp_1981-2010.nc"
precfile = "/Users/capucinelechartre/Documents/PhD/BIOME4Py/data/generated_data/climatologies/prec_1981-2010.nc"
cltfile = "/Users/capucinelechartre/Documents/PhD/BIOME4Py/data/generated_data/climatologies/sun_1981-2010.nc"
soilfile = "/Users/capucinelechartre/Documents/PhD//makesoil/output/soils_55km.nc"

temp_raster = Raster(tempfile, name="temp")
prec_raster = Raster(precfile, name="prec")
clt_raster = Raster(cltfile, name="sun")
ksat_raster = Raster(soilfile, name="Ksat")
whc_raster = Raster(soilfile, name="whc")


# FIXME check what happens if I pass a random PFT list, it should get ovewritten by BIOME4 PFTs but 
# maybe we should put a warning sign

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

# 2. Run it in one line
run!(setup; coordstring="alldata", outfile="output_biome4_fallbacklist.nc")
