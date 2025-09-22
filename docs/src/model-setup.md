# Model Setup — BiomeDriver

This guide shows how to configure and run **BiomeDriver.ModelSetup** for different model types (Base/BIOME4, Dominance, and climate classification models), what inputs are required, and what outputs to expect.

> Works with: `Biome` (models + PFTs) and `Rasters` (IO & grids)

---

## 1) Quick start

```julia
using Biome
using Rasters
using BiomeDriver

# Load rasters
temp_r = Raster("/path/to/temp.nc", name="temp")
prec_r = Raster("/path/to/prec.nc", name="prec")

# Minimal example (Köppen model)
setup = ModelSetup(KoppenModel; temp=temp_r, prec=prec_r)
run!(setup; coordstring="alldata", outfile="output_Koppen.nc")
```

---

## 2) What `ModelSetup` does

`ModelSetup` holds everything needed to run a model on a grid:

* `model::BiomeModel` — which model you want to run (e.g., `BaseModel()`, `BIOMEDominanceModel()`, `KoppenModel()`)
* `lon, lat` — coordinates auto-extracted from your **temp** raster
* `co2::Real` — atmospheric CO₂ (defaults to 378.0)
* `rasters::NamedTuple` — your environmental inputs (any keyword set to a `Raster`)
* `pftlist` — a `PFTClassification` or `BIOME4.PFTClassification` (optional; default depends on model)
* `biome_assignment::Function` — override biome mapping (optional)
* `int_type`, `float_type` — numeric types (optional)

The driver slices the domain (using `coordstring`), processes in chunks, resumes from an existing NetCDF if found, and writes outputs per model schema.

---

## 3) Required inputs by model

All rasters must share **the same grid, ordering, and resolution**. Missing values are unified to `-9999.0` internally.

### A) Base / BIOME4 family

`BaseModel`, `BIOME4Model`, `BIOMEDominanceModel`

**Required:**

* `temp` (`Raster`) — temperature climatology (time or monthly band last dim)
* `prec` (`Raster`) — precipitation climatology

**Common optional (model- or PFT-dependent):**

* `clt` or `sun` (cloudiness or sunshine)
* `ksat` (saturated hydraulic conductivity)
* `whc` (water holding capacity)
* other custom covariates (e.g., `tmin`, `gdd0`, `maxdepth`, …)


**Units**: ensure inputs make biophysical sense for your PFT rules. You can transform units prior to setup, e.g.:

```julia
# Example: scale precipitation ×10, invert sunshine to cloudiness
prec_r .= ifelse.(coalesce.(prec_r, -9999) .!= -9999, 10 .* coalesce.(prec_r, -9999), -9999)
cloud_r = copy(sun_r)
cloud_r .= ifelse.(coalesce.(sun_r, -9999) .!= -9999, 100 .- coalesce!(sun_r, -9999), -9999)
```


**CO₂:** `co2` keyword (e.g., `373.8`).

**PFT list:**

* If omitted:

  * Will default to `BIOME4.PFTClassification()` 

* Can pass a custom `PFTClassification([...])` initialized with [PFTs](./pfts.md)

**Outputs created:**

* `biome` (`Int16`, dims: `lon,lat`)
* `optpft` (`Int16`, dims: `lon,lat`)
* `npp` (`Float64`, dims: `lon,lat,pft`) — size `num_pfts + 1`

### B) Climate classification models

`WissmannModel`, `KoppenModel`, `ThornthwaiteModel`, `TrollPfaffenModel`

**Required:**

* `temp` (`Raster`)
* `prec` (`Raster`)

**Outputs:**

* `WissmannModel` → `climate_zone` (`lon,lat`)
* `KoppenModel` → `koppen_class` (`lon,lat`)
* `ThornthwaiteModel` → `temperature_zone`, `moisture_zone` (`lon,lat`)
* `TrollPfaffenModel` → `troll_zone` (`lon,lat`)

**Primary output variables:** as above (used for resume logic).

---

## 4) Input raster expectations

* Require climatologies for environmental inputs. The inputs should be of dimensions `[X, Y, 12]`.
* Dimensions are taken from the **`temp`** raster to build `lon` and `lat`; all rasters must align exactly.
* Use `name="varname"` when loading to set the key (e.g., `name="temp"`).

* Missing values: Anything `missing` is converted to `-9999.0`.

---

## 5) Selecting the domain (`coordstring`)

* Use `"alldata"` to process the full grid (default).
* Or pass `"lon_min/lon_max/lat_min/lat_max"` (e.g., `"-180/0/-90/90"`).
* The driver maps those to array indices even if latitude is descending.

```julia
run!(setup; coordstring="-180/0/-90/90", outfile="subset.nc")
```

---

## 6) Examples by model

### A) Base model with custom PFT constraints and biome assignment

```julia
using Biome, Rasters

# Load
temp_r = Raster(".../temp_1981-2010.nc", name="temp")
prec_r = Raster(".../prec_1981-2010.nc", name="prec")
clt_r  = Raster(".../sun_1981-2010.nc",  name="sun")
ksat_r = Raster(".../soils_55km.nc",      name="Ksat")
whc_r  = Raster(".../soils_55km.nc",      name="whc")

# Optional extra covariate
test_r = Raster(".../temp_1981-2010.nc", name="temp")[:, :, 1]  # single-band example

# Define PFT list and constraints
pfts = PFTClassification([
    NeedleleafEvergreenPFT(), BroadleafEvergreenPFT(),
    NeedleleafDeciduousPFT(), BroadleafDeciduousPFT(),
    C3GrassPFT(), C4GrassPFT()
])
add_constraint!(pfts.pft_list[1], :test, (-5.0, 10.0))
add_constraint!(pfts.pft_list[2], :test, (0.0, 5.0))
# ...

# (Optional) custom biome mapping
function my_biome_assign(pft::AbstractPFT; subpft, wdom, gdd0, gdd5, tcm, tmin, pftlist, pftstates, gdom)
    # Example overrides then fallback
    if get_characteristic(pft, :c4)
        return Savanna()  # your custom biome type
    else
        return Biome.assign_biome(pft; subpft, wdom, gdd0, gdd5, tcm, tmin, pftlist, pftstates, gdom)
    end
end

setup = ModelSetup(BaseModel();
    temp=temp_r, prec=prec_r, clt=clt_r, ksat=ksat_r, whc=whc_r,
    test=test_r, co2=373.8, pftlist=pfts, biome_assignment=my_biome_assign)

run!(setup; coordstring="-180/0/-90/90", outfile="output_BaseModel.nc")
```

### B) BIOMEDominanceModel on a regional grid (unit transforms shown)

```julia
using Biome, Rasters

# Load region rasters
temp_r = Raster(".../temp_1981-2010_europe.nc", name="temp")
prec_r = Raster(".../prec_1981-2010_europe.nc", name="prec")
sun_r  = Raster(".../sun_1981-2010_europe.nc",  name="sun")
ksat_r = Raster(".../soils_55km_europe.nc",     name="Ksat")
whc_r  = Raster(".../soils_55km_europe.nc",     name="whc")

# Transform examples
prec_r .= ifelse.(coalesce.(prec_r, -9999) .!= -9999, 10 .* coalesce.(prec_r, -9999), -9999)
cloud_r = copy(sun_r)
cloud_r .= ifelse.(coalesce.(sun_r, -9999) .!= -9999, 100 .- coalesce.(sun_r,
```
