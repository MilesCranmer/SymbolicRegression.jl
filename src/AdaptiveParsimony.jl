module AdaptiveParsimonyModule

import ..CoreModule: Options, MAX_DEGREE

"""
    RunningSearchStatistics

A struct to keep track of various running averages of the search and discovered
equations, for use in adaptive losses and parsimony.
"""
mutable struct RunningSearchStatistics
    frequencies::Vector{Float64}
    window_size::Int
    smallest_frequency_allowed::Int
    normalized_frequencies::Vector{Float64}  # Stores `frequencies`, but normalized (updated once in a while)
end

function RunningSearchStatistics(;
    options::Options, window_size::Int=100000, smallest_frequency_allowed=1
)
    maxsize = options.maxsize
    actualMaxsize = maxsize + MAX_DEGREE
    init_frequencies = fill(Float64(window_size / actualMaxsize), actualMaxsize)

    return RunningSearchStatistics(
        init_frequencies, window_size, smallest_frequency_allowed, copy(init_frequencies)
    )
end

function update_frequencies!(
    running_search_statistics::RunningSearchStatistics; size=nothing
)
    if size <= length(running_search_statistics.frequencies)
        running_search_statistics.frequencies[size] += 1
    end
end

function move_window!(running_search_statistics::RunningSearchStatistics)
    frequencies = running_search_statistics.frequencies
    smallest_frequency_allowed = running_search_statistics.smallest_frequency_allowed
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
            if num_loops > 1000 || total_amount_to_subtract < 1e-6
                # Sometimes, total_amount_to_subtract can be a very very small number.
                break
            end
        end
    end
end

function normalize_frequencies!(running_search_statistics::RunningSearchStatistics)
    return running_search_statistics.normalized_frequencies .=
        running_search_statistics.frequencies ./ sum(running_search_statistics.frequencies)
end

end
