# Plant functional types 

## The PFT concept

Plant functional types (PFTs) are the basis of the mechanical schemes. Instead of defining individual species, which tend to be restricted to a single area of the globe, or not extensively studies, PFTs allow to generalize life forms and strategies. 

The defintion of PFTs often includes information on their climatic range and on their phenology, leaf form, or general energy acquisition strategy. For instance, the original PFTs used in BIOME4 are: Tropical Evergreen, Tropical Deciduous, Temperate Broadleaved Evergreen, Temperate Deciduous, Temperate Needleleaf Everegreen, Boreal Evergreen, Boreal Deciduous, Temperate C3 Grass, Tropical/Warm-temperate Grass (C4), Desert Woody (C3 or C4), Tundra Shrub, Cold Herbaceous, Lichen/Forb (Kaplan & Prentice., 2004). However, this list is not finite and could be extended to for example: Epiphytes, CAM Succulents, C4 Forbs, Mangroves, and so on. 


## PFTs in the model 
In this package, we provide you with base PFTs based on Phenology: Deciduous, Evergreen, Grass and Tundra. And with additional traits you could add onto them to compose your own PFT: Broadleaf/Needleleaf, Tropical/Temperate/Boreal. You also can manually modify these traits (see [defining your own PFTs](#defining-your-own-pfts)). 

We provide you with 5 base PFTs: 3 trees (evergreen): Temperate, Tropical, Boreal; and 2 Grass-like: Grass and Tundra, and a Default and None with 0/default values. We have initialized them with generic parameters. 

When running the BIOME4 model, the default PFTs as defined by Kaplan and Prentice (2004) will be used. 

## PFT traits in the model

The model is based on a series traits used to compute the growth of each PFT through photosynthesis, water acquisition, heterotropic respiration, ... 

1. **`phenological_type`**  
   - `1.0` – Evergreen  
   - `2.0` – Deciduous  
   - `3.0` – Grass  

2. **`max_min_canopy_conductance`** (mm s⁻¹)  
   - `gmin` – Plant water loss not directly associated with photosynthesis  
   - Linearly related to the maximum daily photosynthesis rate (Schultz et al., 1994; Körner, 1994)

3. **`Emax`** – Maximum transpiration rate (mm s⁻¹)  
   - Maximum daily transpiration possible under well‑watered conditions  
   - Assigned a value of 5 mm d⁻¹ based on model performance differences among vegetation classes (guesstimated)

4. **`sw_drop`** – Soil water content at which stomata start to close

5. **`sw_appear`** – Soil water content at which stomata start to open

6. **`root_fraction_top_soil`** – Fraction of roots in the topsoil layer  
   - Rooting depths from Haxeltine et al., 1996

7. **`leaf_longevity`** – Leaf longevity (years)

8. **`GDD5_full_leaf_out`** – Growing degree days for full leaf‐out above 5 °C

9. **`GDD0_full_leaf_out`** – Growing degree days for full leaf‐out above 0 °C  
   - GDD = ∑(mean daily temperature – minimum temperature for growth)  
   - Max. growing‐season LAI:  
     - 200 for summergreen woody PFTs as per the BIOME3 model (Haxeltine & Prentice., 1996). 
     - 50 for summergreen grasses  
     - “Rationale for raingreens” calculated in BIOME3 paper

10. **`sapwood_respiration`** – Sapwood respiration rate  
    - This value takes 1 or 2. 1 for woody types and 2 for grassy types. 

11. **`optratioa`** – Optimal leaf‐area : sapwood‐area ratio

12. **`kk`** – Light extinction coefficient

13. **`c4`** – C4 photosynthesis flag

14. **`threshold`** – LAI : sapwood‐area ratio threshold

15. **`t0`** – Reference temperature for growth initiation (°C)

16. **`tcurve`** – Temperature response curve

17. **`respfact`** – Respiration factor  
   - Estimated from sapwood respiration rates and reference temperatures

18. **`allocfact`** – Allocation factor for leaf vs. litter mass  
   - Raich & Nadelhoffer, 1989; modified by Sprugel et al., 1996; Ryan, 1991; Runyon et al., 1994

19. **`grass`** – Grass functional flag

20. **`dominance factor`** - the capacity of the PFT to dominate, even in stressful conditions. Values are extracted from the work of Prentice et al., 1992. 

## Ecophysiological Constraints

The model selects viable PFTs for each grid cell based on constraints below (Prentice et al., 1992; Woodward, 1997).

1. **`tcm`** – Minimum and maximum temperature for carbon assimilation (°C)

2. **`min`** – Minimum temperature for growth (°C)

3. **`gdd`** – Growing degree days for growth initiation

4. **`gdd0`** – Growing degree days for growth initiation at 0 °C

5. **`twm`** – Minimum temperature for water limitation (°C)

6. **`snow`** – Snow depth for growth initiation (cm)

7. **`swb`** - Soil water balance. 


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
PFTList = BIOME4.PFTClassification()

# Customize using set_characteristic! 
set_characteristic!(PFTList, "LichenForb", :Emax, 999999.0)
set_characteristic!(PFTList, "LichenForb", :tcm, [99999.0, Inf])
`````


## References

* Haxeltine, A., & Prentice, I. C. (1996). BIOME3: An equilibrium terrestrial biosphere model based on ecophysiological constraints, resource availability, and competition among plant functional types. Global Biogeochemical Cycles, 10(4), 693–709. https://doi.org/10.1029/96GB02344

* Kaplan, J., & Prentice, I. (2001). Geophysical Applications of Vegetation Modeling.

* Prentice, I. C., Cramer, W., Harrison, S. P., Leemans, R., Monserud, R. A., & Solomon, A. M. (1992). Special Paper: A Global Biome Model Based on Plant Physiology and Dominance, Soil Properties and Climate. Journal of Biogeography, 19(2), 117–134. https://doi.org/10.2307/2845499
