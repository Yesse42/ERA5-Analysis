cd(@__DIR__)
burrowactivate()
import ERA5Analysis as ERA
using PyCall, Dictionaries, CSV, DataFrames, NCDatasets, JLD2, StaticArrays
@pyimport matplotlib.pyplot as plt
@pyimport matplotlib.patches as mpatches
@pyimport cartopy.crs as ccrs
@pyimport numpy as np
@pyimport matplotlib.colors as colors

function isglacier(era_sd; glacier_thresh = 0.95)
    era_sd[ismissing.(era_sd)] .= NaN

    return ((sum(era_sd .> 0; dims = 3) ./ size(era_sd, 3)) .>= glacier_thresh) .|
           ismissing.(era_sd[:, :, 1])
end

point_data_dir = "../../plain_nn"

basin_to_polys = jldopen(joinpath(ERA.BASINDATA, "basin_to_polys.jld2"))["basin_to_polys"]
basin_to_snotel =
    jldopen(joinpath(ERA.NRCSDATA, "cleansed", "SNOTEL_basin_to_id.jld2"))["basin_to_id"]
basin_to_snow_course =
    jldopen(joinpath(ERA.NRCSDATA, "cleansed", "Snow_Course_basin_to_id.jld2"))["basin_to_id"]
station_meta = CSV.read(joinpath(ERA.NRCSDATA, "cleansed", "Metadata.csv"), DataFrame)

stationtype_ids = (basin_to_snotel, basin_to_snow_course)

for (eratype, erafile) in zip(ERA.eratypes, ERA.erafiles)
    era_chosen_points = CSV.read("$point_data_dir/$(eratype)_best_ids.csv", DataFrame)

    era_data = Dataset("../../elevation_data/$(eratype)_aligned_elevations.nc")
    elev = era_data["elevation_m"][:]
    lon = era_data["longitude"]
    lat = era_data["latitude"]

    sd = Dataset(joinpath(ERA.ERA5DATA, eratype, erafile))["sd"][:]
    glacmask = isglacier(sd)[:, :, 1]

    elev[glacmask] .= NaN

    longrid = lon .* ones(length(lat))'
    latgrid = ones(length(lon)) .* lat'
    for basin in ERA.basin_names
        fig = plt.figure()
        goodproj =
            ccrs.AlbersEqualArea(; central_longitude = -147, standard_parallels = (57, 69))

        ax = fig.add_subplot(1, 1, 1; projection = goodproj)

        #Get the basin boundaries and plot them
        polys = basin_to_polys[basin]
        for poly in polys
            poly = reduce(vcat, collect.(transpose.(poly)))
            poly_plot = mpatches.Polygon(
                poly;
                closed = true,
                alpha = 0.5,
                facecolor = "grey",
                edgecolor = "salmon",
                linewidth = 2.0,
                transform = ccrs.PlateCarree(),
            )
            ax.add_patch(poly_plot)
        end

        extrema_of_extrema(extremas) =
            (minimum(e[1] for e in extremas), maximum(e[2] for e in extremas))

        #Now get the bounding box 
        basinids = string.(vcat(getindex.(stationtype_ids, basin)...))
        era_subset = filter(x -> string(x.id) in basinids, era_chosen_points)
        eralonbounds, eralatbounds = extrema(getindex.(Ref(lon), era_subset.lonidx)),
        extrema(getindex.(Ref(lat), era_subset.latidx))
        station_subset = filter(x -> string(x.ID) in basinids, station_meta)
        statlonbounds, statlatbounds =
            extrema(station_subset.Longitude), extrema(station_subset.Latitude)
        lonbounds = extrema_of_extrema((eralonbounds, statlonbounds))
        latbounds = extrema_of_extrema((eralatbounds, statlatbounds))

        buff = 0.25 .* (-1, 1)
        lonbounds = lonbounds .+ 3 .* buff
        latbounds = latbounds .+ buff
        plotbounds = [lonbounds..., latbounds...]
        #Add another buffer
        buff = 2 .* buff
        lonbounds = lonbounds .+ buff
        latbounds = latbounds .+ 3 .* buff
        ax.set_extent(plotbounds; crs = ccrs.PlateCarree())
        ax.gridlines()
        ax.coastlines()

        #Now get the indices of ERA5's elevation to plot
        between(tup) = f(x) = tup[1] <= x <= tup[2]
        era_lonids, era_latids = [
            findall(between(tup), arr) for
            (tup, arr) in zip((lonbounds, latbounds), (lon, lat))
        ]
        plotmask = CartesianIndex.(era_lonids, permutedims(era_latids))

        #Now contour in the elevation

        #Adapted from https://matplotlib.org/stable/tutorials/colors/colormapnorms.html#sphx-glr-tutorials-colors-colormapnorms-py
        colors_undersea = plt.cm.terrain(np.linspace(0, 0.17, 256))
        colors_land = plt.cm.terrain(np.linspace(0.25, 2, 256))
        all_colors = np.vstack((colors_undersea, colors_land))
        terrain_map = colors.LinearSegmentedColormap.from_list("terrain_map", all_colors)

        # make the norm:  Note the center is offset so that the land has more
        # dynamic range:
        divnorm = colors.TwoSlopeNorm(; vmin = -4000.0, vcenter = 0.0, vmax = 4000.0)

        pcm = ax.pcolormesh(
            longrid[plotmask],
            latgrid[plotmask],
            elev[plotmask];
            norm = divnorm,
            cmap = terrain_map,
            shading = "auto",
            transform = ccrs.PlateCarree(),
            zorder = 0,
        )

        # Simple geographic plot, set aspect ratio beecause distance between lines of
        # longitude depends on latitude.
        ax.set_title("$basin Selected Stations, ERA5 $eratype")
        cb = fig.colorbar(pcm; shrink = 0.6, label = "ERA5 Elevation (m)")

        #Now loop througn snow course and snotel, and plot the true locations, and draw an arrow to the chosen era point
        mycolors = ["crimson", "mediumpurple"]
        for (id_dict, mycolor) in zip(stationtype_ids, mycolors)
            ids = id_dict[basin]
            for id in ids
                id_idx = findfirst(==(id), station_meta.ID)
                isnothing(id_idx) && continue
                id_data = station_meta[id_idx, :]
                era_id_idx = findfirst(==(id), era_chosen_points.id)
                isnothing(era_id_idx) && continue
                era_id_data = era_chosen_points[era_id_idx, :]
                #Plot point, label with ID and Elevation
                stat_point = (id_data.Longitude, id_data.Latitude)
                arr(x) = [x]
                ax.scatter(
                    arr.(stat_point)...;
                    transform = ccrs.PlateCarree(),
                    color = mycolor,
                    s = 30,
                    alpha = 0.7,
                )
                arrow_offset =
                    (lon[era_id_data.lonidx], lat[era_id_data.latidx]) .- stat_point
                ax.scatter(
                    arr.(arrow_offset .+ stat_point)...;
                    transform = ccrs.PlateCarree(),
                    color = "orange",
                    s = 20,
                    alpha = 0.7,
                )
                #Draw arrow to ERA point
                ax.arrow(
                    stat_point...,
                    arrow_offset...;
                    transform = ccrs.PlateCarree(),
                    linewidth = 1,
                    alpha = 0.7,
                )
            end
        end
        plt.savefig("../../vis/basin_vis/$eratype/$(basin).png"; dpi = 1200)
        plt.close()
    end
end
