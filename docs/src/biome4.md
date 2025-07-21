# BIOME4


![biome4](assets/output_b4.svg)

We offer to run the BIOME4 model two ways. 

1. Based on a exact translation of the fortran model developped by Jed O. Kaplan and for which the source code is available [here](https://github.com/jedokaplan/BIOME4).

    You can call this model using 

    `````
    `````

2. In so-called `dominance-mode` where we modified the competition logic. 
    We based the new rationale on defining the region of highest dominance of each PFT by fitting a gaussian distribution for the climatological inputs: cloud cover, precipitation, and temperature. For each pixel, the pixel value for the variable will be compared to the distribution and the PFT's dominance in this space is then normalized between 0 and 1 depending on how close it is to the highest dominance point.  
        We then compute dominance as 

        ````
        dominance = dominance_environment(PFT, :clt, mean cloud cover of pixel) + dominance_environment(PFT, :temp, mean temperature of pixel) + dominance_environment(PFT, :prec, mean precipitation of pixel)
        ````
        
        Later on, we multiply this dominance value by the NPP of the PFT. 
        We then rank all PFTs according to the computed value and the PFT with the highest value will be picked as the dominant/most optimal PFT. 

    You can call this model using 

    `````
    `````
    
## References
* Kaplan, J., & Prentice, I. (2001). Geophysical Applications of Vegetation Modeling.