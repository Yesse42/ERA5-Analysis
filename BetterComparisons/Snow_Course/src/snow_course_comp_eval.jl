burrowactivate()
cd(@__DIR__)
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2

include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_era.jl"))
include("snow_course_comp_func.jl")

include("land_vs_base_func.jl")
include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_era.jl"))

load_k_fold_func = let
    kfolddatadir = joinpath(ERA.ERA5DATA, "better_extracted_points", "k-fold_data")

    #Useful preloading
    datadict = nothing
    for foldtype in ERA.foldtypes, eratype in ERA.eratypes
        stationtodata =
            jldopen(joinpath(kfolddatadir, foldtype, eratype, "eradata.jld2"))["station_to_data"]
        stationtodata = map(stationtodata) do datatup
            df = DataFrame(datatup; copycols = false)
            select!(
                df,
                :time => ByRow(Date) => :datetime,
                :sd => ByRow(x -> x .* 1e3) => :era_swe,
            )
            return sort!(df, :datetime)
        end

        if isnothing(datadict)
            datadict = Dictionary([(foldtype, eratype)], [stationtodata])
        else
            insert!(datadict, (foldtype, eratype), stationtodata)
        end
    end

    load_k_fold_func(foldtype) = function load_era_k_fold(_, eratype, id)
        stationtodata = datadict[(foldtype, eratype)]
        return get(stationtodata, string(id), missing)
    end
end

savedirs = "../vis/" .* [ "cheater", joinpath.("k-fold", ERA.foldtypes)..., "plain_nn"]


load_cheater(_, eratype, id) =
    load_era(joinpath(ERA.ERA5DATA, "better_extracted_points", "cheater_data"), eratype, id)

loadfuncs =
    [load_cheater, [load_k_fold_func(type) for type in ERA.foldtypes]..., load_plain_nn]

for (dir, func) in zip(savedirs, loadfuncs)
    mkpath(dir)
    omni_args = (;
        savedir = dir,
    )
    snow_course_comp_lineplot(;
        era_load_func = func,
        omniplot_args = omni_args,
    )
end
