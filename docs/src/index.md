# Biome.jl
🌱 *A modular framework for climate-based biome prediction*

Welcome to the documentation of **Biome.jl** a flexible, open-source modeling framework designed to simulate and analyze biome distributions under varying environmental conditions.
We provide a modular and customizable engine to explore plant functional type (PFT) dynamics, equilibrium vegetation outcomes, and climate-driven biome classifications at global or regional scales.

The package integrates both **climatic envelope schemes**  and **mechanistic simulation approaches** inspired by the [BIOME4](https://www.researchgate.net/publication/37470169_Geophysical_Applications_of_Vegetation_Modeling) model from Kaplan and Prentice (2001).

Biome.jl extends these classical frameworks by enabling:

- Customization of [PFT](./pfts.md) definitions and physiological parameters
- User-defined competition rules and [biome classification](./biomes.md) schemes
- Integration with parameter estimation tools (e.g. [Turing.jl](https://turinglang.org/))
- High-resolution simulations and parallel processing on gridded landscapes
- Scenario-based modeling (e.g. climate change, CO₂ concentration, soil constraints)

The goal of Biome.jl is to foster **community-driven development of biome models** that are reproducible, transparent, and extensible. 

This documentation provides a comprehensive guide to:

- Setting up and configuring models
- Preparing input datasets
- Defining custom PFTs and biomes
- Running simulations across different schemes
- Calibrating parameters and evaluating results

---

Start with the [Getting Started](./getting-started.md) guide to install and run your first Biome.jl model, or jump to the [Model Configuration](./model-setup.md) section for a deeper dive into custom simulations.

## Credits

The following people are involved in the development of Biome.jl 
* [Capucine Lechartre](https://github.com/clechartre) - Main development 
* [Victor Boussange](https://github.com/vboussange) - Code architecture
* [Niklaus Zimmermann](https://www.wsl.ch/de/mitarbeitende/zimmerma/) - Theoretical development
* [Philipp Brun](https://www.wsl.ch/de/mitarbeitende/brunp/) - Theoretical development

All contributors are affiliated with the [Swiss Federal Institute for Forest, Snow, and Landscape Research WSL](https://www.wsl.ch/en/)