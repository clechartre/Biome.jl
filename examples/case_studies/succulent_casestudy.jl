"""
Example of setting up a succulent PFT and a succulent biome and runnign the model on it.
"""

using Biome
using Rasters
 
tempfile = ""
precfile = ""
cltfile = ""
soilfile = ""
tminfile = ""

temp_raster =  Raster(tempfile, name="temp")
prec_raster = Raster(precfile, name="prec")
# prec_raster.= ifelse.(coalesce.(prec_raster, -9999) .!= -9999, 10 .* coalesce.(prec_raster, -9999), -9999)
clt_raster = Raster(cltfile, name="sun")
sun_raster = copy(clt_raster)
sun_raster .= ifelse.(coalesce.(clt_raster, -9999) .!= -9999, 100 .- coalesce.(clt_raster, -9999), -9999)
ksat_raster =  Raster(soilfile, name="Ksat")
whc_raster =  Raster(soilfile, name="whc")
tmin_raster = Raster(tminfile, name = "tmin")

# Add a PFT to the list:
SucculentPFT = BroadleafDeciduousPFT(
    name = "Succulent",
    phenological_type           = 2,    #  1: evergreen, 2: deciduous, many are deciduous
    max_min_canopy_conductance  = 0.05, # Took the same value as C3C4WoodyDesert
    Emax                        = 8.0,
    sw_drop                     = -99.9,
    sw_appear                   = -99.9,
    root_fraction_top_soil      = 0.9, # Wide, shallow root systems, sometimes with a central taproot
    # The diffuse, shallow roots of storage succulents are extremely well adapted for rapid rehydration  
    leaf_longevity              = 30.0,
    GDD5_full_leaf_out          = -99.9,
    GDD0_full_leaf_out          = -99.9,
    sapwood_respiration         = 2, # Succulent do CAM photosynthesis, they don't have sapwood bc non woody
    optratioa                   = 0.7,
    kk                          = 0.3,
    c4                          = false,
    threshold                   = 0.25, # They are NOT fire resistant, check what value would fit here
    t0                          = 10.0,
    tcurve                      = 1.0,
    respfact                    = 1.6,
    allocfact                   = 1.0,
    grass                       = false,
    constraints = (
            tcm=[5, +Inf],
            tmin=[-5, +Inf],
            gdd5=[-Inf, +Inf],
            gdd0=[-Inf, 10000],
            twm=[-Inf, +Inf],
            maxdepth=[-Inf, +Inf],
            swb=[5, 44],
            tpr = [0, 1200]
    ),
    dominance_factor = 3,
    minimum_lai = 2.0 # dominated by small-leaved often spinescent trees
)
 
 
# Add the PFT to the PFT list
PFTList = BIOME4.PFTClassification()
push!(PFTList.pft_list, SucculentPFT)
 
# Biome definition - add a biome that includes this PFT
struct SucculentBiome  <: AbstractBiome
    value::Int
    SucculentBiome() = new(30)
end
 
# Define a custom biome assignment function that attributes the 
# succulent biome to areas dominated by succulent PFTs but return other biomes like desert or 
# grasslands if the conditions for a succulent biome are not met. 
function my_biome_assign(pft::AbstractPFT;
    subpft,
    wdom,
    gdd0,
    gdd5,
    tcm,
    tmin,
    pftlist,
    pftstates,
    gdom,
    env_variables
    )
 
    if get_characteristic(pft, :name) == "Succulent"
        if pftstates[pft].npp > 100 #&& pftstates[wdom].firedays < 150.0
            return SucculentBiome()
        elseif pftstates[pft].npp <= 100 && pftstates[wdom].firedays >= 130.0
            return BIOME4.Desert()
        elseif pftstates[pft].npp < 100 && pftstates[wdom].firedays <= 130.0
                # Copied the assign biomefunction from BIOME4 for default
                if wdom === nothing || isa(wdom, BIOME4.TropicalEvergreen) || isa(wdom, BIOME4.TropicalDroughtDeciduous)
                    if wdom !== nothing && pftstates[wdom].lai > 4.0
                        return BIOME4.TropicalSavanna()
                    else
                        return BIOME4.TropicalXerophyticShrubland()
                    end
                elseif isa(wdom, BIOME4.TemperateBroadleavedEvergreen)
                    return BIOME4.TemperateSclerophyllWoodland()
                elseif isa(wdom, BIOME4.TemperateDeciduous)
                    return BIOME4.TemperateBroadleavedSavanna()
                elseif isa(wdom, BIOME4.CoolConifer)
                    return BIOME4.OpenConiferWoodland()
                elseif isa(wdom, BIOME4.BorealEvergreen) || isa(wdom, BIOME4.BorealDeciduous)
                    return BIOME4.BorealParkland()
                elseif isa(wdom, BIOME4.WoodyDesert)
                    if pftstates[wdom].npp > 100.0
                        if pftstates[gdom].lai > 1.0
                            return tmin >= 0.0 ? BIOME4.TropicalXerophyticShrubland() :
                                BIOME4.TemperateXerophyticShrubland()
                        else
                            return BIOME4.Desert()
                        end
                    else
                        return BIOME4.Desert()
                    end
                else
                    return BIOME4.Barren()
                end
        elseif pftstates[wdom].firedays > 110.0
            return BIOME4.TropicalSavanna()
        else
            return SucculentBiome()
        end
    else
        return BIOME4.assign_biome(pft;
            subpft=subpft,
            wdom=wdom,
            gdom=gdom,
            gdd0=gdd0,
            gdd5=gdd5,
            tcm=tcm,
            tmin=tmin,
            pftlist=pftlist,
            pftstates=pftstates)
    end
end
 
setup = ModelSetup(BIOMEDominanceModel();
                   tas=temp_raster,
                   pr=prec_raster,
                   clt=sun_raster,
                   ksat=ksat_raster,
                   whc=whc_raster,
                   tmin=tmin_raster,
                   co2=Float64.(373.0),
                   pftlist = PFTList,
                   biome_assignment = my_biome_assign)
 
# Run the model
execute(setup; outfile="output_succulent.nc")
 