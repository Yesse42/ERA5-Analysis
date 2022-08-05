using Dates
const startmonth, startday = 9, 1

function water_year(time; startmonth = startmonth, startday = startday)
    raw_year = year(time)
    raw_month, raw_day = month(time), day(time)
    if Date(raw_year, raw_month, raw_day) < Date(raw_year, startmonth, startday)
        raw_year = raw_year - 1
    end
    return raw_year
end

function round_water_year(time::T; startmonth = startmonth, startday=startday) where T
    raw_year = year(time)
    raw_month, raw_day = month(time), day(time)
    if Date(raw_year, raw_month, raw_day) < Date(raw_year, startmonth, startday)
        raw_year = raw_year - 1
    end
    return T(Date(raw_year, startmonth, startday))
end

function day_of_water_year(time; startmonth = startmonth, startday = startday)
    return ((time - round_water_year(time; startmonth, startday)) ÷ Day(1)) + 1
end
