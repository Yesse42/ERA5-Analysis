using CSV, DataFrames, Dates, Dictionaries, AxisArrays, StatsBase, AxisArrays, JLD2
cd(@__DIR__)
burrowactivate()
import ERA5Analysis as ERA

"""This wondrous function expects a list of stations, and a dict of sttaions to data, which
it will then use to aggregate the data"""
