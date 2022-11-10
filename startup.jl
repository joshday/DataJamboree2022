using Pkg
Pkg.activate(@__DIR__)

using Pluto

Pluto.run(notebook=joinpath(@__DIR__, "notebook.jl"))
