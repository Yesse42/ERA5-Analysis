cd(@__DIR__)
burrowactivate()
using CSV, DataFrames, Dates, Plots, JLD2, StatsBase
import ERA5Analysis as ERA

#We just want to plot every SNOTEL's monthly min, mean, and max and all avilable Snow Course observations to ensure
#that nothing fishy is going on
all_metadata = CSV.read("../data/cleansed/Metadata.csv", DataFrame)

for network in ERA.networktypes
    data = CSV.read("../data/cleansed/$(network)_Data.csv", DataFrame)
    metadata = filter(x->x.Network == network, all_metadata)
    for row in eachrow(metadata)
        station = string(row.ID)
        timename = if network == "SNOTEL" "datetime" else "datetime_$station" end
        swename = "SWE_$station"
        stationdata = data[:, [timename, swename]]
        dropmissing!(stationdata)

        #Now groupby month
        transform!(
            stationdata,
            timename => ByRow(t -> Dates.round(t, Month(1), RoundDown)) => timename,
            swename.=>(x ->x .* ERA.meter_to_inch .* 1e-3)=>swename
        )
        month_group = groupby(stationdata, timename)
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
            monthly_stats[!, timename],
            Array(monthly_stats[:, Not(timename)]);
            title = "$(row.Name) in $(row.County), ID: $(row.ID)",
            ylabel = "SWE (in)",
            xlabel = "Date",
            label = ["min" "mean" "max"],
            legend = :topleft,
        )
        save("../vis/$network/$(row.ID).png", myplot)
    end
end
