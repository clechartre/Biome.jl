# Run Biome.jl (BIOME4Model) on every cell of inputs.f32, step by step as in Biome.runmodel,
# and write 27 Float32 per cell: biome, NPP of the 13 PFTs, LAI of the 13 PFTs.
# usage: julia --project=. -t <threads> run_biomejl.jl <data dir> <output file>
using Biome
using Biome: initialize_environmental_variables, initialize_pftstates, constraints,
             findnpp, phenology, competition, get_characteristic, get_biome_characteristic

datadir, outfile = ARGS
n = parse(Int, readline(joinpath(datadir, "ncell.txt")))
inputs = Array{Float32}(undef, 50, n); read!(joinpath(datadir, "inputs.f32"), inputs)
soils  = Array{Float32}(undef, 18, n); read!(joinpath(datadir, "soils.f32"), soils)

function runcell(v, s)
    pftlist = Biome.BIOME4.PFTClassification{Float32,Int}()
    env = initialize_environmental_variables((lat = v[1], lon = v[49], co2 = v[2], p = v[3],
        tas = v[5:16], pr = v[17:28], clt = v[29:40],
        ksat = s[1:6], whc = s[7:12], dz = s[13:18]))
    pftstates, npft = initialize_pftstates(pftlist, env.tcm, env.tmin, env.gdd5, env.gdd0, env.twm, env.maxdepth)
    pftstates = constraints(pftlist, pftstates, env)
    dphen = env.dphen
    for pft in pftlist.pft_list
        state = pftstates[pft]
        state.present || continue
        if get_characteristic(pft, :phenological_type) >= 2
            dphen = phenology(dphen, env.dtas, env.tas, env.tcm, env.tmin, pft, env.ddayl)
        end
        _, lai, npp, state = findnpp(pft, env.tpr, env.dtas, env.sun, env.tas, env.dpr, env.dmelt,
                                     env.dpet, env.dayl, env.k, dphen, env.co2, env.p, env.tsoil, state)
        state.npp, state.lai = npp, lai
        pftstates[pft] = state
    end
    biome, _, _ = competition(Biome.BIOME4Model(), env.tmin, env.tpr, npft, env.gdd0, env.gdd5, env.tcm,
                              pftlist, pftstates, Biome.BIOME4.assign_biome, env)
    npp = [pftstates[p].present ? pftstates[p].npp : 0f0 for p in pftlist.pft_list]
    lai = [pftstates[p].present ? pftstates[p].lai : 0f0 for p in pftlist.pft_list]
    return Float32[get_biome_characteristic(biome, :value); npp; lai]
end

results = zeros(Float32, 27, n)
runcell(inputs[:, 1], soils[:, 1])   # compile before timing
seconds = @elapsed Threads.@threads for c in 1:n
    results[:, c] = runcell(inputs[:, c], soils[:, c])
end
write(outfile, results)
println("Biome.jl, $(Threads.nthreads()) thread(s): $(round(seconds, digits=1)) s, ",
        "$(round(1000seconds / n, digits=2)) ms per cell")
