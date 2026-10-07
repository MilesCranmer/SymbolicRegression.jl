using Documenter
using DocumenterVitepress
using SymbolicUtils
using SymbolicRegression
using SymbolicRegression:
    AbstractExpression,
    ExpressionInterface,
    Dataset,
    update_baseline_loss!,
    AbstractOptions,
    mutate!,
    condition_mutation_weights!,
    crossover,
    CrossoverResult,
    sample_mutation,
    MutationResult,
    AbstractRuntimeOptions,
    AbstractSearchState,
    @extend_operators,
    AbstractPlugin,
    MutationEvent,
    init_plugin_state,
    init_plugin_states,
    fork_plugin_state,
    refresh_worker_plugin_state,
    on_search_start!,
    on_search_end!,
    on_generation_end!,
    on_cycle_start!,
    on_cycle_end!,
    on_mutation_end!,
    init_member,
    tournament_cost_multiplier,
    mutation_acceptance_multiplier,
    prepare_mutation_context,
    condition_mutation!,
    AdaptiveMutationWeightsPlugin,
    SimulatedAnnealingPlugin,
    MutationBurstPlugin
using DynamicExpressions

include("utils.jl")
process_literate_blocks("test")
process_literate_blocks("examples")

# Define the proper YAML frontmatter for VitePress - must be wrapped in @raw html for DocumenterVitepress
proper_yaml = """```@raw html
---
layout: home

hero:
  name: SymbolicRegression.jl
  text: Discover Mathematical Laws from Data
  tagline: Fast, flexible evolutionary algorithms for interpretable machine learning
  actions:
    - theme: brand
      text: Get Started
      link: /examples
    - theme: alt
      text: API Reference 📚
      link: /api
    - theme: alt
      text: View on GitHub
      link: https://github.com/astroautomata/SymbolicRegression.jl
  image:
    src: https://raw.githubusercontent.com/MilesCranmer/PySR_Docs/master/images/pysr-logo.png
    alt: SymbolicRegression.jl

features:
  - icon: 🔬
    title: Interpretable By Design
    details: Discovers interpretable mathematical expressions instead of black-box models.

  - icon: 🚀
    title: Production Ready
    details: Years of development have produced mature, highly optimized parallel evolutionary algorithms.

  - icon: 🔧
    title: Extremely Customizable
    details: "Customize everything: operators, loss functions, complexity, input types, optimizer, and more."

  - icon: 🔌
    title: Julia Native
    details: Built for automatic interoperability with the entire scientific computing stack.
---
```

"""

# Post-process VitePress output to fix YAML frontmatter and HTML escaping
function post_process_vitepress_index()
    # Fix BOTH index.md files - in production mode, files are in build/1/ subdirectory
    is_production = get(ENV, "DOCUMENTER_PRODUCTION", "false") == "true"
    build_subdir = is_production ? "1" : "."

    for index_path in [
        joinpath(@__DIR__, "build", ".documenter", "index.md"),
        joinpath(@__DIR__, "build", build_subdir, "index.md"),
    ]
        process_single_index_file(index_path)
    end
end

function process_single_index_file(index_path)
    if !isfile(index_path)
        @warn "Index file not found: $index_path - skipping"
        return false
    end

    content = read(index_path, String)

    # Check if YAML frontmatter has been corrupted by DocumenterVitepress.jl
    has_hero_pattern = occursin(r"hero:\s*name:", content)
    if has_hero_pattern
        # Replace the corrupted frontmatter with proper VitePress home layout
        # Replace everything from the start up to the first "## Example" with our proper YAML
        content = replace(content, r"^.*?(?=## Example)"s => proper_yaml)
    end

    # Fix HTML escaping - unescape HTML entities
    content = replace(content, "&lt;" => "<")
    content = replace(content, "&gt;" => ">")
    content = replace(content, "&quot;" => "\"")
    content = replace(content, "&#39;" => "'")
    content = replace(content, "&amp;" => "&")

    write(index_path, content)
    return true
end

readme = open(dirname(@__FILE__) * "/../README.md") do io
    read(io, String)
end

# VitePress frontmatter for beautiful home page
vitepress_frontmatter = proper_yaml

# Process README for VitePress
readme = replace(readme, r"<!--.*?-->" => s"") # Remove markdown comments
readme = replace(readme, r"<[/]?div.*" => s"") # Remove div tags
readme = replace(readme, r"\*\*Contents\*\*:.*?(?=## )"s => s"") # Remove Contents TOC
readme = replace(readme, r"## Contributors ✨.*$"s => s"") # Remove Contributors section onwards
readme = replace(
    readme,
    r"(?<=href=\")((?:\./)?\.github/[^\"]+)" =>
        s"https://github.com/astroautomata/SymbolicRegression.jl/blob/master/\1",
)
readme = replace( # Convert video URL to proper video tag wrapped in @raw html for VitePress
    readme,
    r"https://github.com/astroautomata/SymbolicRegression.jl/assets/7593028/f5b68f1f-9830-497f-a197-6ae332c94ee0" => """```@raw html
<div align="center">
<video width="800" height="600" controls>
<source src="https://github.com/astroautomata/SymbolicRegression.jl/assets/7593028/f5b68f1f-9830-497f-a197-6ae332c94ee0" type="video/mp4">
</video>
</div>
```""",
)

# Wrap HTML tables in @raw html blocks for VitePress
readme = replace(readme, r"(<table>.*?</table>)"s => s"```@raw html\n\1\n```")

# Add VitePress frontmatter
readme = vitepress_frontmatter * readme

# Read base content
index_base = open(dirname(@__FILE__) * "/src/index_base.md") do io
    read(io, String)
