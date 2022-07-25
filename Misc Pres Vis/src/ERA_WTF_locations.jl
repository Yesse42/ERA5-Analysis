burrowactivate()
cd(@__DIR__)
import ERA5Analysis as ERA
using CSV, DataFrames, Plots

include("load_era_at_point.jl")

wtfdict = Dictionary{String, Vector{NTuple{2, Int}}}()
insert!(wtfdict, "Base", [(30, 25), (28, 24)])
insert!(wtfdict, "Land", [])

savedir = "../vis/wtf_plots"
mkpath(savedir)

for eratype in ERA.eratypes
    lonlats = wtfdict[eratype]
    for point in lonlats
        data = load_era(eratype, point...)
        p = plot(data.time, data.sd; title = "(lonidx, latidx) = $point", ylabel = "SWE (m)")
        savefig(p, joinpath(savedir, "(lonidx, latidx) = $point.png"))
    end
end