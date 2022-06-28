cd(@__DIR__)
using CSV, DataFrames, Dates, NCDatasets

ncpaths = ["../../Base/ERA5-SD-1979-2022-CREATE-2022-06-16.nc", "../../Land/ERA5-Land-SD-1979-2022-DL-2022-6-15.nc"]

for (eratype, ncpath) in zip(["Base", "Land"], ncpaths)
    nearby_point_idxs = CSV.read("../data/"*eratype*"_nearby_point_idx.csv", DataFrame)
    data = Dataset(ncpath,"r")
    times = data["time"][:]
    sd = data["sd"][:]
    for row in eachrow(nearby_point_idxs)
        if row.col ≡ missing continue end
        data = sd[row.row, row.col, :]
        CSV.write("../$(eratype)/$(row.ID).csv", DataFrame(sd=data))
    end
    CSV.write("../$(eratype)/times.csv", DataFrame(datetime=times))
end