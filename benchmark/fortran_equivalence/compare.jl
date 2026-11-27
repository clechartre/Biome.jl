# Compare the Fortran BIOME4 and Biome.jl outputs cell by cell.
# NPP is compared after rounding to 1 gC m-2 yr-1 and LAI after rounding to 0.01,
# the precision of the BIOME4 output (v4.2.3 rounds, later versions do not).
# usage: julia --project=. compare.jl <data dir> <fortran output> <julia output>
using Printf, Statistics

datadir, ffile, jfile = ARGS
n = parse(Int, readline(joinpath(datadir, "ncell.txt")))
load(file) = (x = Array{Float32}(undef, 27, n); read!(file, x); Float64.(x))
F, J = load(ffile), load(jfile)
pfts = ["TrEv", "TrDD", "TeBE", "TeSu", "CoolCon", "BoEv", "BoDe",
        "C3C4Gr", "C4TrGr", "WoDes", "TunShr", "ColdHerb", "LichForb"]

same = F[1, :] .== J[1, :]
@printf("Biome agreement: %.2f%% of %d cells (%d differ)\n", 100mean(same), n, count(!, same))

pairs = Dict{Tuple{Int,Int},Int}()
for c in findall(!, same)
    key = (Int(F[1, c]), Int(J[1, c]))
    pairs[key] = get(pairs, key, 0) + 1
end
println("Most frequent (Fortran, Biome.jl) biome pairs: ", first(sort(collect(pairs), by = last, rev = true), 8))

# Cells whose only difference is the tropical evergreen PFT (switched off in the Fortran)
rest_same(c) = round.(F[3:14, c]) == round.(J[3:14, c]) &&
               round.(F[16:27, c], digits=2) == round.(J[16:27, c], digits=2)
println("Differing cells explained by tropical evergreen alone: ", count(rest_same, findall(!, same)))

println("\nPer PFT, over cells where either model has the PFT:")
println("PFT        cells  NPP exact  NPP r     LAI exact  LAI r")
for (k, name) in enumerate(pfts)
    fn, jn = round.(F[1+k, :]),            round.(J[1+k, :])
    fl, jl = round.(F[14+k, :], digits=2), round.(J[14+k, :], digits=2)
    m = (fn .!= 0) .| (jn .!= 0)
    count(m) < 3 && continue
    if all(fn .== 0) || all(jn .== 0)
        @printf("%-9s %6d  present in one model only\n", name, count(m))
        continue
    end
    @printf("%-9s %6d  %8.2f%%  %.4f  %8.2f%%  %.4f\n", name, count(m),
            100mean(fn[m] .== jn[m]), cor(fn[m], jn[m]),
            100mean(fl[m] .== jl[m]), cor(fl[m], jl[m]))
end