end

# Create index.md with VitePress frontmatter and content
index_md_path = dirname(@__FILE__) * "/src/index.md"
open(index_md_path, "w") do io
    write(io, readme)
    write(io, "\n")
    write(io, index_base)
end

# Pre-process the source index.md to ensure clean YAML frontmatter
# This ensures VitePress processes clean YAML during makedocs()
function preprocess_source_index()
    index_path = joinpath(@__DIR__, "src", "index.md")
    if !isfile(index_path)
        @warn "Source index file not found: $index_path - skipping"
        return false
    end

    content = read(index_path, String)

    # Check if YAML frontmatter has any issues that need fixing
    has_hero_pattern = occursin(r"hero:\s*name:", content)
    if has_hero_pattern
        # Ensure YAML frontmatter is clean and properly formatted
        # Replace everything from the start up to the first "## Example" with our proper YAML
        content = replace(content, r"^.*?(?=## Example)"s => proper_yaml)
    end

    # Fix any HTML escaping in the source
    content = replace(content, "&lt;" => "<")
    content = replace(content, "&gt;" => ">")
    content = replace(content, "&quot;" => "\"")
    content = replace(content, "&#39;" => "'")
    content = replace(content, "&amp;" => "&")

    write(index_path, content)
    return true
end

# Run preprocessing on source files before makedocs()
preprocess_source_index()

ENV["GITHUB_REPOSITORY"] = "ai-damtp-cam-ac-uk/symbolicregression"
ENV["DOCUMENTER_KEY"] = get(ENV, "DOCUMENTER_KEY_CAM", "")

deploy_config = Documenter.auto_detect_deploy_system()
deploy_decision = Documenter.deploy_folder(
    deploy_config;
    repo="github.com/ai-damtp-cam-ac-uk/symbolicregression.git",
    devbranch="master",
    devurl="dev",
    push_preview=true,
)

current_version = let
    version = get(ENV, "DOCUMENTER_VERSION", nothing)
    if version !== nothing && !isempty(version)
        version
    else
        fallback = get(ENV, "DOCUMENTER_CURRENT_VERSION", nothing)
        if fallback !== nothing && !isempty(fallback)
            fallback
        else
            "dev"
        end
    end
end

DocMeta.setdocmeta!(
    SymbolicRegression,
    :DocTestSetup,
    :(using LossFunctions, DynamicExpressions);
    recursive=true,
)

makedocs(;
    sitename="SymbolicRegression.jl",
    authors="Miles Cranmer",
    version=current_version,
    doctest=true,
    clean=get(ENV, "DOCUMENTER_PRODUCTION", "false") == "true",
    warnonly=[:docs_block, :cross_references, :missing_docs],
    format=DocumenterVitepress.MarkdownVitepress(;
        repo="github.com/astroautomata/SymbolicRegression.jl",
        devbranch="master",
        devurl="dev",
        deploy_url="https://julia.pysr.ai/",
        deploy_decision,
        keep=:patch,
        build_vitepress=get(ENV, "DOCUMENTER_PRODUCTION", "false") == "true",
        md_output_path=if get(ENV, "DOCUMENTER_PRODUCTION", "false") == "true"
            ".documenter"
        else
            "."
        end,
    ),
    pages=[
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
        "Plugins" => "plugins.md",
        "Migrating from v1" => "migration.md",
    ],
)

# Post-processing after makedocs() (for any remaining issues in build output)
# This runs after VitePress build to fix any final rendering issues
post_process_vitepress_index()

# Fix bases.txt if it's empty (prevents "no bases suitable for deployment" error)
function fix_empty_bases()
    bases_file = joinpath(@__DIR__, "build", "bases.txt")
    mkpath(dirname(bases_file))

    if !isfile(bases_file)
        @info "Creating bases.txt for dev deployment"
        write(bases_file, "dev\n")
    else
        bases = filter(!isempty, readlines(bases_file))
        if isempty(bases)
            @info "Fixing empty bases.txt for dev deployment"
            write(bases_file, "dev\n")
        else
            @info "bases.txt already exists with $(length(bases)) bases: $bases"
            # Don't overwrite it - DocumenterVitepress may have generated multiple bases
        end
    end
end

fix_empty_bases()

# Additional post-processing for VitePress production build issues
function fix_vitepress_production_output()
    build_index_html = joinpath(@__DIR__, "build", "1", "index.html")
    if !isfile(build_index_html)
        @warn "Production index.html not found: $build_index_html"
        return false
    end

    content = read(build_index_html, String)

    # Check if the page is showing literal YAML instead of home layout
    if occursin(r"<p>layout: home</p>", content)
        @info "Detected literal YAML frontmatter in production HTML - fixing..."

        # This is a more complex fix - we need to regenerate the page with proper VitePress home layout
        # For now, let's try to replace the literal YAML content with a message
        content = replace(
            content,
            r"<div><hr><p>layout: home</p>.*?<hr>" => """<div class="VPDoc">
                                                      <div class="vp-doc">
                                                      <h1>SymbolicRegression.jl</h1>
                                                      <p><strong>Note:</strong> VitePress home layout not working in production mode. Please use the dev server or check the documentation.</p>
                                                      </div>
                                                      </div>""";
            count=1,
        )

        write(build_index_html, content)
        @info "Applied temporary fix to production HTML output"
        return true
    end

    return false
end

# Apply additional fix for production build
fix_vitepress_production_output()

DocumenterVitepress.deploydocs(;
    repo="github.com/ai-damtp-cam-ac-uk/symbolicregression.git",
    push_preview=true,
    target="build",
    devbranch="master",
)
