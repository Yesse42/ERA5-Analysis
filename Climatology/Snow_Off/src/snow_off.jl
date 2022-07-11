using CSV, DataFrames, Dates, Dictionaries, JLD2, NCDatasets, StatsBase
cd(@__DIR__)
burrowactivate()
import ERA5Analysis as ERA

include("snow_off_single_year.jl")

function snow_off(sd, times; min_snowy_days_before_snowpack_established)
    nyears = -(year.((times[end], times[begin]))...) + 1
    is_snow = sd .> is_snow_thresh
    dates = Date.(times)
    snowoff_arr = Array{Float64, 3}(undef, (size(sd, 1), size(sd, 2), nyears))
    for i in axes(sd, 1), j in axes(sd, 2)
        if ((i - 1) % 10 == 0) && (j == 1)
            print(i)
        end
        if isnan(sd[i, j, 1])
            snowoff_arr[i, j, :] .= NaN
            continue
        end
        for t_idx in axes(snowoff_arr, 3)
            current_year = year(times[begin]) + t_idx - 1
            current_year_begin = only(searchsorted(dates, Date(current_year)))
            current_year_end = searchsorted(dates, Date(current_year, 12, 31))
            current_year_end = if isempty(current_year_end)
                length(dates)
            else
                only(current_year_end)
            end
            t_idx_range = current_year_begin:current_year_end
            snowoff_arr[i, j, t_idx] = snow_off_single_year(
                @view(is_snow[i, j, t_idx_range]),
                @view(dates[t_idx_range]);
                min_snow = min_snowy_days_before_snowpack_established,
            )
        end
    end
    return snowoff_arr
end

using Plots
pyplot()

for (eratype, erafile) in zip(ERA.eratypes, ERA.erafiles)
    ds = Dataset("$(ERA.ERA5DATA)/$eratype/$erafile", "r")
    sd = ds["sd"][:]
    time = ds["time"][:]
    lon = ds["longitude"][:]
    lat = ds["latitude"][:]

    sd[ismissing.(sd)] .= NaN

    lonlat = tuple.(lon, lat')
    longrid, latgrid = first.(lonlat), last.(lonlat)

    snow_off_arr = snow_off(sd, time; min_snowy_days_before_snowpack_established = 30)

    snow_off_mean = mapslices(x -> mean(filter(!isnan, x)), snow_off_arr; dims = 3)[:, :, 1]

    #Also plot basin averages
    basin_snowoff_year = []
    for basin in ERA.basin_names
        basinidxdir = joinpath(ERA.ERA5DATA, "basin_extractions", eratype)
        basin_idx_df = CSV.read(joinpath(basinidxdir, "$(basin)_era_points.csv"), DataFrame)
        basin_idxs = CartesianIndex.(basin_idx_df.lonidx, basin_idx_df.latidx)
        basin_timeseries = snow_off_arr[basin_idxs, :]
        basin_mean_snowoff =
            vec(mapslices((x -> mean(filter(!isnan, x))), basin_timeseries; dims = (1,)))
        push!(basin_snowoff_year, basin_mean_snowoff)
    end
    years = year(time[begin]):year(time[end])
    basin_snowoff = reduce(hcat, basin_snowoff_year)
    yticks =
        round(minimum(filter(!isnan, basin_snowoff))):5:round(
            maximum(filter(!isnan, basin_snowoff)),
        )
    yticklabel = Dates.format.((Date(2020) .+ Day.(yticks .- 1)), dateformat"mm/dd")
    myp = plot(
        years,
        basin_snowoff;
        label = permutedims(ERA.basin_names),
        title = "ERA5-$eratype Snow Off By Year/Basin",
        xlabel = "Year",
        ylabel = "Basin Mean date of snow off (conversion from day of year to mm/dd ignores leap years, stations with no snow or permanent snow ignored)",
        yticks = (yticks, yticklabel),
        legend = :outertopright,
        ylabelfontsize = 5,
        size = 0.5e3 .* (2, 1),
    )

    savefig(myp, "../vis/$(eratype)_basin_snow_off.png")
end
