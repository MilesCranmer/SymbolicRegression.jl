using Coverage
# process '*.cov' files
coverage = process_folder() # defaults to src/; alternatively, supply the folder name as argument
push!(coverage, process_folder("ext")...)

LCOV.writefile("lcov.info", coverage)

# process '*.info' files
coverage = merge_coverage_counts(
    coverage,
    filter!(
        let prefixes = (joinpath(pwd(), "src", ""), joinpath(pwd(), "ext", ""))
            c -> any(p -> startswith(c.filename, p), prefixes)
        end,
        LCOV.readfolder("test"),
    ),
)
# Get total coverage for all Julia files
covered_lines, total_lines = get_summary(coverage)
@show covered_lines, total_lines
