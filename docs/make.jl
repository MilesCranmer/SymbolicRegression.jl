using Documenter, SymbolicRegression
using SymbolicRegression: Node, PopMember, Population, evalTreeArray, Dataset, HallOfFame, CONST_TYPE, stringTree

makedocs(sitename="SymbolicRegression.jl",
         authors="Miles Cranmer",
         doctest=false, clean=true,
         format=Documenter.HTML(canonical="https://milescranmer.github.io/SymbolicRegression.jl/stable")
         )

deploydocs(repo="github.com/MilesCranmer/SymbolicRegression.jl.git")
