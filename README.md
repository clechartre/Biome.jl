# BIOME4jl: Julia version of the BIOME4 model from [Jed Kaplan, 1999](https://github.com/jedokaplan/BIOME4)

This is the BIOME4 equilibrium global vegetation model, that was first used in experiments described in Kaplan et al. (2003). The computational core of the model was last updated in 1999, and at the time was called BIOME4 v4.2b2. For more information about the original model, please refer to: [Kaplan, Jed & Prentice, Iain. (2001). Geophysical Applications of Vegetation Modeling.](https://www.researchgate.net/publication/37470169_Geophysical_Applications_of_Vegetation_Modeling)

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
- Water holding capacity (soil) data
- Saturated conductivity data 

At this stage, we are running the model on a 0.5 grid, all data was therefore reshaped to 720,360 within the data generation codes themselves. On the longer run, we hope to be able the model on 1km resolution grids, and therefore will make this feature less constrained (remove hardcoding on input size)

The input data generation relies on a `data/downloaded_data` folder containing baseline data. Its contents are:
- Sand content at 0-5cm
- Clay content at 0-5cm
- Ksat at 0 and 30cm 
- Soil water content at 10kPa at 0-5cm
- Soil water content at 10kPa at 15-30cm
- Soil water content at 33kPa at 0-5cm
- Soil water content at 33kPa at 15-30cm
- Soil water content at 15000kPa at 0-5cm
- Soil water content at 15000kPa at 15-30cm
- Countries shapefile folder
     
See the previous sections for description of the datasets and where to retrieve them.

#### 1. Climatological data 
The Climatological data, temperature, tmin, cloud cover, and precipitation is downloaded from the [CHELSA database](https://chelsa-climate.org/bioclim/). Each variable is downloaded for a specified year, for each month of the year. 
Aside for yearly data, the CHELSA database also provides averaged datasets over longer time periods. 

#### 2. Water Holding Capacity 
No dataset is available for global water holding capacity (to not be confused with the AWC, available water capacity of the soil). We therefore generate a new dataset from available maps at field capacity (10 or 33 kPa) and wilting point (1500 kPa). 
We are determining field capacity from the sand and clay proportions of the soil and make the assumption that the soil is either of the types. If a soil is mostly sandy, its field capacity will be attributed 10kPa, else 33kPa. Based on this intermediate classification, we extract the moisture content of the soil. 
Sand and clay contents were extracted from [SoilGrids](https://files.isric.org/soilgrids/latest/data_aggregated/1000m/). We assumed that soil type would be the same at all depths and therefore only calculated soil type based on 0cm depth. Future model improvement could consider calculating values individually for all soil layers.

If you subtract the moisture content at wilting point from that at field capacity, and then multiply by the depth you're interested in, you will get the volume—this means plant-available soil water or water holding capacity.
We are using maps of available capactiy extracted from for depths 0-5cm and 15 to 30cm:       
- WV 100 cm: https://doi.org/10.17027/isric-soilgrids.c6cb5073-78dd-4d8d-be81-9d546a1c004f
- WV 330 cm: https://doi.org/10.17027/isric-soilgrids.14e7c761-6f87-4f4c-9035-adb282439a44
- WV 15,000 cm: https://doi.org/10.17027/isric-soilgrids.f5a1188a-09f8-4ef6-b841-93f08e3903f4

#### 3. Ksat 
The ksat dataset was generated by the CoGTF framework  from Gupta, S., Lehmann, P., Bonetti, S., Papritz, A., and Or, D., (2020):
Global prediction of soil saturated hydraulic conductivity using random forest in a Covariate-based Geo Transfer Functions (CoGTF) framework.
Journal of Advances in Modeling Earth Systems, 13(4), e2020MS002242. https://agupubs.onlinelibrary.wiley.com/doi/full/10.1029/2020MS002242"""
One can download dataset source [here](https://zenodo.org/records/3935359). We extracted values for depth 0 and 30cm.

We are masking the WHC and Ksat datasets with landmass data downloaded from [Natural Earth](https://www.naturalearthdata.com/downloads/110m-cultural-vectors/110m-admin-0-countries/) to make sure we only have soil values in continents. 

## How to use the model
This package includes a Julia script that can be executed to run the BIOME4 model using specific environmental data files. The script requires several input files (e.g., temperature, precipitation, etc.), a CO2 concentration, and the coordinates of the region where the model will run.

#### Command Example
You can run the model using the following SLURM command:

```
srun julia -O3 --project=. -e 'include("/path/to/src/BIOME4Ju/biome4driver.jl"); using .Biome4Driver; Biome4Driver.main(
    "-84/-56/-32/15",  # Coordinates as a string in the format: "longitude_min/longitude_max/latitude_min/latitude_max". Use 'alldata' for global.
    324.0,             # CO2 concentration (parts per million)
    false,             # Set diagnostic mode (true/false)
    "/path/to/temp_data.nc",  # Path to the temperature data file (NetCDF format)
    "/path/to/tmin_data.nc",  # Path to the minimum temperature data file (NetCDF format)
    "/path/to/prec_data.nc",  # Path to the precipitation data file (NetCDF format)
    "/path/to/sun_data.nc",   # Path to the sunshine/cloud cover data file (NetCDF format)
    "/path/to/soil.nc",       # Path to the water holding capacity (WHC) and saturate conductivity (Ksat) data file (NetCDF format)
    "path/to/pft.json",       # Path to the PFT characteristic file
    "year",                   # Year of data source as a string, will determine the output file name
    "high"                    # Resolution setting: choose from "high" or "low"
)'
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
