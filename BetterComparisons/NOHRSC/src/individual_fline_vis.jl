burrowactivate()
cd(@__DIR__)
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2

include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_nohrsc.jl"))

basin_to_fline =
    jldopen(joinpath(ERA.NOHRSCDATA, "Land_basin_to_flines.jld2"))["basin_to_flines"]

for basin in ERA.basin_names
    for fline in basin_to_fline[basin]
        data = load_nohrsc.(fline, ERA.eratypes)
        any(ismissing.(data)) && continue
        data = outerjoin(data...; on = :datetime, makeunique = true)
        filter!(x -> month(x.datetime) == 4, data)
        select!(data, :datetime, :gamma, "mean_era_swe" .* ["", "_1"] .=> ERA.eratypes)

        plotdata = Array(data[:, Not(:datetime)])
        medians = mapslices(slice->median(skipmissing(slice)), plotdata, dims = 1)
        plotdata ./= medians ./ 100
        plotdata[ismissing.(plotdata)] .= NaN
        c = [:red :green :blue]
        myplot = plot(
            year.(data.datetime),
            plotdata;
            label = ["NOHRSC" "Base" "Land"],
            xlabel = "Year",
            ylabel = "ERA5 SWE (% median)",
            legend = :outertopleft,
            line = :scatter,
            title = "$fline",
            c
        )
        myticks = (year.(data.datetime), Dates.format.(data.datetime, dateformat"yyyy/mm/dd"))
        plot!(myplot, year.(data.datetime), plotdata; label = "", c, xticks = myticks, rotation=45)
        

        savefig(myplot, "../vis/individual_fline_scatter/$(fline).png")
    end
end
