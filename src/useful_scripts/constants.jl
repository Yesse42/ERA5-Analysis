chena_basin_ids = ["19080306"]
copper_ids = ["190201", "1908030403"]
kenai_ids = ["190203"]
southeast_ids = ["190705"]
northern_ids = ["19090101", "19090102", "19090104"]
western_ids = ["190903"]
norton_coast = ["190501"]
lynn_canal = ["190103", "19010206"]
const allowed_hucs = [
    chena_basin_ids,
    copper_ids,
    kenai_ids,
    southeast_ids,
    northern_ids,
    western_ids,
    norton_coast,
    lynn_canal,
]
const basin_names = [
    "Chena",
    "Copper",
    "Kenai",
    "Eastern Interior",
    "Northern Interior",
    "Lower Yukon",
    "Norton Sound",
    "Lynn Canal",
]

const usable_basins = [
    "Chena",
    "Copper",
    "Kenai",
    "Eastern Interior",
    "Northern Interior",
    "Lower Yukon",
    "Lynn Canal",
]
const meter_to_inch = 39.3701
const mm_to_inch = 0.0393701

const hucsizes = [6,8,10]

ak_bounds = [-171, -129, 50, 72]
eratypes = ["Base", "Land"]
networktypes = ["SNOTEL", "Snow_Course"]
erafiles =
    ["ERA5-SD-1979-2022-CREATE-2022-06-16.nc", "ERA5-Land-SD-1979-2022-DL-2022-6-15.nc"]

foldtypes = ["Every 3rd year", "3 periods"]

special_snotels = string.([954, 949, 1189, 1182, 1096])

na_or_miss(x) = ismissing(x) || isnan(x)
not_na_or_miss(x) = (!)(na_or_miss(x))
skipnaormiss(x) = Iterators.filter(not_na_or_miss, x)
Base.length(x::Base.Iterators.Filter{typeof(not_na_or_miss), T}) where T = count(not_na_or_miss, x)
