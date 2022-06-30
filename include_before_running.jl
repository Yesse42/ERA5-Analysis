#You must include this package into your current julia session for anything here to run
#I personally put this in my startup.julia
using Pkg
function burrowactivate(projectname=nothing)
    currentdir = pwd()
    try
        while !(isfile("Project.toml") && (pwd() == projectname || isnothing(projectname)))
            cd("..")
        end
    catch e
        error("Project with given name not found")
    end
    Pkg.activate(".")
    cd(currentdir)
end