# Data

This user guide describes the basic structures and functions to run the base models provided in the package, and define your biome schemes and run them.

---

## Requirements in input data

### Climatological and soil input

#### 1) Climatological data
The climatological variables—**temperature**, **tmin**, **cloud cover**, and **precipitation**—are downloaded from the [CHELSA database](https://chelsa-climate.org/bioclim/).  
Each variable is available **per month for a specified year**. In addition to yearly data, CHELSA also provides **multi-year climatologies** (averaged datasets over longer time periods).

#### 2) Soil characteristics data
Soil characteristics are generated using the [makesoil](https://github.com/ARVE-Research/makesoil) module from ARVE Research.  
This script produces a NetCDF file with the two variables required by BIOME4:

- **whc** — soil water-holding capacity  
- **Ksat** — soil saturated conductivity

---

## Climate envelope models

The climate envelope models here are a Julia re-implementation of the CHELSA module for mapping climatologies at high resolutions  
(see: [CHELSA 1-km Köppen-Geiger](https://chelsa-climate.org/1-km-global-koppen-geiger-climate-classification-for-present-and-future/) and the original SAGA tool:  
[climate_tools_19](https://saga-gis.sourceforge.io/saga_tool_doc/7.3.0/climate_tools_19.html)).

**Inputs:**

- **Thornthwaite, TrollPfaffen, Wissmann**
  - Temperature climatologies
  - Precipitation climatologies
- **Köppen–Geiger**
  - Temperature climatologies
  - Precipitation climatologies
  - **Latitude and longitude** information (for seasonal partitioning/hemisphere logic)

---

## Mechanistic models

The **BIOME4** model and other **PFT-based** frameworks require the following gridded inputs:

- Climatological **monthly mean temperature** (°C)
- Climatological **monthly mean cloud cover** (%)
- Climatological **monthly total precipitation** (mm)
- **Soil water-holding capacity** in two or more layers (mm/mm)
- **Soil saturated conductivity** in two or more layers (mm/h)

BIOME4 also requires a **single global value** for atmospheric **CO₂** concentration.

---
