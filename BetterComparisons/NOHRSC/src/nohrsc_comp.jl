burrowactivate()
cd(@__DIR__)
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2, Dates

include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_nohrsc.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "omniplot.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "comparison_machinery.jl"))

used_basins = []
land_pom_rmsd = []
base_pom_rmsd = []
climo_pom_rmsd = []
for basin in ERA.basin_names
    eradata = DataFrame[]

    for eratype in ERA.eratypes
        basin_to_flines =
            jldopen(joinpath(ERA.NOHRSCDATA, "$(eratype)_basin_to_flines.jld2"))["basin_to_flines"]

        flines = basin_to_flines[basin]
        basinmean = general_station_compare(
            eratype,
            flines;
            load_data_func = load_nohrsc_only,
            load_era_func = load_nohrsc_era,
            comparecolnames = [:mean_era_swe, :gamma],
            timecol = "datetime",
            groupfunc = month,
            median_group_func = month,
        )
        ismissing(basinmean) && continue
        push!(eradata, basinmean.basindata)
    end
    isempty(eradata) && continue

    #Now plot the difference in percent of median and the anomaly difference on separate axes,
    #for both era5 land and base
    #Filter for april
    eradata = [filter(x -> x.datetime == 4, d) for d in eradata]
    #Now get the percent of median and anomaly diff
    push!(land_pom_rmsd, only(eradata[2].normed_anomaly_diff_rmsd))
    push!(base_pom_rmsd, only(eradata[1].normed_anomaly_diff_rmsd))
    push!(climo_pom_rmsd, only(eradata[1].gamma_normed_anom_climo_diff_rmsd))
    push!(used_basins, basin)
end

#Now barplot land vs base and land vs climatology

omnidata = reduce(vcat, permutedims.((land_pom_rmsd, climo_pom_rmsd, base_pom_rmsd)))
xvals = reshape(collect(eachindex(omnidata)), size(omnidata)) .+ (1:size(omnidata, 2))'
cvec = [:purple, :orange, :blue]
fillcolors = reduce(hcat, (cvec for i in Base.axes(omnidata, 2)))
xticks = xvals[2:3:end]
xticklabels = used_basins

p = bar(
    vec(xvals),
    vec(omnidata);
    fillcolor = vec(fillcolors),
    legend = :topright,
    label = "",
    xticks = (xticks, xticklabels),
    rotation = 45,
)
plot!(
    p;
    title = "NOHRSC April Normed Anomaly RMSD",
    ylabel = "Normed Anomaly Diff RMSD (unitless)",
    xlabel = "Basin",
)
bar(
    p,
    (1:3)',
    [NaN, NaN, NaN]';
    show_axis = false,
    label = ["ERA5 Land" "Station Climatology" "ERA5 Base"],
    fillcolor = permutedims(cvec),
)
