cd(@__DIR__)
burrowactivate()
import ERA5Analysis as ERA
using NCDatasets, AxisArrays, Plots
datasets = Dataset.(joinpath.(ERA.ERA5DATA, ERA.eratypes, ERA.erafiles))
nice_datasets = [AxisArray(ds["sd"][:], lon=ds["longitude"][:], lat=ds["latitude"][:], time=ds["time"][:]) for ds in datasets];
nice_datasets = [arr[:,end:-1:begin, :] for arr in nice_datasets]
lonlat = (-149.62, 60.19)
offset = 0.5 .* (-1, 1)
lonbounds = lonlat[1] .+ offset
latbounds = lonlat[2] .+ offset
interv(tup) = tup[1]..tup[2]
filtered = [ds[lon=interv(lonbounds), lat = interv(latbounds), time = :] for ds in nice_datasets];

for (i, eratype) in enumerate(ERA.eratypes)
    data = filtered[i]
    time = AxisArrays.axes(data, 3).val
    for I in CartesianIndices(data[:,:,1])
        tseries = data[I,:]
        (any(ismissing.(tseries)) || !(all(tseries .> 0))) && continue
        display(plot(time, tseries; title = "$eratype"))
    end
end