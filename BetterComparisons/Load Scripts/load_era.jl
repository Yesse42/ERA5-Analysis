include(joinpath(@__DIR__, "../comparison_constants.jl"))

function load_era(eradatadir, eratype, id)
    #Skip if there is no extracted point there due to glaciation for either ERA5 type
    #=if !isfile(joinpath(eradatadir, eratype, "$id.csv"))
        return missing
    end=#

    times = CSV.read(joinpath(eradatadir, eratype, "times.csv"), DataFrame)
    data = CSV.read(joinpath(eradatadir, eratype, "$id.csv"), DataFrame)
    #Set to midnight for later joining
    times.datetime = Date.(times.datetime)
    #Convert to mm
    data.sd .*= 1e3
    eradata = rename!(hcat(times, data), [:datetime, Symbol(eratype)])

    return eradata
end