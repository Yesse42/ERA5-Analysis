cd(@__DIR__)
burrowactivate()
using CSV, DataFrames, Dates, NCDatasets
import ERA5Analysis as ERA

for (eratype, ncpath) in zip(ERA.eratypes, ERA.erafiles)
    nearby_point_idxs = CSV.read("../data/" * eratype * "_chosen_points.csv", DataFrame)
    data = Dataset("$(ERA.ERA5DATA)/$eratype/$ncpath", "r")
    times = data["time"][:]
    sd = data["sd"][:]
    for row in eachrow(nearby_point_idxs)
        sd_at_loc = sd[row.lonidx, row.latidx, :]
        if string(row.stat_id) == "964"
            display(sd_at_loc)
        end
        if all(ismissing.(sd_at_loc))
            continue
        end
        CSV.write("../$(eratype)/$(row.stat_id).csv", DataFrame(; sd = sd_at_loc))
    end
    CSV.write("../$(eratype)/times.csv", DataFrame(; datetime = times))
end
