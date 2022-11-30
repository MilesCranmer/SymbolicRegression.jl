module AdaptiveParsimonyModule

import ..CoreModule: Options, MAX_DEGREE

"""
    RunningSearchStatistics

A struct to keep track of various running averages of the search and discovered
equations, for use in adaptive losses and parsimony.

# Fields

- `window_size::Int`: After this many equations are seen, the frequencies are reduced
    by 1, averaged over all complexities, each time a new equation is seen.
- `frequencies::Vector{Float64}`: The number of equations seen at this complexity,
    given by the index.
- `normalized_frequencies::Vector{Float64}`: This is the same as `frequencies`, but
    normalized to sum to 1.0. This is updated once in a while.
"""
mutable struct RunningSearchStatistics
    window_size::Int
    frequencies::Vector{Float64}
    normalized_frequencies::Vector{Float64}  # Stores `frequencies`, but normalized (updated once in a while)
end

function RunningSearchStatistics(; options::Options, window_size::Int=100000)
    maxsize = options.maxsize
    actualMaxsize = maxsize + MAX_DEGREE
    init_frequencies = ones(Float64, actualMaxsize)

    return RunningSearchStatistics(
        window_size, init_frequencies, copy(init_frequencies) / sum(init_frequencies)
    )
end

"""
    update_frequencies!(running_search_statistics::RunningSearchStatistics; size=nothing)

Update the frequencies in `running_search_statistics` by adding 1 to the frequency
for an equation at size `size`.
"""
@inline function update_frequencies!(
    running_search_statistics::RunningSearchStatistics; size=nothing
)
    if 0 < size <= length(running_search_statistics.frequencies)
        running_search_statistics.frequencies[size] += 1
    end
    return nothing
end

"""
    move_window!(running_search_statistics::RunningSearchStatistics)

Reduce `running_search_statistics.frequencies` until it sums to
`window_size`.
"""
function move_window!(running_search_statistics::RunningSearchStatistics)
    smallest_frequency_allowed = 1
    max_loops = 1000

    frequencies = running_search_statistics.frequencies
    window_size = running_search_statistics.window_size

    cur_size_frequency_complexities = sum(frequencies)
    if cur_size_frequency_complexities > window_size
        difference_in_size = cur_size_frequency_complexities - window_size
        # We need frequencyComplexities to be positive, but also sum to a number.
        num_loops = 0
        # TODO: Clean this code up. Should not have to have
        # loop catching.
        while difference_in_size > 0
            indices_to_subtract = findall(frequencies .> smallest_frequency_allowed)
            num_remaining = size(indices_to_subtract, 1)
            amount_to_subtract = min(
                difference_in_size / num_remaining,
                min(frequencies[indices_to_subtract]...) - smallest_frequency_allowed,
            )
            frequencies[indices_to_subtract] .-= amount_to_subtract
            total_amount_to_subtract = amount_to_subtract * num_remaining
            difference_in_size -= total_amount_to_subtract
            num_loops += 1
            if num_loops > max_loops || total_amount_to_subtract < 1e-6
                # Sometimes, total_amount_to_subtract can be a very very small number.
                break
            end
        end
    end
    return nothing
end

function normalize_frequencies!(running_search_statistics::RunningSearchStatistics)
    running_search_statistics.normalized_frequencies .=
        running_search_statistics.frequencies ./ sum(running_search_statistics.frequencies)
    return nothing
end

end
