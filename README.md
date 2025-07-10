[![Run tests](https://github.com/clechartre/BIOME5/actions/workflows/pre-commit.yml/badge.svg)](https://github.com/clechartre/BIOME5/actions/workflows/pre-commit.yml)

# BIOME.jl: A Package for simulating biome schemes

This package provides a platform for simulating climate-driven biome classification schemes alongside the mechanistic model BIOME4. 

The BIOME4 equilibrium global vegetation model was first used in experiments described in Kaplan et al. (2003). The computational core of the model was last updated in 1999, and at the time was called [BIOME4 v4.2b2 ](https://github.com/jedokaplan/BIOME4). For more information about the original model, please refer to: [Kaplan, Jed & Prentice, Iain. (2001). Geophysical Applications of Vegetation Modeling.](https://www.researchgate.net/publication/37470169_Geophysical_Applications_of_Vegetation_Modeling)

This GitHub repository contains the translation to Julia of the original FORTRAN77 computational core to run on sample input data, also provided in this repository.

The original code works with a main routine and subroutines. You can see the infrastructure in the following graph. In this Julia version, we kept the overall structure where higher level modules call functions from sub-modules.

<p align="middle">
  <img src="figures/infrastructure_biome4jl.jpg"/>
</p>


## Requirements in Input data:

The PFTs and their characteristics are supplied to the model through a JSON file. Default PFT value for BIOME4 can be found on `input\pft.json`

BIOME4 requires the following variables to run (in the form of gridded fields):

- climatological monthly mean fields of temperature (°C)
- climatological monthly mean cloud cover (%)
- climatological mean monthly total precipitation (mm)
- soil water holding capacity in two or more layers (mm/mm)
- soil saturated conductivity in two or more layers (mm/h)

BIOME4 also requires a single global value for atmospheric CO₂ concentrations
The following input variables are optional:

climatological absolute minimum temperature (°C) (will be estimated using a regression function based on mean temperature if not present)
grid cell elevation above sea level (m) (will be set to sea level if not present)
The gridded input data can be at any resolution, but this version of the driver expects the input fields to be in unprojected (lon-lat) rasters (this is probably not an issue anyways since everything is processed pixel by pixel)

### The input generation scripts
Since we want to be able to generate our own input data, we've created 3 input generation scripts, available in `utils/data_generation`. 
- Climatological data 


At this stage, we are running the model on a 0.5 grid, all data was therefore reshaped to 720,360 within the data generation codes themselves. On the longer run, we hope to be able the model on 1km resolution grids, and therefore will make this feature less constrained (remove hardcoding on input size)

     
See the previous sections for description of the datasets and where to retrieve them.

#### 1. Climatological data 
The Climatological data, temperature, tmin, cloud cover, and precipitation is downloaded from the [CHELSA database](https://chelsa-climate.org/bioclim/). Each variable is downloaded for a specified year, for each month of the year. 
Aside for yearly data, the CHELSA database also provides averaged datasets over longer time periods. 

#### 2. Soil characteristics data
The data on soil characteristics are generated using the [makesoil](https://github.com/ARVE-Research/makesoil) module from Arve research. This script will automatically generate a NetCDF file with the two variables that are necessary to run BIOME4: the soil water holding capacity (whc), and the soil saturated conductivity (Ksat).

## How to use the model
This package includes a Julia script that can be executed to run the BIOME4 model using specific environmental data files. The script requires several input files (e.g., temperature, precipitation, etc.), a CO2 concentration, and the coordinates of the region where the model will run.

#### Command Example
You can run the model using the following SLURM command:

```
julia --project=. src/driver.jl --coordstring "alldata"\
  --co2 373.847 \
  --tempfile  "path/to/tempfile.nc" \
  --precfile "path/to/precfile.nc"\
  --sunfile "path/to/sunfile.nc"\
  --soilfile "path/to/soilfile.nc""\
  --year "NAME"\
  --model "biome4"

```


## Preparation

This project has been created from the
[MeteoSwiss Python blueprint](https://github.com/MeteoSwiss-APN/mch-python-blueprint)
for the CSCS.

### Installing the Julia Environment

To run the BIOME4 model using Julia, you need to set up the required environment by installing the necessary dependencies. The environment is defined in the `Project.toml` and `Manifest.toml` files, which ensure reproducibility.

### Step-by-step Installation

1. **Install Julia**:  
   First, ensure that Julia is installed on your system. You can download the latest version from the official Julia website: [https://julialang.org/downloads/](https://julialang.org/downloads/).

2. **Clone the Repository**:  
   Clone this repository to your local machine:
   ```bash
   git clone https://github.com/yourusername/BIOME4jl.git
   cd BIOME4jl
   ```

3. ***Activate the Project**:
    Inside the repository, activate the project environment using Julia’s built-in package manager. Open a Julia REPL by typing julia in your terminal, then run: 
    ```
      using Pkg
      Pkg.activate(".")
      Pkg.instantiate()
    ```

## Credits

All calculations and logic was developped by Jed Kaplan in the original BIOME4 version.

All translations to Julia and the repository architecture were designed by Capucine Lechartre. For any question related to the code, please contact me at capucine.lechartre@wsl.ch

This package was created with [`copier`](https://github.com/copier-org/copier) and the [`MeteoSwiss-APN/mch-python-blueprint`](https://meteoswiss-apn.github.io/mch-python-blueprint/) project template.
