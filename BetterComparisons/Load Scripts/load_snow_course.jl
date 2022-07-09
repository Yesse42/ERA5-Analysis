include(joinpath(@__DIR__, "../comparison_constants.jl"))

const snow_course_data =
    CSV.read(joinpath(ERA.NRCSDATA, "cleansed", "Snow_Course_Data.csv"), DataFrame)

function load_snow_course(id)
    cols = ["datetime", "SWE_$id"]
    cols[2] ∉ names(snow_course_data) && return missing
    outdata = rename(snow_course_data[:, cols], ["datetime", "snow_course_swe"])
    return transform!(outdata, :datetime => ByRow(Date) => :datetime)
end
