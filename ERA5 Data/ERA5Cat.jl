using NCDatasets, DataStructures

#List of files in time order
datasets = NCDataset.(["ERA5 Data/Base/ERA5-SD-1979-2021-DL-2022-6-15.nc", "ERA5 Data/Base/ERA5-SD-2022-2022-DL-2022-6-16.nc"], "r")

#Get the attributes, all of which can be from the first
vars = keys(datasets[1])
dims = keys(datasets[1].dim)
attribs = keys(datasets[1].attrib)

newtime = vcat(Array.(getproperty.(getindex.(datasets, "time"),:var))...)
#combine the two different expver into one Array
function choose_expver(d...)
    for data in d
        if data ≢ missing
            return data
        end
    end
end
interweaved = choose_expver.(datasets[2]["sd"][:,:,1,:], datasets[2]["sd"][:,:,2,:])
newsd = cat(Array.((datasets[1]["sd"], interweaved))...; dims=3)

#Now create the new dataset
fname = "ERA5 Data/Base/ERA5-SD-1979-2022-CREATE-2022-06-16.nc"
if isfile(fname) rm(fname) end
combo = NCDataset(fname, "c")

defDim(combo, "longitude", 158)
defDim(combo, "latitude", 70)
defDim(combo, "time", length(newtime))
for vname in ("longitude", "latitude")
    defVar(combo, vname, datasets[1][vname].var[:], (vname,); attrib = datasets[1][vname].attrib)
end
defVar(combo, "time", newtime, ("time",); attrib = datasets[1]["time"].attrib)
sdvar = defVar(combo, "sd", newsd, ("longitude","latitude","time"))
for (k,v) in datasets[1]["sd"].attrib
    if k in ("_FillValue","missing_value", "add_offset","scale_factor") continue end
    sdvar.attrib[k] = v
end
combo.attrib = datasets[1].attrib
close(combo)
