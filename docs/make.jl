using Documenter, SymbolicRegression
using SymbolicRegression:
    Node, PopMember, Population, eval_tree_array, Dataset, HallOfFame, string_tree

readme = open(dirname(@__FILE__) * "/../README.md") do io
    read(io, String)
end

# First, we want to delete from "# Code structure" to before "## Search options".
readme = let
    i = findfirst("# Code structure", readme)[begin]
    j = findfirst("## Search options", readme)[begin] - 1
    readme[1:(i - 1)] * readme[j:end]
end

# Then, we replace every instance of <img src="IMAGE" ...> with ![](IMAGE).
readme = replace(readme, r"<img src=\"([^\"]+)\"[^>]+>.*" => s"![](\1)")

# Then, we remove any line with "<div" on it:
readme = replace(readme, r"<[/]?div.*" => s"")

# Finally, we read in file docs/src/index_base.md:
index_base = open(dirname(@__FILE__) * "/src/index_base.md") do io
    read(io, String)
end

# And then we create "/src/index.md":
open(dirname(@__FILE__) * "/src/index.md", "w") do io
    write(io, readme)
    write(io, "\n")
    write(io, index_base)
end

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
