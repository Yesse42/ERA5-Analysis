include(joinpath(@__DIR__, "../comparison_constants.jl"))

const snow_course_data = CSV.read(joinpath(ERA.NRCSDATA, "cleansed", "Snow_Course_Data.csv"), DataFrame)

function load_snow_course(id)
    cols = ["datetime", "SWE_$id"]
    outdata = rename(snow_course_data[:, cols], ["datetime", "snow_course_swe"])
    transform!(outdata, :datetime=>ByRow(Date)=>:datetime)
end