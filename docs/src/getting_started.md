# Getting Started

This user guide describes the basic structures and functions to run the base models provided in the package, and define your biome schemes and run them.

## Requirements in Input data:

## Climatological and soil input

#### 1. Climatological data 
The Climatological data, temperature, tmin, cloud cover, and precipitation is downloaded from the [CHELSA database](https://chelsa-climate.org/bioclim/). Each variable is downloaded for a specified year, for each month of the year. 
Aside for yearly data, the CHELSA database also provides averaged datasets over longer time periods. 

#### 2. Soil characteristics data
The data on soil characteristics are generated using the [makesoil](https://github.com/ARVE-Research/makesoil) module from Arve research. This script will automatically generate a NetCDF file with the two variables that are necessary to run BIOME4: the soil water holding capacity (whc), and the soil saturated conductivity (Ksat).

## Climate Envelope Models

The Thornthwaite, TrollPfaffen, and Wissmann models will work with 
* Temperature climatologies
* Precipiation climatologies

The Köppen-Geiger model will additionally require latitudinal and longitudinal information. 

## Mechanistic Models
The BIOME4 model and other PFT-based frameworks require the following variables to run (in the form of gridded fields):

* climatological monthly mean fields of temperature (°C)
* climatological monthly mean cloud cover (%)
* climatological mean monthly total precipitation (mm)
* soil water holding capacity in two or more layers (mm/mm)
* soil saturated conductivity in two or more layers (mm/h)

BIOME4 also requires a single global value for atmospheric CO₂ concentrations


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

