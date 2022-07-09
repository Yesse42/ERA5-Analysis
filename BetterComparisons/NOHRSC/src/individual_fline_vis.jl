burrowactivate()
cd(@__DIR__)
import ERA5Analysis as ERA 
using CSV, DataFrames, Plots, JLD2

include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_nohrsc.jl"))

basin_to_fline = jldopen(joinpath(ERA.NOHRSCDATA, "Land_basin_to_flines.jld2"))["basin_to_flines"]

for basin in ERA.basin_names
    for fline in basin_to_fline[basin]
        data = load_nohrsc.(fline, ERA.eratypes)
        any(ismissing.(data)) && continue
        data = outerjoin(data...; on=:datetime, makeunique=true)
        filter!(x->month(x.datetime)==4, data)
        select!(data, :datetime, :gamma, "mean_era_swe".*["","_1"].=>ERA.eratypes)

        plotdata = Array(data[:, Not(:datetime)])
        plotdata[ismissing.(plotdata)] .= NaN
        myplot = plot(year.(data.datetime), plotdata; label=["NOHRSC" "Base" "Land"], xlabel="Year",
        ylabel = "ERA5 SWE (in)", aspect_ratio = :equal, legend = :outertopleft, line=:scatter)
        plot!(myplot, year.(data.datetime), plotdata; label="")

        savefig(myplot, "../vis/individual_fline_scatter/$(fline).png")
    end
end