using Documenter, SymbolicRegression
using SymbolicRegression:
    Node,
    PopMember,
    Population,
    eval_tree_array,
    Dataset,
    HallOfFame,
    CONST_TYPE,
    string_tree

makedocs(;
    sitename="SymbolicRegression.jl",
    authors="Miles Cranmer",
    doctest=false,
    clean=true,
    format=Documenter.HTML(;
        canonical="https://astroautomata.com/SymbolicRegression.jl/stable"
    ),
)

deploydocs(; repo="github.com/MilesCranmer/SymbolicRegression.jl.git")
