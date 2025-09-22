# Köppen-Geiger

The Köppen–Geiger system divides Earth’s climates into five primary groups: A (tropical), B (arid), C (temperate), D (continental) and E (polar). Each group is then further subdivided by patterns of seasonal precipitation and temperature thresholds. This biome classification relies on metrics such as the coldest and warmest monthly mean temperatures, total and driest-month precipitation, and the relative timing of wet and dry seasons, and outputs subtypes like Af (tropical rainforest), Cfb (oceanic) or BWh (hot desert), each mapped to a unique integer code.

Köppen emphasized using monthly means and seasonal contrasts rather than only annual values, because vegetation and human environments respond to the timing of warmth and moisture as much as their totals. 


<figure> <img src="assets/output_koppengeiger_example.svg" alt="Example Köppen–Geiger map produced by the model (subtypes such as Af, Cfb, BWh; colors correspond to integer codes)" width="100%"> <figcaption><strong>Figure.</strong> Example Köppen–Geiger classification map.</figcaption> </figure>

These are the classes: 


| Code | Class |
|---:|---|
| 1 | Equatorial fully humid (**Af**) |
| 2 | Equatorial monsoonal (**Am**) |
| 3 | Equatorial summer dry (**As**) |
| 4 | Equatorial winter dry (**Aw**) |
| 5 | Cold desert (**BWk**) |
| 6 | Hot desert (**BWh**) |
| 7 | Cold steppe (**BSk**) |
| 8 | Hot steppe (**BSh**) |
| 9 | Warm temperate fully humid hot summer (**Cfa**) |
| 10 | Warm temperate fully humid warm summer (**Cfb**) |
| 11 | Warm temperate fully humid cool summer (**Cfc**) |
| 12 | Warm temperate summer dry hot summer (**Csa**) |
| 13 | Warm temperate summer dry warm summer (**Csb**) |
| 14 | Warm temperate summer dry cool summer (**Csc**) |
| 15 | Warm temperate, winter dry, hot summer (**Cwa**) |
| 16 | Warm temperate, winter dry, warm summer (**Cwb**) |
| 17 | Warm temperate, winter dry, cool summer (**Cwc**) |
| 18 | Snow fully humid hot summer (**Dfa**) |
| 19 | Snow fully humid warm summer (**Dfb**) |
| 20 | Snow fully humid cool summer (**Dfc**) |
| 21 | Snow fully humid extremely continental (**Dfd**) |
| 22 | Snow summer dry hot summer (**Dsa**) |
| 23 | Snow summer dry warm summer (**Dsb**) |
| 24 | Snow summer dry cool summer (**Dsc**) |
| 25 | Snow summer dry extremely continental (**Dsd**) |
| 26 | Snow winter dry hot summer (**Dwa**) |
| 27 | Snow winter dry warm summer (**Dwb**) |
| 28 | Snow winter dry cool summer (**Dwc**) |
| 29 | Snow winter dry extremely continental (**Dwd**) |
| 30 | Polar tundra (**ET**) |
| 31 | Polar frost (**EF**) |


In the provided Julia implementation, the run function unpacks longitude, latitude, monthly temperature and precipitation from the input vector, computes summary statistics (min, max, mean), sums seasonal precipitation (winter vs. summer based on hemisphere), then applies the Köppen–Geiger decision tree against those thresholds and looks up the resulting symbol in a Dict{Symbol,Int} to produce a numeric climate class, finally returning that class along with the original coordinates.

You can call this model using 

`````julia
using Biome
using Rasters

# Minimal inputs
tempfile = "/path/to/temp.nc"   # monthly mean temperature (stacked in 3rd dim)
precfile = "/path/to/prec.nc"   # monthly precipitation (same grid/stacking)

temp_raster = Raster(tempfile, name="temp")
prec_raster = Raster(precfile,  name="prec")

setup = ModelSetup(KoppenModel();
                   temp=temp_raster,
                   prec=prec_raster)

# Process full grid (or pass "lonmin/lonmax/latmin/latmax")
run!(setup; coordstring="alldata", outfile="output_Koppen.nc")

`````

## Tips for tidy outputs

* Ensure `temp` and `prec` share identical grid, resolution, and ordering (lat can be asc/desc; the driver handles both).

    * Units: temperature in °C; precipitation in mm per month (match what your decision tree expects).

* The NetCDF will contain `koppen_class` on (lon, lat). You can find the mapping of the integer codes to Köppen symbols in the plotting script `utils/plotting/plotting_kg.jl`.

## References

* Köppen, W. Das geographische System der Klimate, 1–44 (Gebrüder Borntraeger: Berlin, Germany, 1936).

* Beck, H., Zimmermann, N., McVicar, T. et al. Present and future Köppen-Geiger climate classification maps at 1-km resolution. Sci Data 5, 180214 (2018). https://doi.org/10.1038/sdata.2018.214

