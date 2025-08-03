using Documenter
using DocumenterVitepress
using SymbolicUtils
using SymbolicRegression
using SymbolicRegression:
    AbstractExpression,
    ExpressionInterface,
    Dataset,
    update_baseline_loss!,
    AbstractMutationWeights,
    AbstractOptions,
    mutate!,
    condition_mutation_weights!,
    sample_mutation,
    MutationResult,
    AbstractRuntimeOptions,
    AbstractSearchState,
    @extend_operators
using DynamicExpressions

include("utils.jl")
process_literate_blocks("test")
process_literate_blocks("examples")

# Define the proper YAML frontmatter for VitePress
proper_yaml = """---
layout: home

hero:
  name: SymbolicRegression.jl
  text: Discover Mathematical Laws from Data
  tagline: A flexible, user-friendly framework that automatically finds interpretable equations from your data
  actions:
    - theme: brand
      text: Get Started
      link: #quickstart
    - theme: alt
      text: API Reference 📚
      link: /api
    - theme: alt
      text: View on GitHub
      link: https://github.com/MilesCranmer/SymbolicRegression.jl
  image:
    src: /assets/logo.svg
    alt: SymbolicRegression.jl

features:
  - icon: 🔍
    title: Interpretable by Design
    details: Automatically discovers human-readable mathematical expressions, not black-box models.

  - icon: ⚡
    title: Production Ready
    details: Years of engineering and optimization deliver high-performance distributed search.

  - icon: 🛠️
    title: Customizable
    details: Build exactly what you need with custom types, operators, loss functions, templates, and more.
    link: /customization

  - icon: ⚙️
    title: Easy Integration
    details: Seamlessly integrates with the Julia ecosystem.
    link: #mlj-interface

  - icon: 💡
    title: For Scientists
    details: Proven with real scientific discoveries from astrophysics to economics.

  - icon: 🔬
    title: For SR Researchers
    details: Designed to support the community as a "PyTorch" for symbolic regression.
---
"""

# Post-process VitePress output to fix YAML frontmatter and HTML escaping
function post_process_vitepress_index()
    index_path = joinpath(@__DIR__, "build", "index.md")

    if !isfile(index_path)
        @error "Index file not found: $index_path"
        return false
    end

    content = read(index_path, String)

    # Check if YAML frontmatter has been corrupted by DocumenterVitepress.jl
    if occursin(r"hero:\s*name:", content)
        # Replace the corrupted frontmatter with proper VitePress home layout (defined globally above)

        # Replace everything from the start up to the first "## Example:" with our proper YAML
        content = replace(content, r"^.*?(?=## Example:)"s => proper_yaml)
    end

    # Fix HTML escaping - unescape HTML entities
    content = replace(content, "&lt;" => "<")
    content = replace(content, "&gt;" => ">")
    content = replace(content, "&quot;" => "\"")
    content = replace(content, "&#39;" => "'")
    content = replace(content, "&amp;" => "&")

    write(index_path, content)
    @info "Successfully post-processed VitePress index.md - fixed YAML frontmatter and HTML escaping"
    return true
end

readme = open(dirname(@__FILE__) * "/../README.md") do io
    read(io, String)
end

# VitePress frontmatter for beautiful home page
vitepress_frontmatter = proper_yaml * """
## Example: Rediscovering Physical Laws

SymbolicRegression.jl can automatically discover mathematical expressions from data:

"""

# Process README for VitePress
readme = replace(readme, r"<!--.*?-->" => s"") # Remove markdown comments
readme = replace(readme, r"<[/]?div.*" => s"") # Remove div tags
readme = replace( # Convert video URL to proper video tag
    readme,
    r"https://github.com/MilesCranmer/SymbolicRegression.jl/assets/7593028/f5b68f1f-9830-497f-a197-6ae332c94ee0" => """<div align="center">
                                                                                                            <video width="800" height="600" controls>
                                                                                                            <source src="https://github.com/MilesCranmer/SymbolicRegression.jl/assets/7593028/f5b68f1f-9830-497f-a197-6ae332c94ee0" type="video/mp4">
                                                                                                            </video>
                                                                                                            </div>""",
)
readme = replace( # Convert mermaid blocks for VitePress
    readme,
    r"```mermaid([^`]*)```" => s"```@raw html\n<div class=\"mermaid\">\n\1\n</div>\n```",
)

# Add mermaid.js initialization and VitePress frontmatter
init_mermaid = """<script type="module">
  import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@9/dist/mermaid.esm.min.mjs';
  mermaid.initialize({ startOnLoad: true });
</script>
"""
readme = vitepress_frontmatter * init_mermaid * readme

# Read base content
index_base = open(dirname(@__FILE__) * "/src/index_base.md") do io
    read(io, String)
end

# Create index.md with VitePress frontmatter and content
open(dirname(@__FILE__) * "/src/index.md", "w") do io
    write(io, readme)
    write(io, "\n")
    write(io, index_base)
end

deploy_config = Documenter.auto_detect_deploy_system()
deploy_decision = Documenter.deploy_folder(
    deploy_config;
    repo="github.com/MilesCranmer/SymbolicRegression.jl",
    devbranch="master",
    devurl="dev",
    push_preview=true,
)

DocMeta.setdocmeta!(
    SymbolicRegression,
    :DocTestSetup,
    :(using LossFunctions, DynamicExpressions);
    recursive=true,
)

makedocs(;
    sitename="SymbolicRegression.jl",
    authors="Miles Cranmer",
    doctest=true,
    clean=get(ENV, "DOCUMENTER_PRODUCTION", "false") == "true",
    warnonly=[:docs_block, :cross_references, :missing_docs],
    format=DocumenterVitepress.MarkdownVitepress(;
        repo="github.com/MilesCranmer/SymbolicRegression.jl",
        devbranch="master",
        devurl="dev",
        deploy_decision,
        build_vitepress=get(ENV, "DOCUMENTER_PRODUCTION", "false") == "true",
        md_output_path=if get(ENV, "DOCUMENTER_PRODUCTION", "false") == "true"
            ".documenter"
        else
            "."
        end,
    ),
    pages=[
        "Contents" => "index_base.md",
        "Home" => "index.md",
        "Examples" => [
            "Short Examples" => "examples.md",
            "Template Expressions" => "examples/template_expression.md",
            "Parameterized Expressions" => "examples/parameterized_function.md",
            "Parameterized Template Expressions" => "examples/template_parametric_expression.md",
            "Custom Types" => "examples/custom_types.md",
            "Using SymbolicRegression.jl on a Cluster" => "slurm.md",
        ],
        "API" => "api.md",
        "Losses" => "losses.md",
        "Types" => "types.md",
        "Customization" => "customization.md",
    ],
)

# Run post-processing to fix HTML escaping
post_process_vitepress_index()

DocumenterVitepress.deploydocs(;
    repo="github.com/MilesCranmer/SymbolicRegression.jl.git",
    push_preview=true,
    target="build",
    devbranch="master",
)

ENV["DOCUMENTER_KEY"] = get(ENV, "DOCUMENTER_KEY_CAM", "")
ENV["GITHUB_REPOSITORY"] = "ai-damtp-cam-ac-uk/symbolicregression.git"
DocumenterVitepress.deploydocs(;
    repo="github.com/ai-damtp-cam-ac-uk/symbolicregression.git",
    push_preview=true,
    target="build",
    devbranch="master",
)
