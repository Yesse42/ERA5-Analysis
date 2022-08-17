burrowactivate()
import ERA5Analysis as ERA
cd(@__DIR__)
using Plots, DataFrames, CSV, StatsBase
gr()

include.(joinpath.(ERA.COMPAREDIR, "Load Scripts", "load_" .* ("era", "snow_course") .* ".jl"))

mycourse = "46P04"
eratype = "Land"

plotdata = innerjoin(load_plain_nn(eratype, mycourse), load_snow_course(mycourse); on=:datetime)
sort!(plotdata)
filter!(row->month(row.datetime+Day(16))==4 && 2015 <= year(row.datetime), plotdata)
swecols = [:era_swe, :snow_course_swe]
median_mask = Date(1991) .<= plotdata.datetime .< Date(2021)
for col in swecols
    med = median(plotdata[median_mask, col])
    plotdata[!, col] = plotdata[!, col] ./ med
end
plot(plotdata.datetime, Array(plotdata[:, swecols]); labels = ["ERA5 $eratype SWE" "Snow Course SWE"],
        xlabel = "Date", ylabel = "Fraction of Median (FOM)", title = "Colorado Creek Snow Course ($mycourse) Data Sample",
        xformatter = f(t) = Dates.format(t, dateformat"yyyy/mm/dd"), xticks = plotdata.datetime, rotation = 20., legend=:topleft)

savefig("../vis/sample.png")
