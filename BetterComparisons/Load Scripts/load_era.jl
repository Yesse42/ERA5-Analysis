include(joinpath(@__DIR__, "../comparison_constants.jl"))

function load_era(eradatadir, eratype, id)
    if !isfile(joinpath(eradatadir, eratype, "$id.csv"))
        return missing
    end

    times = CSV.read(joinpath(eradatadir, eratype, "times.csv"), DataFrame)
    data = CSV.read(joinpath(eradatadir, eratype, "$id.csv"), DataFrame)
    #Set to midnight for later joining
    times.datetime = Date.(times.datetime)
    #Convert to mm
    data.sd .*= 1e3
    eradata = rename!(hcat(times, data), [:datetime, :era_swe])

    #1979 is a cursed year, so throw it out
    filter!(x->year(x.datetime)>1979, eradata)

    return eradata
end
