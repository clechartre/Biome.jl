# NetCDF code → biome / climate-class key

This document maps the integer **codes stored in the NetCDF variables** to the **biome / climate class names**.

---
## 1) Köppen–Geiger (`koppen_class`)

**NetCDF variable:** `koppen_class`  
**Biome codes:** `1–31`  

| Code | Label |
|---:|---|
| 1 | Equatorial fully humid (Af) |
| 2 | Equatorial monsoonal (Am) |
| 3 | Equatorial summer dry (As) |
| 4 | Equatorial winter dry (Aw) |
| 5 | Hot desert (BWh) |
| 6 | Cold desert (BWk) |
| 7 | Hot steppe (BSh) |
| 8 | Cold steppe (BSk) |
| 9 | Warm temperate fully humid hot summer (Cfa) |
| 10 | Warm temperate fully humid warm summer (Cfb) |
| 11 | Warm temperate fully humid cool summer (Cfc) |
| 12 | Warm temperate summer dry hot summer (Csa) |
| 13 | Warm temperate summer dry warm summer (Csb) |
| 14 | Warm temperate summer dry cool summer (Csc) |
| 15 | Warm temperate, winter dry, hot summer (Cwa) |
| 16 | Warm temperate, winter dry, warm summer (Cwb) |
| 17 | Warm temperate, winter dry, cool summer (Cwc) |
| 18 | Snow fully humid hot summer (Dfa) |
| 19 | Snow fully humid warm summer (Dfb) |
| 20 | Snow fully humid cool summer (Dfc) |
| 21 | Snow fully humid extremely continental (Dfd) |
| 22 | Snow summer dry hot summer (Dsa) |
| 23 | Snow summer dry warm summer (Dsb) |
| 24 | Snow summer dry cool summer (Dsc) |
| 25 | Snow summer dry extremely continental (Dsd) |
| 26 | Snow winter dry hot summer (Dwa) |
| 27 | Snow winter dry warm summer (Dwb) |
| 28 | Snow winter dry cool summer (Dwc) |
| 29 | Snow winter dry extremely continental (Dwd) |
| 30 | Polar tundra (ET) |
| 31 | Polar frost (EF) |
---

## 2) Thornthwaite (derived combined class from `moisture_zone` × `temperature_zone`)

**NetCDF variables:**  
- `moisture_zone` (codes `1–5`)  
- `temperature_zone` (codes `1–6`)

> `combined_code = (moisture_zone - 1) * 6 + temperature_zone`  

### 2.1 Moisture zone (`moisture_zone`)

| Code | Moisture label |
|---:|---|
| 1 | Wet |
| 2 | Humid |
| 3 | Subhumid |
| 4 | Semiarid |
| 5 | Arid |

### 2.2 Temperature zone (`temperature_zone`)

| Code | Temperature label |
|---:|---|
| 1 | Tropical |
| 2 | Mesothermal |
| 3 | Microthermal |
| 4 | Taiga |
| 5 | Tundra |
| 6 | Frost |

### 2.3 Combined Thornthwaite class (`biome_combined` in-memory)

**NetCDF variable:** `biome_combined`, computed in the plotting script `utils/plotting/plotting_thw.jl`
**Biome codes:** `1–30`  

| Code | Moisture / Temperature |
|---:|---|
| 1 | Wet / Tropical |
| 2 | Wet / Mesothermal |
| 3 | Wet / Microthermal |
| 4 | Wet / Taiga |
| 5 | Wet / Tundra |
| 6 | Wet / Frost |
| 7 | Humid / Tropical |
| 8 | Humid / Mesothermal |
| 9 | Humid / Microthermal |
| 10 | Humid / Taiga |
| 11 | Humid / Tundra |
| 12 | Humid / Frost |
| 13 | Subhumid / Tropical |
| 14 | Subhumid / Mesothermal |
| 15 | Subhumid / Microthermal |
| 16 | Subhumid / Taiga |
| 17 | Subhumid / Tundra |
| 18 | Subhumid / Frost |
| 19 | Semiarid / Tropical |
| 20 | Semiarid / Mesothermal |
| 21 | Semiarid / Microthermal |
| 22 | Semiarid / Taiga |
| 23 | Semiarid / Tundra |
| 24 | Semiarid / Frost |
| 25 | Arid / Tropical |
| 26 | Arid / Mesothermal |
| 27 | Arid / Microthermal |
| 28 | Arid / Taiga |
| 29 | Arid / Tundra |
| 30 | Arid / Frost |
---

## 3) Troll–Pfaffen (`troll_zone`)

**NetCDF variable:** `troll_zone`  
**Biome codes:** `1–37`  

