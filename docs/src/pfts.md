# Plant functional types 

## The PFT concept

Plant functional types (PFTs) are the basis of the mechanical schemes. Instead of defining individual species, which tend to be restricted to a single area of the globe, or not extensively studies, PFTs allow to generalize life forms and strategies. 

The defintion of PFTs often includes information on their climatic range and on their phenology, leaf form, or general energy acquisition strategy. For instance, the original PFTs used in BIOME4 are: Tropical Evergreen, Tropical Deciduous, Temperate Broadleaved Evergreen, Temperate Deciduous, Temperate Needleleaf Everegreen, Boreal Evergreen, Boreal Deciduous, Temperate C3 Grass, Tropical/Warm-temperate Grass (C4), Desert Woody (C3 or C4), Tundra Shrub, Cold Herbaceous, Lichen/Forb (Kaplan & Prentice., 2004). However, this list is not finite and could be extended to for example: Epiphytes, CAM Succulents, C4 Forbs, Mangroves, and so on. 


## PFTs in the model 
In this package, we provide you with base PFTs based on Phenology: Deciduous, Evergreen, Grass and Tundra. And with additional traits you could add onto them to compose your own PFT: Broadleaf/Needleleaf, Tropical/Temperate/Boreal. You also can manually modify these traits (see [defining your own PFTs](#defining-your-own-pfts)). 

We provide you with 5 base PFTs: 3 trees (evergreen): Temperate, Tropical, Boreal; and 2 Grass-like: Grass and Tundra, and a Default and None with 0/default values. We have initialized them with generic parameters. 

When running the BIOME4 model, the default PFTs as defined by Kaplan and Prentice (2004) will be used. 

## PFT traits in the model

The model is based on a series traits used to compute the growth of each PFT through three main processes (Hallgren & Pitman, 2001): 
* photosynthesis
* evaopotranspiration
* root distribution

### Ecophysiological traits

| Parameter                  | Category             | Description                                                                                 | Min         | Max         | Source                               |
|---------------------------|----------------------|---------------------------------------------------------------------------------------------|-------------|-------------|--------------------------------------|
| `kk`                      | Photosynthesis       | Light extinction coefficient                                                               | 0.3         | 0.7         | Larcher (1995)                       |
| `c4`                      | Photosynthesis       | C4 photosynthesis flag (true = C4, false = C3)                                              | Bool        | Bool        | -                                    |
| `optratioa` (C3)          | Photosynthesis       | Optimal Ci/Ca ratio for C3                                                                  | 0.5         | 0.6         | Haxeltine et al. (1996)              |
| `optratioa` (C4)          | Photosynthesis       | Optimal Ci/Ca ratio for C4                                                                  | 0.31        | 0.4         | Wong et al. (1979), Collatz et al. (1992) |
| `sw_drop`                 | Photosynthesis       | Soil water content at which stomata start to close                                         | -           | -           | Not specified                        |
| `sw_appear`               | Photosynthesis       | Soil water content at which stomata start to open                                          | -           | -           | Not specified                        |
| `max_min_canopy_conductance` | Evapotranspiration | Min/max canopy conductance (mm s⁻¹), related to photosynthesis                             | 2.5         | 20          | Monteith (1995)                      |
| `Emax`                    | Evapotranspiration   | Maximum daily transpiration under well-watered conditions (mm s⁻¹)                         | 2.4         | 6.4         | Whitehead et al. (1993); Stewart & Gay (1989) |
| `sapwood_respiration`     | Respiration          | Sapwood respiration type (1 = woody, 2 = grass)                                             | 1           | 2           | -                                    |
| `respfact`                | Respiration          | Sapwood maintenance respiration (g C kg⁻¹ month⁻¹)                                          | 1.3         | 2.0         | -                                    |
| `phenological_type`       | General              | Phenology type: 1 = Evergreen; 2 = Deciduous; 3 = Grass                                    | 1           | 3           | -                                    |
| `root_fraction_top_soil`  | General              | Fraction of roots in topsoil layer                                                         | -           | -           | Haxeltine et al. (1996)              |
| `leaf_longevity`          | General              | Leaf longevity (years)                                                                     | 0.5         | 7           | Hallgren & Pitman (2001)            |
| `GDD5_full_leaf_out`      | General              | Growing degree days above 5 °C for full leaf-out                                           | 50          | 200         | Haxeltine & Prentice (1996)         |
| `GDD0_full_leaf_out`      | General              | Growing degree days above 0 °C for full leaf-out                                           | -           | -           | -                                    |
| `threshold`               | General              | LAI:sapwood-area threshold                                                                 | 0.01        | 0.2         | Hallgren & Pitman (2001)            |
| `t0`                      | General              | Reference temperature for growth initiation (°C)                                           | -           | -           | -                                    |
| `tcurve`                  | General              | Temperature response curve                                                                 | -           | -           | -                                    |
| `allocfact`               | General              | Allocation factor for leaf vs litter mass                                                  | -           | -           | Raich & Nadelhoffer (1989)          |
| `grass`                   | General              | Grass flag (true = grass functional type)                                                  | Bool        | Bool        | -                                    |
| `dominance_factor`        | General              | Capacity to dominate in harsh conditions                                                   | 1           | 10          | Prentice et al. (1992)               |

### Climatic Constraints

| Parameter     | Description                                              | Min      | Max      | Source                            |
|---------------|----------------------------------------------------------|----------|----------|-----------------------------------|
| `tcm`         | Min/max temperature of coldest month (°C)               | -65      | +15      | Hallgren & Pitman (2001), Table 2 |
| `min`         | Minimum temperature for growth (°C)                     | -45      | +5       | Haxeltine et al. (1996)           |
| `gdd`         | GDD for growth initiation (base unspecified)            | 300      | 1800     | Hallgren & Pitman (2001)          |
| `gdd0`        | GDD for growth initiation above 0 °C                    | 500      | 2000     | Hallgren & Pitman (2001)          |
| `twm`         | Temperature for water limitation growth cutoff (°C)     | 0        | 15       | Hallgren & Pitman (2001)          |
| `snow`        | Snow depth required for growth (cm)                     | 0        | 100      | Hallgren & Pitman (2001)          |
| `swb`         | Soil water balance (mm)                                 | 0     | 2000      | Added in this iteration of the model        |


## Defining your own PFTs

You can modify individual parameters of your base PFT by doing: 

````
C4Grass =  GrassPFT(c4 = true, name = "C4Grass")


TropicalDeciduous = TropicalPFT(phenological_type = 2)
````
These subtypes will inherit the supertypes of our base PFTs, useful later on in your biome definition 

`````
typeof(C4Grass)
GrassPFT{Float64, Int64}

typeof(TropicalDeciduous)
TropicalPFT{Float64, Int64}
`````

You can also completely define your PFT from the base. For example, here is a WoodyDesert plant from BIOME4: 

`````
function WoodyDesert()
    return WoodyDesert{T,U}(
        PFTCharacteristics{T,U}(
            "C3C4WoodyDesert",
            1,
            0.1,
            1.0,
            -99.9,
            -99.9,
            0.53,
            12.0,
            -99.9,
            -99.9,
            U(1,
            0.70,
            0.3,
            true,
            0.33,
            5.0,
            1.0,
            1.4,
            1.0,
            false,
            (
                tcm=[-Inf, +Inf],
                min=[-45.0, +Inf],
                gdd=[500, +Inf],
                gdd0=[-Inf, +Inf],
                twm=[10.0, +Inf],
                snow=[-Inf, +Inf],
                swb=[-Inf,500]
            ),
            (clt=9.2, prec=2.5, temp=23.9),
            (clt=2.2, prec=2.8, temp=2.7))
        ).
        dominance_factor = 5
    )
end


WoodyDesert() = WoodyDesert()

`````
## Modifying existing PFTs 

You can also choose to load some of the existing PFT lists and to modify a single parameter at a time. This is very useful for parameter optimization and tuning.
A helper function helps you to do so.
Below is an example on updating the PFT named "LichenForb" from the PFT list for Emax and then for the constraint tcm (temperature of the coldest month).

`````
pftlist = BIOME4.PFTClassification()

# Customize using set_characteristic! 
set_characteristic!(pftlist, "LichenForb", :Emax, 999999.0)
set_characteristic!(pftlist, "LichenForb", :tcm, [99999.0, Inf])
`````


## References

* Hallgren, Willow & Pitman, AJ. (2001). The uncertainty in simulations by a Global Biome Model (BIOMES) to alternative parameter values. Global Change Biology. 6. 483 - 495. 10.1046/j.1365-2486.2000.00325.x. 

* Haxeltine, A., & Prentice, I. C. (1996). BIOME3: An equilibrium terrestrial biosphere model based on ecophysiological constraints, resource availability, and competition among plant functional types. Global Biogeochemical Cycles, 10(4), 693–709. https://doi.org/10.1029/96GB02344

* Kaplan, J., & Prentice, I. (2001). Geophysical Applications of Vegetation Modeling.

* Prentice, I. C., Cramer, W., Harrison, S. P., Leemans, R., Monserud, R. A., & Solomon, A. M. (1992). Special Paper: A Global Biome Model Based on Plant Physiology and Dominance, Soil Properties and Climate. Journal of Biogeography, 19(2), 117–134. https://doi.org/10.2307/2845499

