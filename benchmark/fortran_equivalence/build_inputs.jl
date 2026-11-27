# Build the input table shared by the Fortran BIOME4 and Biome.jl runs.
#   inputs.f32 : 50 x N Float32, the BIOME4 `vars_in` layout (one column per land cell)
#   soils.f32  : 18 x N Float32, the 6-layer soil used by Biome.jl (ksat, whc, dz)
#   ncell.txt  : N
# usage: julia --project=. build_inputs.jl <climatology dir> <output dir>
using NCDatasets

climdir, outdir = ARGS
mkpath(outdir)
co2 = 324.0f0
p   = 101325.0f0   # sea-level pressure

readvar(file, var) = NCDataset(ds -> Float32.(coalesce.(ds[var][:, :, :], NaN32)), joinpath(climdir, file))
temp = readvar("temp_1981-2010.nc", "temp")
prec = readvar("prec_1981-2010.nc", "prec")
sun  = 100f0 .- readvar("sun_1981-2010.nc", "sun")   # file holds cloud cover (%)
ksat = readvar("soils_55km.nc", "Ksat")
whc  = readvar("soils_55km.nc", "whc")
lon, lat, dz = NCDataset(joinpath(climdir, "soils_55km.nc")) do ds
    Float32.(ds["lon"][:]), Float32.(ds["lat"][:]), Float32.(ds["dz"][:])
end

inputs = Vector{Float32}[]
soils  = Vector{Float32}[]
for j in eachindex(lat), i in eachindex(lon)
    t, pr, s = temp[i, j, :], prec[i, j, :], sun[i, j, :]
    k, w = ksat[i, j, :], whc[i, j, :]
    all(x -> isfinite(x) && x != -9999, [t; pr; s; k; w]) || continue

    v = zeros(Float32, 50)
    v[1] = lat[j]; v[2] = co2; v[3] = p
    v[4] = 0.006f0 * minimum(t)^2 + 1.316f0 * minimum(t) - 21.9f0   # tmin regression (BIOME4 driver)
    v[5:16] = t; v[17:28] = pr; v[29:40] = s
    v[41] = sum(k[1:3] .* dz[1:3]) / sum(dz[1:3])   # Ksat, top / bottom layer
    v[42] = sum(k[4:6] .* dz[4:6]) / sum(dz[4:6])
    v[43] = sum(w[1:3] .* dz[1:3])                  # water holding capacity (mm)
    v[44] = sum(w[4:6] .* dz[4:6])
    v[49] = lon[i]
    push!(inputs, v)
    push!(soils, [k; w; dz])
end

write(joinpath(outdir, "inputs.f32"), reduce(hcat, inputs))
write(joinpath(outdir, "soils.f32"), reduce(hcat, soils))
write(joinpath(outdir, "ncell.txt"), string(length(inputs)))
println("land cells: ", length(inputs))
