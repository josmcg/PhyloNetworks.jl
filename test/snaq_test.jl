push!(LOAD_PATH, realpath("../src"))
addprocs(4)
using PhyloNetworks
using Base.Test
using DataFrames
include("test_bootstrap.jl")

