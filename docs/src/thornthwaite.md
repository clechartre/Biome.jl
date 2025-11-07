# Thornthwaite

The Thornthwaite system (1931 – 1948) classifies climates both by how effectively precipitation meets evaporative demand and by thermal efficiency. It uses **monthly** temperature and precipitation to derive two indices—precipitation-effectiveness (PE) and thermal-efficiency (TE)—and assigns each grid cell to a **moisture zone** and a **temperature zone**.

<figure>
  <img src="assets/output_thornthwaite_examples.svg" alt="Example Thornthwaite climate zones (moisture and temperature classes)" width="100%">
  <figcaption><strong>Figure.</strong> Example Thornthwaite classification map.</figcaption>
</figure>

In our method, twelve monthly temperatures and precipitations are used to compute a precipitation-effectiveness index (PE) and a thermal-efficiency index (TE). PE then places the site into one of five moisture zones (Wet, Humid, Subhumid, Semiarid, Arid), and TE into one of six temperature zones (Tropical, Mesothermal, Microthermal, Taiga, Tundra, Frost), each mapped via simple thresholds.

These are the classes (row-major order: moisture × temperature):

| Moisture \ Temp | Tropical (1) | Mesothermal (2) | Microthermal (3) | Taiga (4) | Tundra (5) | Frost (6) |
|---|---:|---:|---:|---:|---:|---:|
| **Wet**       | **1**  | **2**  | **3**  | **4**  | **5**  | **6**  |
| **Humid**     | **7**  | **8**  | **9**  | **10** | **11** | **12** |
| **Subhumid**  | **13** | **14** | **15** | **16** | **17** | **18** |
| **Semiarid**  | **19** | **20** | **21** | **22** | **23** | **24** |
| **Arid**      | **25** | **26** | **27** | **28** | **29** | **30** |


> Moisture order: Wet, Humid, Subhumid, Semiarid, Arid (1→5)  
> Temperature order: Tropical, Mesothermal, Microthermal, Taiga, Tundra, Frost (1→6)

## How to run it

```julia
using Biome
using Rasters

# Minimal inputs
tempfile = "/path/to/temp.nc"   # monthly mean temperature (stacked in 3rd dim)
precfile = "/path/to/prec.nc"   # monthly precipitation (same grid/stacking)

temp_raster = Raster(tempfile, name="temp")
prec_raster = Raster(precfile,  name="prec")

setup = ModelSetup(ThornthwaiteModel();
                   temp=temp_raster,
                   prec=prec_raster)

# Process full grid (or pass "lonmin/lonmax/latmin/latmax")
run!(setup; coordstring="alldata", outfile="output_Thornthwaite.nc")
````


## References
* Thornthwaite, C. W. (1931). The climates of North America: According to a new classification. , 21(4),. JSTOR. Geographical Review, 633–655.