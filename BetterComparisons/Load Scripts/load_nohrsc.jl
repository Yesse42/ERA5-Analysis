include(joinpath(@__DIR__, "../comparison_constants.jl"))

const nohrscdir = joinpath(ERA.ERA5DATA, "extracted_flightlines", "data")

const dict = Dictionary(ERA.eratypes, [jldopen(joinpath(nohrscdir, "$(eratype)_flightline_era_data.jld2"))["flightline_era_data"] for eratype in ERA.eratypes])

function load_nohrsc(id, eratype)
    data = dict[eratype][id]
    data.datetime = Date.(data.datetime)
    return data
end
