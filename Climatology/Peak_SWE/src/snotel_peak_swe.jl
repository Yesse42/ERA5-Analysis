#This needs to take into account when the snotels are coming online

using CSV, DataFrames, Dates, Dictionaries, JLD2, NCDatasets, StatsBase, Plots
cd(@__DIR__)
burrowactivate()
import ERA5Analysis as ERA

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
    #Add in the snow bools and a year column to group on
    with_year = transform!(combodat, :datetime=>ByRow(year)=>:year)
    group_year = groupby(with_year, :year)
    naormiss(x) = ismissing(x) || isnan(x)
    myskipmiss_na(x) = if all(naormiss.(x)) return [NaN] else return Base.Iterators.filter(!naormiss, x) end
    max_swe = combine(group_year, (datacols.=>(x->maximum(myskipmiss_na(x))).=>datacols)...)

    max_swe_data = Array(max_swe[:, datacols])

    years = max_swe.year
    myp = plot(
        years,
        max_swe_data;
        label = permutedims(["SNOTEL", "Base", "LAND"]),
        title = "$name SNOTEL (ID: $snotel) vs ERA5 Peak SWE",
        xlabel = "Year",
        ylabel = "Peak SWE (mm)",
        legend = :outertopright,
        ylabelfontsize = 6,
        size = 0.5e3 .* (2, 1),
    )

    savefig(myp, "../vis/SNOTEL_$(snotel)_peak_swe.png")
end