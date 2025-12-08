"""
    Constants

Module containing all physical and biological constants used in the BIOME model.

This module defines constants for atmospheric physics, photosynthesis parameters,
respiration coefficients, and isotopic fractionation factors.
"""
module Constants

const T = Real 

# Export all constants for use in other modules
export MIDDAY_365, P0, CP, T0, G, M, R0,
       QEFFC3, DRESPC3, DRESPC4, ABS1, TETA, SLO2, JTOE, OPTRATIO,
       KO25, KC25, TAO25, CMASS, KCQ10, KOQ10, TAOQ10,
       TWIGLOSS, TUNE, LEAFRESP,
       MAXTEMP,
       LN, Y0, M10, P1, STEMCARBON,
       E0, TREF, TEMP0,
       A, ES, A1, B3, B

# Daily interpolations
const MIDDAY_365 =  [
    16, 44, 75, 105, 136, 166,
    197, 228, 258, 289, 319, 350
]

# Atmospheric and physical constants
const P0 = T(101325.0)      # Sea level standard atmospheric pressure (Pa)
const CP = T(1004.68506)    # Constant-pressure specific heat (J kg⁻¹ K⁻¹)
const T0 = T(288.16)        # Sea level standard temperature (K)
const G = T(9.80665)        # Earth surface gravitational acceleration (m s⁻²)
const M = T(0.02896968)     # Molar mass of dry air (kg mol⁻¹)
const R0 = T(8.314462618)   # Universal gas constant (J mol⁻¹ K⁻¹)

# Photosynthesis constants
const ABS1 = T(1.0)         # Light absorption coefficient
const CMASS = T(12.0)       # Carbon atomic mass (g mol⁻¹)
const DRESPC3 = T(0.015)    # Dark respiration coefficient for C3 plants
const DRESPC4 = T(0.03)     # Dark respiration coefficient for C4 plants
const JTOE = T(2.3e-6)      # Conversion factor J to E (mol photons)
const KC25 = T(30.0)        # Michaelis constant for CO₂ at 25°C (Pa)
const KCQ10 = T(2.1)        # Q10 temperature coefficient for KC
const KO25 = T(30.0e3)      # Michaelis constant for O₂ at 25°C (Pa)
const KOQ10 = T(1.2)        # Q10 temperature coefficient for KO
const LEAFRESP = T(0.0)     # Leaf respiration rate
const OPTRATIO = T(0.95)    # Optimal intercellular CO₂ ratio
const QEFFC3 = T(0.08)      # Quantum efficiency for C3 photosynthesis
const SLO2 = T(20.9e3)      # Oxygen partial pressure (Pa)
const TAO25 = T(2600.0)     # CO₂/O₂ specificity ratio at 25°C
const TAOQ10 = T(0.57)      # Q10 temperature coefficient for TAO
const TETA = T(0.7)         # Curvature parameter for light response
const TUNE = T(1.0)         # Tuning parameter
const TWIGLOSS = T(1.0)     # Twig loss coefficient

# C4 photosynthesis constants
const MAXTEMP = T(55.0)     # Maximum temperature for C4 photosynthesis (°C)

# Respiration constants
const E0 = T(308.56)        # Activation energy (K)
const LN = T(50.0)          # Leaf nitrogen content (g m⁻²)
const M10 = T(1.6)          # Respiration multiplier at 10°C
const P1 = T(0.25)          # Root respiration coefficient
const STEMCARBON = T(0.5)   # Stem carbon content (kg C m⁻²)
const TEMP0 = T(46.02)      # Reference temperature offset (K)
const TREF = T(10.0)        # Reference temperature (°C)
const Y0 = T(0.8)            # Growth efficiency coefficient

# Isotopic fractionation constants
const A = T(4.4)            # Fractionation during CO₂ diffusion (‰)
const ES = T(1.1)           # Fractionation during CO₂ dissolution (‰)
const A1 = T(0.7)           # Fractionation coefficient
const B3 = T(30.0)          # Fractionation during C3 carboxylation (‰)
const B = T(27.5)           # Fractionation during RuBisCO carboxylation (‰)

end # module Constants