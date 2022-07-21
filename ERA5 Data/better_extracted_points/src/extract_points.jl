cd(@__DIR__)
burrowactivate()
using CSV, DataFrames, Dates, NCDatasets
import ERA5Analysis as ERA

for (eratype, ncpath) in zip(ERA.eratypes, ERA.erafiles)
    nearby_point_idxs = CSV.read("../data/" * eratype * "_best_ids.csv", DataFrame)
    data = Dataset("$(ERA.ERA5DATA)/$eratype/$ncpath", "r")
    times = data["time"][:]
    sd = data["sd"][:]
    for row in eachrow(nearby_point_idxs)
        sd_at_loc = sd[row.lonidx, row.latidx, :]
        if all(ismissing.(sd_at_loc))
            continue
        end
        CSV.write("../$(eratype)/$(row.id).csv", DataFrame(; sd = sd_at_loc))
    end
    CSV.write("../$(eratype)/times.csv", DataFrame(; datetime = times))
end
