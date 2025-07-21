# Wissmann

The Wissmann scheme partitions climates into six major groups (from Tropical through Polar) and within each applies moisture thresholds to distinguish rainforest, monsoonal, steppe and desert subtypes. 


![wissman](assets/output_wissmann_example.svg)


In the provided function, the twelve monthly temperatures and precipitations are first summarized (min, max, mean temperatures; total and minimum precipitation; plus seasonal sums for “winter” and “summer” based on hemisphere). A dynamic precipitation threshold (t_threshold) is computed as ten times the mean annual temperature (shifted by +14 °C if summer is wetter than winter). The main classes are applied with thresholds: 

* Polar (Group VI if max < 0 °C; V if max < 10 °C)

* Boreal (Group IV when mean < 4 °C), with four moisture classes (IV_F humid, IV_T winter‑dry, IV_S steppe, IV_D desert) based on precipitation relative to 1×, 2×, or 2.5× t_threshold

* Cool temperate (Group III when min < 2 °C), with analogous moisture splits and a winter‑vs‑summer dry distinction for the Ts/Tw subtypes

* Warm temperate (Group II when 2 °C ≤ min < 13 °C), where hot summers (max > 23 °C) get the Fa vs. Fb humid subtype, and Ts/Tw or IS/ID for intermediate and arid regimes

* Tropical (Group I when min ≥ 13 °C), where a driest‐month check (precip_min ≥ 60 mm) yields the equatorial IA rainforest type, otherwise IF (weak dry period), IT (monsoonal), IS (savanna) or ID (desert) by the same 1‒2.5 × threshold bins.


You can call this model using 

`````
`````

## References

* Wissmann, H. (1939). In Die Klima-und Vegetationsgebiete Eurasiens: Begleitworte zu einer Karte der Klimagebiete Eurasiens. (pp. 81–92). Erdk. Berlin.