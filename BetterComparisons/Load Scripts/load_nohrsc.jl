include(joinpath(@__DIR__, "../comparison_constants.jl"))

load_nohrsc, load_nohrsc_only, load_nohrsc_era = let

    nohrscdir = joinpath(ERA.ERA5DATA, "extracted_flightlines", "data")

    dict = Dictionary(
        ERA.eratypes,
        [
            jldopen(joinpath(nohrscdir, "$(eratype)_flightline_era_data.jld2"))["flightline_era_data"]
            for eratype in ERA.eratypes
        ],
    )

    (function load_nohrsc(id, eratype = "Base")
        if id ∉ keys(dict[eratype])
            return missing
        end
        data = dict[eratype][id]
        return select(data, :date => ByRow(Date) => :datetime, Not(:date))
    end,

    function load_nohrsc_only(id, eratype = "Base")
        if id ∉ keys(dict[eratype])
            return missing
        end
        data = dict[eratype][id]
        out = select(data, :date => ByRow(Date) => :datetime, :gamma)
        return out
    end,

    function load_nohrsc_era(_, eratype, id)
        if id ∉ keys(dict[eratype])
            return missing
        end
        data = dict[eratype][id]
        out = select(data, :date => ByRow(Date) => :datetime, :mean_era_swe)
        return out
    end)
end
