using CSV, DataFrames, Dates, Dictionaries, JLD2, NCDatasets, StatsBase
cd(@__DIR__)
burrowactivate()
import ERA5Analysis as ERA

"""Takes a time series of SWE from Jan-1 to Dec-31, the associated dates and the minimum
number of consecutive days with snow necessary for snowpack to be considered 'established'"""
function single_year_single_point_snow_off(sd, dates; min_snow)
    if ismissing(sd[begin])
        return NaN
    end

    has_snow = sd .> 0

    possible_snow_off_idxs = findall(==(-1), has_snow[2:end] .- has_snow[1:(end - 1)])

    #Snow conditions never change from Snowy to No Snow
    if isempty(possible_snow_off_idxs)
        #Always snowy
        if has_snow[begin] == true
            return NaN
        else
            #Never snowy
            return NaN
        end
    end

    #Now iterate through; they are ordered from first to last so we just need to check if a snowpack is
    #established in accordance with min_snowy_days_before_snowpack_established
    current_idx = nothing
    for idx in possible_snow_off_idxs
        #If there aren't enough preceding days to establish snowiness then skip
        idx <= min_snow && continue
        #Otherwise check the previos min_snowy_days are all snow
        if all(has_snow[(idx - min_snow):(idx - 1)])
            current_idx = idx
        end
    end

    #Looks like a snowpack never managed to establish if current_idx is still nothing
    if current_idx ≡ nothing
        return NaN
    else
        return dayofyear(dates[current_idx])
    end
end

"Assumes the times begin Jan 1st of the 1st year"
function year_snow_off(sd, times; min_snowy_days_before_snowpack_established)
    dates = Date.(times)
    max_idx = length(dates)

    minyear, maxyear = year.((dates[begin], dates[end]))

    snowoff = zeros(Float64, size(sd, 1), size(sd, 2), maxyear - minyear + 1)

    #Now loop through each year
    current_idx = 1
    for (t_idx, this_year) in enumerate(minyear:1:maxyear)
        daysofyear = Date(this_year):Day(1):Date(this_year, 12, 31)
        ndays = length(daysofyear)
        #Logic to handle the end of the time period
        if current_idx + ndays - 1 > max_idx
            daysofyear =
                Date(this_year):Day(1):(Date(this_year) + Day(max_idx - current_idx))
            ndays = length(daysofyear)
        end
        this_year_sds = @view sd[:, :, current_idx:(current_idx + ndays - 1)]
        for i in 1:size(sd, 1), j in 1:size(sd, 2)
            snowoff[i, j, t_idx] = single_year_single_point_snow_off(
                @view(this_year_sds[i, j, :]),
                daysofyear;
                min_snow = min_snowy_days_before_snowpack_established,
            )
        end
        current_idx += ndays
    end
    return snowoff
end

using PyCall
@pyimport matplotlib.pyplot as plt
@pyimport cartopy.crs as ccrs
@pyimport mpl_toolkits.axes_grid1 as mplg1
make_axes_locatable = mplg1.make_axes_locatable

for (eratype, erafile) in zip(ERA.eratypes, ERA.erafiles)
    ds = Dataset("$(ERA.ERA5DATA)/$eratype/$erafile", "r")
    sd = ds["sd"][:]
    time = ds["time"][:]
    lon = ds["longitude"][:]
    lat = ds["latitude"][:]

    lonlat = tuple.(lon, lat')
    longrid, latgrid = first.(lonlat), last.(lonlat)

    snow_off = year_snow_off(sd, time; min_snowy_days_before_snowpack_established = 30)

    snow_off_mean = mapslices(x -> mean(filter(!isnan, x)), snow_off; dims = 3)[:, :, 1]

    display(snow_off_mean)

    #Now plot it
    fig = plt.figure(; figsize = (10, 10))
    ax = plt.subplot(
        1,
        1,
        1;
        projection = ccrs.Gnomonic(; central_longitude = -147, central_latitude = 65),
    )
    #ccrs.AlbersEqualArea(central_longitude = -150,standard_parallels = (57,69))
    fig.add_axes(ax)

    cfplot = ax.contourf(
        longrid,
        latgrid,
        snow_off_mean;
        transform = ccrs.PlateCarree(),
        levels = 20,
        cmap = "cividis_r",
    )
    cont = ax.contour(
        longrid,
        latgrid,
        snow_off_mean;
        transform = ccrs.PlateCarree(),
        levels = 10,
        colors = "pink",
        linewidths = 0.5,
    )

    fmt(value) = "$(round(value))"

    ax.clabel(cont, cont.levels; inline = true, fmt = fmt, colors = "black", fontsize = 6)

    plt.colorbar(
        cfplot;
        shrink = 0.7,
        ticks = 0:15:360,
        label = "Mean Day of year at which \"snow is off\"",
    )

    ax.set_extent(ERA.ak_bounds; crs = ccrs.PlateCarree())
    ax.gridlines()
    ax.coastlines()
    ax.set_title(
        "ERA5-$eratype Mean (1979-2021) Snow off date, snowpack considered established after 30 days";
        fontsize = 12,
    )
    plt.savefig("$eratype mean_snow_off_date.png")
end
