<p align="middle">
  <img src="figures/biomelogo_grey.svg"/>
</p>

[![Run tests](https://github.com/clechartre/BIOME5/actions/workflows/pre-commit.yml/badge.svg)](https://github.com/clechartre/BIOME5/actions/workflows/pre-commit.yml)
  <a href="https://mit-license.org">
    <img alt="MIT license" src="https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square">
  </a>

# Biome.jl: Climate-Driven Vegetation Modeling in Julia

**Biome.jl** is a Julia package for simulating climate-driven biome classification and vegetation patterns. It provides implementations of both mechanistic models (including the well-established BIOME4 model) and empirical climate envelope approaches for predicting global vegetation distributions.

If you are looking for an R package with the same functionalities, please check out our [R wrapper](https://github.com/clechartre/biomeR.git)

## What is Biome.jl?

This package offers:
- **BIOME4 Model**: A Julia translation of the original FORTRAN77 equilibrium vegetation model by Kaplan et al. (2003)
- **Custom Biome Schemes**: Framework for creating your own climate-vegetation classification systems
- **Plant Functional Types (PFTs)**: Flexible system for defining and parameterizing vegetation types
- **Climate Envelope Models**: Simpler approaches based on temperature and precipitation thresholds

The models predict vegetation types and biome distributions based on climate variables, making them useful for studying climate-vegetation relationships, climate change impacts, and paleoclimate reconstructions.

## Model Output Example

Below is an example global biome map generated using the BIOME4 model logic:

<p align="middle">
  <img src="figures/output_b4.svg"/>
</p>

# Installation Instructions

To run Biome.jl using Julia, you need to set up the required environment by installing the necessary dependencies. The environment is defined in the `Project.toml` and `Manifest.toml` files, which ensure reproducibility.

1. **Install Julia**:  
   First, ensure that Julia is installed on your system. You can download the latest version from the official Julia website: [https://julialang.org/downloads/](https://julialang.org/downloads/).

2. **Clone the Repository**:  
   Clone this repository to your local machine:
   ```bash
   git clone https://github.com/clechartre/Biome.jl.git
   cd Biome.jl
   ```

3. ***Activate the Project**:
    Inside the repository, activate the project environment using Julia’s built-in package manager. Open a Julia REPL by typing julia in your terminal, then run: 
    ```
      using Pkg
      Pkg.activate(".")
      Pkg.instantiate()
    ```

## Model Types

### 1. Climate Envelope Models
Simpler models requiring only basic climate data:
- **Temperature**: Monthly mean temperature (°C) 
- **Precipitation**: Monthly total precipitation (mm)

### 2. Mechanistic Models
More complex models that simulate plant physiology and require:
- **Temperature**: Monthly mean temperature (°C) -- Climatology
- **Precipitation**: Monthly total precipitation (mm) -- Climatology
- **Cloud cover**: Monthly mean cloud cover (%) -- Climatology
- **Soil properties**: Water holding capacity (mm/mm) and hydraulic conductivity (mm/h) -- For multiple soil depths
- **CO₂ concentration**: Atmospheric CO₂ (ppm) -- Single value

## Input Data Format
All spatial data should be provided as rasters to the `ModelSetup` class intentiation with:
- Monthly time dimension (12 months)
- Spatial dimensions (longitude/latitude)
- Consistent spatial resolution and projection

## Data Sources

### Climate Data
- **Recommended**: [CHELSA database](https://www.chelsa-climate.org//) for high-resolution climate data
- **Alternative**: ERA5, WorldClim, or other gridded climate datasets

### Soil Data  
- Use the [makesoil](https://github.com/ARVE-Research/makesoil) tool to generate soil hydraulic properties
- Generates water holding capacity (whc) and hydraulic conductivity (Ksat) from soil texture data


## Examples

### Climate Envelope Model Example
For a simple climate-based classification:

```julia
using Biome, Rasters

# Load climate data
temp = Raster("temperature_1981-2010.nc", name="temp")
prec = Raster("precipitation_1981-2010.nc", name="prec")


# Run model
setup = ModelSetup(KoppenModel(); temp=temp, prec=prec)
run!(setup; outfile="climate_biomes.nc")
```

### BIOME4 Mechanistic Model Example
For the full physiological model:

```julia
using Biome, Rasters

# Load all required data
temp = Raster("temperature.nc", name="temp")
prec = Raster("precipitation.nc", name="prec") 
clt = Raster("cloudcover.nc", name="sun")
ksat = Raster("soils.nc", name="Ksat")
whc = Raster("soils.nc", name="whc")

# Use default BIOME4 PFT classification
pfts = BIOME4.PFTClassification()

# Run mechanistic model
setup = ModelSetup(BIOME4Model(); 
    temp=temp,
    prec=prec,
    clt=clt,
    ksat=ksat,
    whc=whc, 
    co2=373.8,
    PFTList=pfts)
run!(setup; coordstring = "alldata", outfile="biome4_output.nc")
```


### Coordinate Specification
- `"alldata"`: Process entire input domain
- `"lon1/lon2/lat1/lat2"`: Specify bounding box (e.g., "-10/30/35/70" for Europe)
- Single coordinates: `"lon/lat"` for point locations

## Customization

### Custom Plant Functional Types
You can define your own PFTs with specific climate tolerances:

```julia
# Create custom PFT with specific temperature/precipitation limits
custom_pft = BroadleafEvergreenPFT(
    name = "Mediterranean", 
    phenological_type = 1,
    constraints = (
      gdd5=[1000, Inf],     # Growing degree days > 5°C
      tcm=[5, 20]        # Coldest month temperature range
    )
)
pftlist = PFTClassification([custom_pft, ...])
```

### Model Parameters
Modify BIOME4 PFT parameters:

```julia
pfts = BIOME4.PFTClassification()
set_characteristic!(pfts, "BorealEvergreen", :gdd5, [600.0, Inf])
set_characteristic!(pfts, "BorealDeciduous", :tcm, [-40.0, 18.0])
```

## Troubleshooting

- **Memory issues**: Use coordinate strings to process smaller regions
- **Missing data**: Ensure all input files have consistent spatial grids
- **Slow performance**: Consider using fewer PFTs, lower resolution data, or parallelize your work

## More Information

- See `examples/` directory for complete working examples
- Check `test/` directory for model validation examples
- Documentation: [Link to docs when available]

## Background

This project translates the original FORTRAN77 BIOME4 model (Kaplan et al. 2003) to modern Julia, making it more accessible and extensible. The original BIOME4 v4.2b2 computational core has been preserved while adding new functionality for custom biome definitions.

## Credits

- **Original BIOME4 model**: Jed Kaplan ([Kaplan & Prentice, 2001](https://www.researchgate.net/publication/37470169_Geophysical_Applications_of_Vegetation_Modeling))
- **Julia translation & package development**: Capucine Lechartre (capucine.lechartre@wsl.ch)
- **Original FORTRAN code**: Available at [github.com/jedokaplan/BIOME4](https://github.com/jedokaplan/BIOME4)

## References

Kaplan, J.O., Bigelow, N.H., Prentice, I.C., Harrison, S.P., Bartlein, P.J., Christensen, T.R., Cramer, W., Matveyeva, N.V., McGuire, A.D., Murray, D.F. and Razzhivin, V.Y., 2003. Climate change and Arctic ecosystems: 2. Modeling, paleodata‐model comparisons, and future projections. *Journal of Geophysical Research*, 108(D19).
