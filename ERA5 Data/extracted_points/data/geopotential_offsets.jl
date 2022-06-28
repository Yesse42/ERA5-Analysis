#=As can be seen by inspecting the era land and base geopotential indices compared to the snow depth indices, 
one can see that there is a constant offset between them, which is expected as both are regular latlon grids, just with
different starting and ending bounds. I was just too lazy to find the offsets and opted for brute force because why not
This document contains the offsets=#
(base_offsets = CartesianIndex(0,0), land_offsets = CartesianIndex(185, 1919))