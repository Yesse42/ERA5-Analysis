include(joinpath(@__DIR__, "../comparison_constants.jl"))
using Missings
load_snow_course = let
    snow_course_data =
        CSV.read(joinpath(ERA.NRCSDATA, "cleansed", "Snow_Course_Data.csv"), DataFrame)

    courses = names(snow_course_data)

    function load_snow_course(id)
        cols = ["datetime_$id", "SWE_$id"]
        cols[2] ∉ courses && return missing
        outdata = rename(snow_course_data[:, cols], ["datetime", "snow_course_swe"])
        outdata = dropmissing(outdata)
        return transform!(outdata, :datetime => ByRow(Date) => :datetime, :snow_course_swe=>ByRow(passmissing(x->(Float64(x * ERA.mm_to_inch))))=>:snow_course_swe)
    end
end
