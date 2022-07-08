using CSV, DataFrames, Dates, Dictionaries, JLD2, StatsBase, Plots
cd(@__DIR__)
burrowactivate()
import ERA5Analysis as ERA

include("snow_off_single_year.jl")
include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_snotel.jl"))
include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_era.jl"))
eradir = joinpath(ERA.ERA5DATA, "extracted_points")

snometa = CSV.read(joinpath(ERA.NRCSDATA, "cleansed", "SNOTEL_Metadata.csv"), DataFrame)

id_to_data = Dictionary(string.(snometa.ID), collect(eachrow(snometa[:, Not(:ID)])))

for snotel in ERA.special_snotels
    name = id_to_data[snotel].Name
    display((name, snotel))
    eradat = load_era.(eradir, ERA.eratypes, snotel)
    snodat = load_snotel(snotel)
    combodat = outerjoin(snodat, eradat...; on=:datetime)
    #Now group by year and calculate the snow off dates
    datacols = filter!(x->!occursin("time", x), names(combodat))
    data_with_time = [[datacol; "datetime"] for datacol in datacols]
    #Add in the snow bools and a year column to group on
    mistona(x) = if ismissing(x) return NaN else return x end
    with_year = transform!(combodat, datacols.=>(x->mistona.((x.>0) .+ 0)).=>datacols, :datetime=>ByRow(year)=>:year)
    group_year = groupby(with_year, :year)
    snow_off = combine(group_year, (data_with_time.=>((x,y)->snow_off_single_year(x,y;min_snow=30)).=>datacols)...)

    snow_off_data = Array(snow_off[:, datacols])

    years = snow_off.year

    yticks =
    round(minimum(filter(!isnan, snow_off_data))):5:round(
        maximum(filter(!isnan, snow_off_data)),
    )
    yticklabel = Dates.format.((Date(2021) .+ Day.(yticks .- 1)), dateformat"mm/dd")
    myp = plot(
        years,
        snow_off_data;
        label = permutedims(["SNOTEL", "Base", "LAND"]),
        title = "$name SNOTEL (ID: $snotel) vs ERA5 Snow Off, by year",
        xlabel = "Year",
        ylabel = "Basin Mean date of snow off (leap years ignored in switch from day of year to mm/dd)",
        yticks = (yticks, yticklabel),
        legend = :outertopright,
        ylabelfontsize = 6,
        size = 0.5e3 .* (2, 1),
    )

    savefig(myp, "../vis/SNOTEL_$(snotel)_snow_off.png")
end