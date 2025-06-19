- src/
  - models/
    - abstractmodel.jl --> abstract type
    - engine.jl
    - MechanisticModel/
      - competition.jl
      - pft.jl
     
      - biome.jl
    - ClimaticEnvelope/
      - KoppenGeiger/

Ideally, a new user can add a `PFTType` or `NewBiome` type, and only needs to add functions (`assign_biome`, ) that specifies how `run` function will handle those against the already implemented PFTs.
