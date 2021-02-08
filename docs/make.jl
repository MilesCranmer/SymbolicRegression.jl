using Documenter, SymbolicRegression
using SymbolicRegression: Node, PopMember, Population, evalTreeArray, Dataset, HallOfFame, CONST_TYPE, stringTree

makedocs(sitename="SymbolicRegression.jl",
         authors="Miles Cranmer",
         doctest=false, clean=true)

deploydocs(repo="github.com/MilesCranmer/SymbolicRegression.jl.git")
