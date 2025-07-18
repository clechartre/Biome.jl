# Defining PFTs

Plant functional types (PFTs) are the basis of the mechanical schemes. Instead of defining individual species, which tend to be restricted to a single area of the globe, or not extensively studies, PFTs allow to generalize life forms and strategies. 

The defintion of PFTs often includes information on their climatic range and on their phenology, leaf form, or general energy acquisition strategy. For instance, the original PFTs used in BIOME4 are: Tropical Evergreen, Tropical Deciduous, Temperate Broadleaved Evergreen, Temperate Deciduous, Temperate Needleleaf Everegreen, Boreal Evergreen, Boreal Deciduous, Temperate C3 Grass, Tropical/Warm-temperate Grass (C4), Desert Woody (C3 or C4), Tundra Shrub, Cold Herbaceous, Lichen/Forb. However, this list is not finite and could be extended to for example: Epiphytes, CAM Succulents, C4 Forbs, Mangroves, and so on. 


In this package, we provide you with base PFTs based on climate zone: Tropical, Temperate, Boreal, and Tundra. And with additional traits you could add onto them to compose your own PFT: Deciduous/Evergreen, Broadleaf/Needleleaf, Grass/Woody/Forb. You also can manually modify these traits. 

# PFT traits in the model

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
     - 200 for summergreen woody PFTs (BIOME3)  
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

### Ecophysiological Constraints

The model selects viable PFTs for each grid cell based on constraints below (Prentice et al., 1992; Woodward, 1997).

1. **`tcm`** – Minimum and maximum temperature for carbon assimilation (°C)

2. **`min`** – Minimum temperature for growth (°C)

3. **`gdd`** – Growing degree days for growth initiation

4. **`gdd0`** – Growing degree days for growth initiation at 0 °C

5. **`twm`** – Minimum temperature for water limitation (°C)

6. **`snow`** – Snow depth for growth initiation (cm)

7. **`swb`** - Soil water balance. 



