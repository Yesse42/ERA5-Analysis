cd(@__DIR__)
burrowactivate()
using CSV, DataFrames, Dates, Plots, JLD2, StatsBase
import ERA5Analysis as ERA

#We just want to plot every SNOTEL's monthly min, mean, and max and all avilable Snow Course observations to ensure
#that nothing fishy is going on

for network in ERA.networktypes
    data = CSV.read("../data/cleansed/$(network)_Data.csv", DataFrame)
    metadata = CSV.read("../data/cleansed/$(network)_Metadata.csv", DataFrame)
    for row in eachrow(metadata)
        station = string(row.ID)
        swename = "SWE_$station"
        stationdata = data[:, ["datetime", swename]]

        #Now groupby month
        transform!(stationdata, :datetime=>ByRow(t->Dates.round(t, Month(1), RoundDown))=>:datetime)
        month_group = groupby(stationdata, :datetime)
        myskipmiss(x) = if all(ismissing.(x)) return [missing] else return skipmissing(x) end
        stat_funcs =(minimum, mean, maximum) .∘ myskipmiss
        monthly_stats = combine(month_group, (swename.=>stat_funcs.=>["min","mean","max"])...)
        display(monthly_stats)
        dropmissing!(monthly_stats)

        #And now plot
        myplot = plot(monthly_stats.datetime, Array(monthly_stats[:,Not(:datetime)]); title="$(row.Name) in $(row.Basin), ID: $(row.ID)",
                        ylabel="SWE (mm)", xlabel="Date", label=["min" "mean" "max"], legend=:topleft)
        save("../vis/$network/$(row.ID).png", myplot)
    end
end