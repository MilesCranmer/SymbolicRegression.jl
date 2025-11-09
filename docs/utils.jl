using Literate: Literate

# Function to process literate blocks in test files
function process_literate_blocks(base_path="test")
    test_dir = joinpath(@__DIR__, "..", base_path)
    for (dirpath, _, files) in walkdir(test_dir)
        for file in files
            endswith(file, ".jl") && process_file(joinpath(dirpath, file))
        end
    end
end

function process_file(filepath)
    content = read(filepath, String)
    blocks = match_literate_blocks(content)
    for (output_file, block_content) in blocks
        process_literate_block(output_file, block_content, filepath)
    end
end

function match_literate_blocks(content)
    pattern = r"^(\s*)#literate_begin\s+file=\"(.*?)\"\n(.*?)#literate_end"sm
    matches = collect(eachmatch(pattern, content))
    return Dict(
        m.captures[2] => process_block_content(m.captures[1], m.captures[3]) for
        m in matches
    )
end

function process_block_content(indent, block_content)
    if isempty(block_content)
        return ""
    end
    indent_length = length(indent)
    # Filter out formatter directive lines
    lines = split(block_content, '\n')
    lines = filter(line -> !startswith(strip(line), "#! format:"), lines)
    stripped_lines = [
        if startswith(line, indent)
            line[(length(indent) + 1):end]  # Only remove exactly the indent prefix
        else
            line  # Keep the line as is if it doesn't have the expected indent
        end for line in lines
    ]
    return strip(join(stripped_lines, '\n'))
end

function process_literate_block(output_file, content, source_file)
    # Create a temporary .jl file
    temp_file = tempname() * ".jl"
    write(temp_file, content)

    # Process the temporary file with Literate.markdown
    output_dir = joinpath(@__DIR__, "src", "examples")
    base_name = first(splitext(basename(output_file))) # Remove any existing extension

    Literate.markdown(temp_file, output_dir; name=base_name, documenter=true)

    # Generate the relative path for EditURL
    edit_path = relpath(source_file, output_dir)

    # Read the generated markdown file
    md_file = joinpath(output_dir, base_name * ".md")
    md_content = read(md_file, String)

    # Replace the existing EditURL with the correct one
    new_content = replace(md_content, r"EditURL = .*" => "EditURL = \"$edit_path\"")

    # Add a codeblock at the end with the raw julia source
    new_content = replace(
        new_content,
        r"\*This page was generated using \[Literate\.jl\]\(https://github\.com/fredrikekre/Literate\.jl\)\.\*" => """

    ```@raw html
    <details>
    <summary> Show raw source code </summary>
    ```

    ```julia
    $(replace(content, r"```" => "\\```"))
    ```

    which uses Literate.jl to generate this page.

    ```@raw html
    </details>
    ```

    """,
    )

    # Write the updated content back to the file
    write(md_file, new_content)

    @info "Processed literate block to $md_file with EditURL set to $edit_path"
end