| Code | Label |
|---:|---|
| 1 | Polar ice-deserts |
| 2 | Polar frost-debris belt |
| 3 | Tundra |
| 4 | Sub-polar tussock grassland and moors |
| 5 | Oceanic humid coniferous woods |
| 6 | Continental coniferous woods |
| 7 | Highly continental dry coniferous woods |
| 8 | Evergreen broad-leaved and mixed woods |
| 9 | Oceanic deciduous broad-leaved and mixed woods |
| 10 | Sub-oceanic deciduous broad-leaved and mixed woods |
| 11 | Sub-continental deciduous broad-leaved and mixed woods |
| 12 | Continental deciduous broad-leaved and mixed woods as well as wooded steppe |
| 13 | Highly continental deciduous broad-leaved and mixed woods as well as wooded steppe |
| 14 | Deciduous broad-leaved and mixed wood and wooded steppe |
| 15 | Thermophile dry wood and wooded steppe |
| 16 | Humid deciduous broad-leaved and mixed wood |
| 17 | High grass-steppe with perennial herbs |
| 18 | Humid steppe with mild winters |
| 19 | Short grass-, dwarf shrub-, or thorn-steppe |
| 20 | Steppe with short grass, dwarf shrubs and thorns |
| 21 | Central and East-Asian grass and dwarf shrub steppe |
| 22 | Semi-desert and desert with cold winters |
| 23 | Semi-desert and desert with mild winters |
| 24 | Sub-tropical hard-leaved and coniferous wood |
| 25 | Sub-tropical grass and shrub-steppe |
| 26 | Sub-tropical thorn- and succulents-steppe |
| 27 | Sub-tropical steppe with short grass |
| 28 | Sub-tropical semi-deserts and deserts |
| 29 | Sub-tropical high-grassland |
| 30 | Sub-tropical humid forests |
| 31 | Evergreen tropical rain forest |
| 32 | Rain-green humid forest |
| 33 | Half-deciduous transition wood |
| 34 | Rain-green dry wood and savannah |
| 35 | Tropical thorn-succulent wood and savannah |
| 36 | Tropical dry climates with humid months in winter |
| 37 | Tropical semi-deserts and deserts |
| 38 | Not Classified|

---

## 4) Wissmann (`climate_zone`)

**NetCDF variable:** `climate_zone`  
**Biome codes:** `1–22` 

| Code | Label |
|---:|---|
| 1 | Rainforest, equatorial |
| 2 | Rainforest, weak dry period |
| 3 | Savannah and monsoonal rainforest |
| 4 | Steppe, tropical |
| 5 | Desert, tropical |
| 6 | Warm temperate, humid, summer dry |
| 7 | Warm temperate, humid |
| 8 | Warm temperate, winter dry |
| 9 | Warm temperate, cool summer |
| 10 | Steppe, warm temperate |
| 11 | Desert, warm temperate |
| 12 | Cool temperate, humid |
| 13 | Cool temperate, winter dry |
| 14 | Cool temperate, summer dry |
| 15 | Steppe, cool temperate |
| 16 | Desert, cool temperate |
| 17 | Boreal, humid |
| 18 | Boreal, winter dry |
| 19 | Steppe, boreal |
| 20 | Desert, boreal |
| 21 | Polar tundra |
| 22 | Polar frost |
---

## 5) BIOME4 (`biome`)

**NetCDF variable:** `biome`  
**Biome codes:** `1–28`

| Code | Label |
|---:|---|
| 1 | Tropical evergreen forest |
| 2 | Tropical semi-deciduous forest |
| 3 | Tropical deciduous forest/woodland |
| 4 | Temperate deciduous forest |
| 5 | Temperate conifer forest |
| 6 | Warm mixed forest |
| 7 | Cool mixed forest |
| 8 | Cool conifer forest |
| 9 | Cold mixed forest |
| 10 | Evergreen taiga/montane forest |
| 11 | Deciduous taiga/montane forest |
| 12 | Tropical savanna |
| 13 | Tropical xerophytic shrubland |
| 14 | Temperate xerophytic shrubland |
| 15 | Temperate sclerophyll woodland |
| 16 | Temperate broadleaved savanna |
| 17 | Open conifer woodland |
| 18 | Boreal parkland |
| 19 | Tropical grassland |
| 20 | Temperate grassland |
| 21 | Desert |
| 22 | Steppe tundra |
| 23 | Shrub tundra |
| 24 | Dwarf shrub tundra |
| 25 | Prostrate shrub tundra |
| 26 | Cushion-forbs, lichen and moss |
| 27 | Barren |
| 28 | Land ice |
---

## 6) Customizable Base model (`biome`)

**NetCDF variable:** `biome`  
**Biome codes:** `0–8`

| Code | Label |
|---:|---|
| 0 | No data |
| 1 | Needleleaf Evergreen forest |
| 2 | Broadleaf Evergreen forest |
| 3 | Needleleaf Deciduous forest |
| 4 | Broadleaf Deciduous forest |
| 5 | Mixed Forest |
| 6 | C3 Grassland |
| 7 | C4 Grassland |
| 8 | Hot and Cold Desert |
---

## Quick variable summary

| Model | NetCDF variable(s) that store codes |
|---|---|
| Köppen–Geiger | `koppen_class` |
| Thornthwaite | `moisture_zone`, `temperature_zone` *(combined in plotting)* |
| Troll–Pfaffen | `troll_zone` |
| Wissmann | `climate_zone` |
| BIOME4 | `biome` |
| Base | `biome`|
