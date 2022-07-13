cd(@__DIR__)
burrowactivate()
using CSV, DataFrames, Dates, Plots, JLD2, StatsBase
import ERA5Analysis as ERA

#Plot every extracted station's mean, min, and max by month, to see if anything sus is going on
const swename = "sd"

for eratype in ERA.eratypes
    files = readdir("../$(eratype)")
    filter!(x -> occursin(".csv", x) && x ≠ "times.csv", files)
    ids = replace.(files, Ref(".csv" => ""))
    times = CSV.read("../$(eratype)/times.csv", DataFrame)
    for id in ids
        sd_data = CSV.read("../$(eratype)/$id.csv", DataFrame)
        sd_data.sd .*= ERA.meters_to_inch
        stationdata = hcat(times, sd_data)

        #Now groupby month
        transform!(
            stationdata,
            :datetime => ByRow(t -> Dates.round(t, Month(1), RoundDown)) => :datetime,
        )
        month_group = groupby(stationdata, :datetime)
        myskipmiss(x) =
            if all(ismissing.(x))
                return [missing]
            else
                return skipmissing(x)
            end
        stat_funcs = (minimum, mean, maximum) .∘ myskipmiss
        monthly_stats =
            combine(month_group, (swename .=> stat_funcs .=> ["min", "mean", "max"])...)
        dropmissing!(monthly_stats)

        #And now plot
        myplot = plot(
            monthly_stats.datetime,
            Array(monthly_stats[:, Not(:datetime)]);
            title = "ID: $id",
            ylabel = "SWE (in)",
            xlabel = "Date",
            label = ["min" "mean" "max"],
            legend = :topleft,
        )
        save("../vis/$(eratype)_sanity/$id.png", myplot)
    end
end
