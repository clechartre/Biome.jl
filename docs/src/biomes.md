# Defining New Biomes

## The biome concept

Biomes are large-scale ecosystems that occupy subcontinental to continental areas (or occur as complexes of smaller patches) and integrate characteristic plant and animal communities. They are shaped by macroclimate, soils, water availability, and disturbance regimes, and are generally recognizable by their vegetation physiognomy (dominant life forms and structure).

The biome concept has deep roots in both ecology and biogeography. Its foundations include:

- **Precursors:** early ideas such as *formation* (Grisebach, 1838), *life zones* (Merriam, 1894), and Schimper’s climatic template (1898).
- **Climatic and edaphic zonality:** macroclimate and soils as primary drivers of global vegetation patterns (Schimper, Dokuchaev, Walter).
- **Physiognomy:** vegetation form and structure as a unifying comparative tool across regions.
- **Functional and evolutionary perspectives:** biomes as dynamic entities assembled by ecological processes and evolutionary history, acting as “theatres of evolution” where species and traits are filtered and reshaped.

---

## Biomes in the model

In the model, biomes are defined through a few driving elements:

- **The dominant PFT**
- **The subdominant PFT**
- **The dominant woody type** (may equal the dominant PFT)
- **The dominant grassy type**

Along with key environmental variables:

- **GDD0** and **GDD5**
- **Temperature of the coldest month (TCM)**
- **Absolute minimum temperature (Tmin)**

---

## Defining your own biomes

You can define any rule base that links PFTs to a biome. The only requirement is a PFT. First, define the biome types themselves: give each a **name** and a **numeric value** (useful for encoding outputs and plotting).

```julia
struct Savanna <: AbstractBiome
    value::Int
    Savanna() = new(6)
end

struct TropicalEvergreenForest <: AbstractBiome
    value::Int
    TropicalEvergreenForest() = new(7)
end

struct TemperateDeciduousForest <: AbstractBiome
    value::Int
    TemperateDeciduousForest() = new(8)
end
````
In the example below, we assign:

* Savanna when the dominant PFT is C4,
* Tropical Evergreen Forest if the PFT is TropicalEvergreen,
* Temperate Deciduous Forest for Temperate Deciduous.

Otherwise, we fall back to the default `Biome.assign_biome` logic.

```julia 
function my_biome_assign(pft::AbstractPFT;
    subpft,
    wdom,
    gdd0,
    gdd5,
    tcm,
    tmin,
    pftlist,
    pftstates,
    gdom)

    if get_characteristic(pft, :c4)
        return Savanna()
    elseif get_characteristic(pft, :name) == "TropicalEvergreen"
        return TropicalEvergreenForest()
    elseif get_characteristic(pft, :name) == "TemperateDeciduous"
        return TemperateDeciduousForest()
    else
        # Fallback to the package's default biome assignment
        return Biome.assign_biome(pft;
            subpft=subpft, wdom=wdom,
            gdd0=gdd0, gdd5=gdd5,
            tcm=tcm, tmin=tmin,
            pftlist=pftlist,
            pftstates=pftstates, gdom=gdom)
    end
end
```