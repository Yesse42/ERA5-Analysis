include(joinpath(ERA.SCRIPTPATH, "load_era_data.jl"))

function load_era(eratype, lonidx, latidx)
    sd = sds[eratype]
    return DataFrame(time = times[eratype], sd = @view sd[lonidx, latidx, :])
end