using Documenter
using SymbolicRegression
using SymbolicRegression: Dataset, update_baseline_loss!

DocMeta.setdocmeta!(SymbolicRegression, :DocTestSetup, :(using LossFunctions); recursive=true)
DocMeta.setdocmeta!(SymbolicRegression, :DocTestSetup, :(using DynamicExpressions); recursive=true)

readme = open(dirname(@__FILE__) * "/../README.md") do io
    read(io, String)
end

# We replace every instance of <img src="IMAGE" ...> with ![](IMAGE).
readme = replace(readme, r"<img src=\"([^\"]+)\"[^>]+>.*" => s"![](\1)")

# Then, we remove any line with "<div" on it:
readme = replace(readme, r"<[/]?div.*" => s"")

# Then, we surround ```mermaid\n...\n``` snippets
# with ```@raw html\n<div class="mermaid">\n...\n</div>```:
readme = replace(readme, r"```mermaid([^`]*)```" => s"```@raw html\n<div class=\"mermaid\">\n\1\n</div>\n```")

# Then, we init mermaid.js:
init_mermaid = """
```@raw html
<script type="module">
  import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@9/dist/mermaid.esm.min.mjs';
  mermaid.initialize({ startOnLoad: true });
</script>
```
"""

readme = init_mermaid * readme

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
