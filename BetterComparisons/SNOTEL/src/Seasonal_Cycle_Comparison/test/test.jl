include("../calculate_seasonal_cycle.jl")
using Plots

include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_snotel.jl"))

station = 1073

data = load_snotel("$station")

my_year = 2021

filter!(row->Date(my_year, 9, 1) <= row.datetime <= Date(my_year+1, 8, 31), data)

shape = swe_shape(data.snotel_swe, day_of_water_year.(data.datetime), 0.01:0.05:0.99)

smoothdata = swe_shape_output_to_interpolated_values(shape)

p = plot(smoothdata.daysofyear, smoothdata.swe_interped)

plot!(p, day_of_water_year.(data.datetime), data.snotel_swe ./ maximum(data.snotel_swe))

display(p)
