"""
calcphi(gpp::AbstractVector{T})::T

Calculate the maximum quantum yield of photosynthesis based on GPP data.

# Arguments
- `gpp`: An array of 12 T values representing Gross Primary Productivity for each month.

# Returns
- `phi`: The calculated maximum quantum yield of photosynthesis.
"""
function calcphi(gpp::AbstractVector{T})::T where {T <: Real}
@assert length(gpp) == 12 "gpp must have exactly 12 elements"

totgpp = sum(gpp)
meangpp = totgpp / T(12.0)
normgpp = [g / meangpp for g in gpp]

snormavg = T[0.0, 0.0, 0.0, 0.0]
snormavg[1] = sum(normgpp[1:3]) / T(3.0)
snormavg[2] = sum(normgpp[4:6]) / T(3.0)
snormavg[3] = sum(normgpp[7:9]) / T(3.0)
snormavg[4] = sum(normgpp[10:12]) / T(3.0)

svar = T[0.0, 0.0, 0.0, 0.0]
for m in 1:3
    a = ((normgpp[m] - snormavg[1]) ^ 2) / T(3.0)
    svar[1] += a
end

for m in 4:6
    a = ((normgpp[m] - snormavg[2]) ^ 2) / T(3.0)
    svar[2] += a
end

for m in 7:9
    a = ((normgpp[m] - snormavg[3]) ^ 2) / T(3.0)
    svar[3] += a
end

for m in 10:12
    a = ((normgpp[m] - snormavg[4]) ^ 2) / T(3.0)
    svar[4] += a
end

avar = sum(svar)
phi = T(0.3518717) * avar + T(0.2552359)

if phi >= T(1.0)
    phi /= T(10.0)
end

return phi
end
