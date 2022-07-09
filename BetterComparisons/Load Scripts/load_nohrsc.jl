include(joinpath(@__DIR__, "../comparison_constants.jl"))

const nohrscdir = joinpath(ERA.ERA5DATA, "extracted_flightlines", "data")

const dict = Dictionary(
    ERA.eratypes,
    [
        jldopen(joinpath(nohrscdir, "$(eratype)_flightline_era_data.jld2"))["flightline_era_data"]
        for eratype in ERA.eratypes
    ],
)

function load_nohrsc(id, eratype)
    if id ∉ keys(dict[eratype])
        return missing
    end
    data = dict[eratype][id]
    return select(data, :date => ByRow(Date) => :datetime, Not(:date))
end
