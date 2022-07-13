chena_basin_ids = ["19080306"]
copper_ids = ["190201"]
kenai_ids = ["190203"]
southeast_ids = ["190705"]
remote_ids = ["19090101"]
western_ids = ["190903"]
norton_coast = ["190501"]
lynn_canal = ["190103"]
const allowed_hucs = [
    chena_basin_ids,
    copper_ids,
    kenai_ids,
    southeast_ids,
    remote_ids,
    western_ids,
    norton_coast,
    lynn_canal,
]
const basin_names = [
    "Chena",
    "Copper",
    "Kenai",
    "Southeast Interior",
    "Northern Interior",
    "Western Interior",
    "Norton Sound",
    "Lynn Canal",
]
const meters_to_inch = 39.3701

ak_bounds = [-171, -129, 50, 72]
eratypes = ["Base", "Land"]
networktypes = ["SNOTEL", "Snow_Course"]
erafiles =
    ["ERA5-SD-1979-2022-CREATE-2022-06-16.nc", "ERA5-Land-SD-1979-2022-DL-2022-6-15.nc"]

special_snotels = string.([954, 949, 1189, 1182, 1096])
