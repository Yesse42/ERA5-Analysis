include(joinpath(@__DIR__, "../comparison_constants.jl"))

using Missings

load_snotel = let
    snotel_data = CSV.read(joinpath(ERA.NRCSDATA, "cleansed", "SNOTEL_Data.csv"), DataFrame)

    function load_snotel(id)
        cols = ["datetime", "SWE_$id"]
        outdata = rename(snotel_data[:, cols], ["datetime", "snotel_swe"])
        dropmissing!(outdata)
        return transform!(
            outdata,
            :datetime => ByRow(Date) => :datetime,
            :snotel_swe =>
                ByRow(passmissing(x -> (Float64(x .* ERA.mm_to_inch)))) => :snotel_swe,
        )
    end
end
