using Documenter
using SymbolicUtils
using SymbolicRegression
using SymbolicRegression: Dataset, update_baseline_loss!

DocMeta.setdocmeta!(
    SymbolicRegression, :DocTestSetup, :(using LossFunctions); recursive=true
)
DocMeta.setdocmeta!(
    SymbolicRegression, :DocTestSetup, :(using DynamicExpressions); recursive=true
)

readme = open(dirname(@__FILE__) * "/../README.md") do io
    read(io, String)
end

# First, we remove all markdown comments:
readme = replace(readme, r"<!--.*?-->" => s"")

# Then, we remove any line with "<div" on it:
readme = replace(readme, r"<[/]?div.*" => s"")

# We delete the https://github.com/MilesCranmer/SymbolicRegression.jl/assets/7593028/f5b68f1f-9830-497f-a197-6ae332c94ee0,
# and replace it with a video:
readme = replace(
    readme,
    r"https://github.com/MilesCranmer/SymbolicRegression.jl/assets/7593028/f5b68f1f-9830-497f-a197-6ae332c94ee0" =>
        (
            """
            ```@raw html
            <div align="center">
            <video width="800" height="600" controls>
            <source src="https://github.com/MilesCranmer/SymbolicRegression.jl/assets/7593028/f5b68f1f-9830-497f-a197-6ae332c94ee0" type="video/mp4">
            </video>
            </div>
            ```
            """
        ),
)

# We prepend the `<table>` with a ```@raw html
# and append the `</table>` with a ```:
readme = replace(
    readme,
    r"<table>" => s"```@raw html\n<table>",
)
readme = replace(
    readme,
    r"</table>" => s"</table>\n```",
)

# Then, we surround ```mermaid\n...\n``` snippets
# with ```@raw html\n<div class="mermaid">\n...\n</div>```:
readme = replace(
    readme,
    r"```mermaid([^`]*)```" => s"```@raw html\n<div class=\"mermaid\">\n\1\n</div>\n```",
)

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
    doctest=true,
    strict=:doctest,
    clean=true,
    format=Documenter.HTML(;
        canonical="https://astroautomata.com/SymbolicRegression.jl/stable"
    ),
    pages=[
        "Contents" => "index_base.md",
        "Home" => "index.md",
        "Examples" => "examples.md",
        "API" => "api.md",
        "Losses" => "losses.md",
        "Types" => "types.md",
    ],
)

# Next, we fix links in the docs/build/losses/index.html file:
using Gumbo

html_type(::HTMLElement{S}) where {S} = S

function apply_to_a_href!(f!, element::HTMLElement)
    if html_type(element) == :a &&
        haskey(element.attributes, "href") &&
        element.attributes["href"] == "@ref"
        f!(element)
    else
        for child in element.children
            typeof(child) <: HTMLElement && apply_to_a_href!(f!, child)
        end
    end
end

html_content = read("docs/build/losses/index.html", String)
html = parsehtml(html_content)

apply_to_a_href!(html.root) do element
    # Replace the "href" to be equal to the contents of the tag, prefixed with #:
    element.attributes["href"] = "#LossFunctions." * element.children[1].text
end

# Then, we write the new html to the file:
open("docs/build/losses/index.html", "w") do io
    write(io, string(html))
end

deploydocs(; repo="github.com/MilesCranmer/SymbolicRegression.jl.git")
