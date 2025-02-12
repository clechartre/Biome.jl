

using ComponentArrays
using DataStructures


function load_pft_parameters()::ComponentArray
    # Define plant types and parameter names
    plant_types = [
        :tet, :trt, :tbe, :tst, :ctc, :bec, :bst, 
        :C3_C4_temperate_grass, :C4_tropical_grass, 
        :C3_C4_woody_desert, :tundra_shrub, 
        :cold_herbaceous, :lichen_forb
    ]

    parameter_names = [
        :phenological_type, :max_min_canopy_conductance, 
        :Emax, :sw_drop, :sw_appear, :root_fraction_top_soil, 
        :leaf_longevity, :GDD5_full_leaf_out, :GDD0_full_leaf_out, 
        :sapwood_respiration, :c4_plant
    ]

    constraint_names = [
        :ltcm, :utcm, :lmin, :umin, :lgdd, :ugdd, 
        :lgdd0, :ugdd0, :ltwm, :utwm, :lsnow, :usnow
    ]

    additional_parameter_names = [
        :optratioa, :kk, :c4, :threshold, :t0, :tcurve, :respfact, :allocfact
    ]

    # Define specific values for the PFTs and their parameters
    specified_values = [
        [1.0, 0.5, 10.0, -99.0, -99.0, 0.69, 18.0, -99.0, -99.0, 1.0, 0.0],
        [3.0, 0.5, 10.0, 0.5, 0.6, 0.70, 9.0, -99.0, -99.0, 1.0, 0.0],
        [1.0, 0.2, 4.8, -99.0, -99.0, 0.67, 18.0, -99.0, -99.0, 1.0, 0.0],
        [2.0, 0.8, 10.0, -99.0, -99.0, 0.65, 7.0, 200.0, -99.0, 1.0, 0.0],
        [1.0, 0.2, 4.8, -99.0, -99.0, 0.52, 30.0, -99.0, -99.0, 1.0, 0.0],
        [1.0, 0.5, 4.5, -99.0, -99.0, 0.83, 24.0, -99.0, -99.0, 1.0, 0.0],
        [2.0, 0.8, 10.0, -99.0, -99.0, 0.83, 24.0, 200.0, -99.0, 1.0, 0.0],
        [3.0, 0.8, 6.5, 0.2, 0.3, 0.83, 8.0, -99.0, 100.0, 2.0, 1.0],
        [3.0, 0.8, 8.0, 0.2, 0.3, 0.57, 10.0, -99.0, -99.0, 2.0, 1.0],
        [1.0, 0.1, 1.0, -99.0, -99.0, 0.53, 12.0, -99.0, -99.0, 1.0, 1.0],
        [1.0, 0.8, 1.0, -99.0, -99.0, 0.93, 8.0, -99.0, -99.0, 1.0, 0.0],
        [2.0, 0.8, 1.0, -99.0, -99.0, 0.93, 8.0, -99.0, 25.0, 2.0, 0.0],
        [1.0, 0.8, 1.0, -99.0, -99.0, 0.93, 8.0, -99.0, -99.0, 1.0, 0.0]
    ]

    # Define constraints
    constraint_values = [
        [[-99.9, -99.9], [0.0, -99.9], [-99.9, -99.9], [-99.9, -99.9], [10.0, -99.9], [-99.9, -99.9]],
        [[-99.9, -99.9], [0.0, -99.9], [-99.9, -99.9], [-99.9, -99.9], [10.0, -99.9], [-99.9, -99.9]],
        [[-99.9, -99.9], [-8.0, 5.0], [1200.0, -99.9], [-99.9, -99.9], [10.0, -99.9], [-99.9, -99.9]],
        [[-15.0, -99.9], [-99.9, -8.0], [1200.0, -99.9], [-99.9, -99.9], [-99.9, -99.9], [-99.9, -99.9]],
        [[-2.0, -99.9], [-99.9, 10.0], [900.0, -99.9], [-99.9, -99.9], [10.0, -99.9], [-99.9, -99.9]],
        [[-32.5, -2.0], [-99.9, -99.9], [-99.9, -99.9], [-99.9, -99.9], [-99.9, 21.0], [-99.9, -99.9]],
        [[-99.9, 5.0], [-99.9, -10.0], [-99.9, -99.9], [-99.9, -99.9], [-99.9, 21.0], [-99.9, -99.9]],
        [[-99.9, -99.9], [-99.9, 0.0], [550.0, -99.9], [-99.9, -99.9], [-99.9, -99.9], [-99.9, -99.9]],
        [[-99.9, -99.9], [-3.0, -99.9], [-99.9, -99.9], [-99.9, -99.9], [10.0, -99.9], [-99.9, -99.9]],
        [[-99.9, -99.9], [-45.0, -99.9], [500.0, -99.9], [-99.9, -99.9], [10.0, -99.9], [-99.9, -99.9]],
        [[-99.9, -99.9], [-99.9, -99.9], [-99.9, -99.9], [50.0, -99.9], [15.0, -99.9], [15.0, -99.9]],
        [[-99.9, -99.9], [-99.9, -99.9], [-99.9, -99.9], [50.0, -99.9], [15.0, -99.9], [-99.9, -99.9]],
        [[-99.9, -99.9], [-99.9, -99.9], [-99.9, -99.9], [-99.9, -99.9], [15.0, -99.9], [-99.9, -99.9]]
    ]

    # Define additional parameters
    optratioa = [0.95, 0.9, 0.8, 0.8, 0.9, 0.8, 0.9, 0.65, 0.65, 0.70, 0.90, 0.75, 0.80]
    kk = [0.7, 0.7, 0.6, 0.6, 0.5, 0.5, 0.4, 0.4, 0.4, 0.3, 0.5, 0.3, 0.6]
    c4 = [false, false, false, false, false, false, false, false, true, true, false, false, false]
    threshold = [0.25, 0.20, 0.40, 0.33, 0.40, 0.33, 0.33, 0.40, 0.40, 0.33, 0.33, 0.33, 0.33]
    t0 = [10.0, 10.0, 5.0, 4.0, 3.0, 0.0, 0.0, 4.5, 10.0, 5.0, -7.0, -7.0, -12.0]
    tcurve = [1.0, 1.0, 1.0, 1.0, 0.9, 0.8, 0.8, 1.0, 1.0, 1.0, 0.6, 0.6, 0.5]
    respfact = [0.8, 0.8, 1.4, 1.6, 0.8, 4.0, 4.0, 1.6, 0.8, 1.4, 4.0, 4.0, 4.0]
    allocfact = [1.0, 1.0, 1.2, 1.2, 1.2, 1.2, 1.2, 1.0, 1.0, 1.0, 1.0, 1.0, 1.5]


    # Flattened constraint values for easier assignment
    limits_flattened = [vcat(lim...) for lim in constraint_values]

    # Additional parameter values
    additional_params_values = [
        optratioa, kk, c4, threshold, t0, tcurve, respfact, allocfact
    ]

    pftdict = OrderedDict{Symbol, ComponentArray}()

    for i in eachindex(plant_types)
        main_params = (; zip(parameter_names, specified_values[i])...)
        constraints = (; zip(constraint_names, limits_flattened[i])...)
        additional_params = (; zip(additional_parameter_names, [param[i] for param in additional_params_values])...)

        combined_params = (
            main_params = main_params,
            constraints = constraints,
            additional_params = additional_params
        )

        pftdict[plant_types[i]] = ComponentArray(combined_params)
    end

    return ComponentArray(pftdict)
end

