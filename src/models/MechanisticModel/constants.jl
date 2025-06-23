# constants.jl 
module Constants

    const T = Real 

    # Export calls export all future constants defined
    export P0, CP, T0, G, M, R0,
        QEFFC3, DRESPC3, ABS1, TETA, SLO2, JTOE, OPTRATIO,
        KO25, KC25, TAO25, CMASS, KCQ10, KOQ10, TAOQ10,
        TWIGLOSS, TUNE, LEAFRESP,
        MAXTEMP,
        LN, Y, M10, P1, STEMCARBON,
        E0, TREF, TEMP0,
        A, ES, A1, B3, B

    # Define constants
    # Engine
    const P0 = T(101325.0)  # sea level standard atmospheric pressure (Pa)
    const CP = T(1004.68506 ) # constant-pressure specific heat (J kg-1 K-1)
    const T0 = T(288.16)    # sea level standard temperature (K)
    const G = T(9.80665)    # earth surface gravitational acceleration (m s-1)
    const M = T(0.02896968) # molar mass of dry air (kg mol-1)
    const R0 = T(8.314462618)  # universal gas constant (J mol-1 K-1)

    # Photosynthesis
    const ABS1 = T(1.0)
    const CMASS = T(12.0)
    const DRESPC3 = T(0.015)
    const DRESPC4 = T(0.03)
    const JTOE = T(2.3e-6)
    const KC25 = T(30.0)
    const KCQ10 = T(2.1)
    const KO25 = T(30.0e3)
    const KOQ10 = T(1.2)
    const LEAFRESP = T(0.0)
    const OPTRATIO = T(0.95)
    const QEFFC3 = T(0.08)
    const SLO2= T(20.9e3)
    const TAO25 = T(2600.0)
    const TAOQ10 = T(0.57)
    const TETA = T(0.7)
    const TUNE = T(1.0)
    const TWIGLOSS = T(1.0)

    # C4 Photo 
    const MAXTEMP::T = T(55.0)

    # Respiration
    const E0 = T(308.56)
    const LN = T(50.0)
    const M10 = T(1.6)
    const P1 = T(0.25)
    const STEMCARBON = T(0.5)
    const TEMP0 = T(46.02)
    const TREF = T(10.0)
    const Y = T(0.8)

    # Isotopes
    const A = T(4.4)
    const ES = T(1.1)
    const A1 = T(0.7)
    const B3 = T(30.0)
    const B = T(27.5)

end # module Constants