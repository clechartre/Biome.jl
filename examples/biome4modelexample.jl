using Biome
using Rasters

tempfile = "/cluster/scratch/clechartre/ch_data/chelsa_emerge/pr/pr/CHELSA_HR_tas_climatology_1981-1990_fixed.nc"
precfile = "/cluster/scratch/clechartre/ch_data/chelsa_emerge/pr/pr/CHELSA_HR_pr_climatology_1981-1990_fixed.nc"
cltfile = "/cluster/scratch/clechartre/ch_data/chelsa_emerge/clt/CHELSA_HR_clt_climatology_1981-1990_fixed.nc"
soilfile = "/cluster/scratch/clechartre/ch_data/soils_on_clt_bilin.nc"

temp_raster =  Raster(tempfile, name="tas")
prec_raster =  Raster(precfile, name="pr")
clt_raster =  Raster(cltfile, name="clt")
ksat_raster =  Raster(soilfile, name="Ksat")
whc_raster =  Raster(soilfile, name="whc")

PFTList = BIOME4.PFTClassification()
set_characteristic!(PFTList, "BorealEvergreen", :gdd5, [600.0, Inf])
# set_characteristic!(PFTList, "BorealEvergreen", :gdd0, [param3, param4])

set_characteristic!(PFTList, "BorealDeciduous", :gdd5, [740.0, 790.0])
set_characteristic!(PFTList, "BorealDeciduous", :gdd0, [1210.0, Inf])

println("PFTList: ", PFTList)


# Values of Co2
# 1981-1990: 346.7
# 1991-2000: 361.4
# 2001-2010: 379.86
setup = ModelSetup(BIOME4Model();
                   temp=temp_raster,
                   prec=prec_raster,
                   clt=clt_raster,
                   ksat=ksat_raster,
                   whc=whc_raster,
                   co2=346.7,
                   PFTList = PFTList)

run!(setup; coordstring="alldata", outfile="/cluster/scratch/clechartre/ch_data/output_switzerland_1981-1990_2.nc")
