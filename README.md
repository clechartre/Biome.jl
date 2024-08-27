# BIOME4Py: Python version of the BIOME4 model from [Jed Kaplan, 1999](https://github.com/jedokaplan/BIOME4)

This is the BIOME4 equilibrium global vegetation model, that was first used in experiments described in Kaplan et al. (2003). The computational core of the model was last updated in 1999, and at the time was called BIOME4 v4.2b2. For more information about the original model, please refer to: [Kaplan, Jed & Prentice, Iain. (2001). Geophysical Applications of Vegetation Modeling.](https://www.researchgate.net/publication/37470169_Geophysical_Applications_of_Vegetation_Modeling)

This GitHub repository contains the translation to python of the original FORTRAN77 computational core to run on sample input data, also provided in this repository.

The original code works with a main routine and subroutines. You can see the infrastructure in the following graph. In this Python version, we kept the overall structure where higher level modules call functions from sub-modules.

<p align="middle">
  <img src="figures/BIOME4_architecture.png"/>
</p>


## Requirements in Input data:

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
This package comes together with a command line entrypoint `src/cli.py` to specifiy input files, the coordinates onto which to run the model and the ouputfile. You can run it as this:

```bash
  python /src/cli.py \
  --coordstring alldata \
  --co2 324 \
  --tempfile /path/to/temp_data.nc \
  --tminfile /path/to/tmin_data.nc \
  --precfile /path/to/prec_data.nc \
  --sunfile /path/to/sun_data.nc \
  --ksatfile /path/to/ksat_data.nc \
  --whcfile /path/to/whc_data.nc
```


## Preparation

This project has been created from the
[MeteoSwiss Python blueprint](https://github.com/MeteoSwiss-APN/mch-python-blueprint)
for the CSCS.
The recommended way to manage Python versions is with `Conda`
(https://docs.conda.io/en/latest/).
On CSCS machines it is recommended to install the leaner `Miniconda`
(https://docs.conda.io/en/latest/miniconda.html),
which offers enough functionality for most of our use cases.
If you don't want to do this step manually, you may use the script
`tools/setup_miniconda.sh`.
The default installation path of this script is the current working directory,
you might want to change that with the `-p` option to a common location for all
environments, like e.g. `$SCRATCH`. If you want the script to immediately
initialize conda (executing `conda init` and thereby adding a few commands at the
end of your `.bashrc`) after installation, add the `-u` option:

```bash
tmpl/tools/setup_miniconda.sh -p $SCRATCH -u
```

In case you ever need to uninstall miniconda, do the following:

```bash
conda init --reverse --all
rm -rf $SCRATCH/miniconda
```

## Start developing

Once you created or cloned this repository, make sure the installation is running properly. Install the package dependencies with the provided script `setup_env.sh`.
Check available options with
```bash
tools/setup_env.sh -h
```
We distinguish pinned installations based on exported (reproducible) environments and free installations where the installation
is based on top-level dependencies listed in `requirements/requirements.yml`. If you start developing, you might want to do an unpinned installation and export the environment:

```bash
tools/setup_env.sh -u -e -n <package_env_name>
```
*Hint*: If you are the package administrator, it is a good idea to understand what this script does, you can do everything manually with `conda` instructions.

*Hint*: Use the flag `-m` to speed up the installation using mamba. Of course you will have to install mamba first (we recommend to install mamba into your base
environment `conda install -c conda-forge mamba`. If you install mamba in another (maybe dedicated) environment, environments installed with mamba will be located
in `<miniconda_root_dir>/envs/mamba/envs`, which is not very practical.

The package itself is installed with `pip`. For development, install in editable mode:

```bash
conda activate <package_env_name>
pip install --editable .
```

*Warning:* Make sure you use the right pip, i.e. the one from the installed conda environment (`which pip` should point to something like `path/to/miniconda/envs/<package_env_name>/bin/pip`).

Once your package is installed, run the tests by typing:

```
conda activate <package_env_name>
pytest
```

If the tests pass, you are good to go. If not, contact the package administrator Capucine Lechartre. Make sure to update your requirement files and export your environments after installation
every time you add new imports while developing. Check the next section to find some guidance on the development process if you are new to Python and/or APN.

### Roadmap to your first contribution

Generally, the source code of your library is located in `src/<library_name>`. The blueprint will generate some example code in `mutable_number.py`, `utils.py` and `cli.py`. `cli.py` thereby serves as an entry
point for functionalities you want to execute from the command line, it is based on the Click library. If you do not need interactions with the command line, you should remove `cli.py`. Moreover, of course there exist other options for command line interfaces,
a good overview may be found here (https://realpython.com/comparing-python-command-line-parsing-libraries-argparse-docopt-click/), we recommend however to use click. The provided example
code should provide some guidance on how the individual source code files interact within the library. In addition to the example code in `src/<library_name>`, there are examples for
unit tests in `tests/<library_name>/`, which can be triggered with `pytest` from the command line. Once you implemented a feature (and of course you also
implemented a meaningful test ;-)), you are likely willing to commit it. First, go to the root directory of your package and run pytest.

```bash
conda activate <package_env_name>
cd <package-root-dir>
pytest
```

If you use the tools provided by the blueprint as is, pre-commit will not be triggered locally but only if you push to the main branch
(or push to a PR to the main branch). If you consider it useful, you can set up pre-commit to run locally before every commit by initializing it once. In the root directory of
your package, type:

```bash
pre-commit install
```

If you run `pre-commit` without installing it before (line above), it will fail and the only way to recover it, is to do a forced reinstallation (`conda install --force-reinstall pre-commit`).
You can also just run pre-commit selectively, whenever you want by typing (`pre-commit run --all-files`). Note that mypy and pylint take a bit of time, so it is really
up to you, if you want to use pre-commit locally or not. In any case, after running pytest, you can commit and the linters will run at the latest on the GitHub actions server,
when you push your changes to the main branch. Note that pytest is currently not invoked by pre-commit, so it will not run automatically. Automated testing can be set up with
GitHub Actions or be implemented in a Jenkins pipeline (template for a plan available in `jenkins/`. See the next section for more details.

## Development tools

As this package was created with the APN Python blueprint, it comes with a stack of development tools, which are described in more detail on
(https://meteoswiss-apn.github.io/mch-python-blueprint/). Here, we give a brief overview on what is implemented.

### Testing and coding standards

Testing your code and compliance with the most important Python standards is a requirement for Python software written in APN. To make the life of package
administrators easier, the most important checks are run automatically on GitHub actions. If your code goes into production, it must additionally be tested on CSCS
machines, which is only possible with a Jenkins pipeline (GitHub actions is running on a GitHub server).

### Pre-commit on GitHub actions

`.github/workflows/pre-commit.yml` contains a hook that will trigger the creation of your environment (unpinned) on the GitHub actions server and
then run various formatters and linters through pre-commit. This hook is only triggered upon pushes to the main branch (in general: don't do that)
and in pull requests to the main branch.

## Credits

All calculations and logic was developped by Jed Kaplan in the original BIOME4 version.

All translations to Python and the repository architecture were designed by Capucine Lechartre. For any question related to the code, please contact me at capucine.lechartre@wsl.ch

This package was created with [`copier`](https://github.com/copier-org/copier) and the [`MeteoSwiss-APN/mch-python-blueprint`](https://meteoswiss-apn.github.io/mch-python-blueprint/) project template.
