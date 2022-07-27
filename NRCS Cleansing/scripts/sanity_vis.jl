cd(@__DIR__)
burrowactivate()
using CSV, DataFrames, Dates, Plots, JLD2, StatsBase
import ERA5Analysis as ERA

#We just want to plot every SNOTEL's monthly min, mean, and max and all avilable Snow Course observations to ensure
#that nothing fishy is going on
all_metadata = CSV.read("../data/cleansed/Metadata.csv", DataFrame)
include.(joinpath.(ERA.COMPAREDIR, "Load Scripts", ("load_snow_course.jl", "load_snotel.jl")))

for (network, loadfunc, label) in zip(ERA.networktypes, (load_snotel, load_snow_course), (:snotel_swe, :snow_course_swe))
    basin_to_stations = jldopen("../data/cleansed/$(network)_basin_to_id.jld2")["basin_to_id"]
    data = CSV.read("../data/cleansed/$(network)_Data.csv", DataFrame)
    for basin in ERA.basin_names
        allowed_ids = basin_to_stations[basin]
        isempty(allowed_ids) && continue
        metadata = filter(x->string(x.ID) in allowed_ids, all_metadata)
        dfs = loadfunc.(allowed_ids)
        dropmissing!.(dfs)
        p=plot(; title="$basin $network", legend = :outertopleft)
        for (df, id) in zip(dfs, allowed_ids)
            plot!(p, df.datetime, df[!, label]; label = id)
        end
        
        savefig(p, "../vis/$network/$basin.png")
    end
end
