module AdaptiveParsimonyModule

import ..CoreModule: Options, MAX_DEGREE
import ..EquationUtilsModule: compute_complexity
import ..HallOfFameModule: HallOfFame, calculate_pareto_frontier

"""
    RollingSearchStatistics

A struct to keep track of various running averages of the search and discovered
equations, for use in adaptive losses and parsimony.
"""
mutable struct RollingSearchStatistics{T}
    frequencies::Vector{Float64}
    normalized_frequencies::Vector{Float64}  # Stores `frequencies`, but normalized (updated once in a while)
    window_size::Int
    smallest_frequency_allowed::Int
    dense_pareto_front::Vector{T}
    normalized_dense_pareto_front::Vector{T}
end

function RollingSearchStatistics(
    ::Type{T}; options::Options, window_size::Int=100000, smallest_frequency_allowed=1
) where {T}
    maxsize = options.maxsize
    actualMaxsize = maxsize + MAX_DEGREE
    init_frequencies = fill(Float64(window_size / actualMaxsize), actualMaxsize)

    return RollingSearchStatistics(
        init_frequencies,
        copy(init_frequencies),
        window_size,
        smallest_frequency_allowed,
        fill(T(Inf), maxsize),
        fill(T(Inf), maxsize),
    )
end

function update_frequencies!(rolling_search_statistics::RollingSearchStatistics; size::Int)
    if size <= length(rolling_search_statistics.frequencies)
        rolling_search_statistics.frequencies[size] += 1
    end
    return nothing
end

function normalize_frequencies!(rolling_search_statistics::RollingSearchStatistics)
    rolling_search_statistics.normalized_frequencies .=
        rolling_search_statistics.frequencies ./ sum(rolling_search_statistics.frequencies)
    return nothing
end

function update_dense_pareto_front!(
    rolling_search_statistics::RollingSearchStatistics{T};
    hall_of_fame::HallOfFame{T},
    options::Options,
) where {T}
    s = length(rolling_search_statistics.dense_pareto_front)
    dense_pareto_front = fill(T(Inf), s)
    for member in calculate_pareto_frontier(hall_of_fame, options)
        # Assume all the more complex expressions have the same loss (at worst)
        size = compute_complexity(member.tree, options)
        dense_pareto_front[size:end] .= member.loss
    end
    for i in 1:s
        rolling_search_statistics.dense_pareto_front[i] = min(
            rolling_search_statistics.dense_pareto_front[i], dense_pareto_front[i]
        )
    end
    return nothing
end

function normalize_dense_pareto_front!(rolling_search_statistics::RollingSearchStatistics{T}) where {T}
    dense_pareto_front = copy(rolling_search_statistics.dense_pareto_front)
    bad_vals = findall(x -> !isfinite(x), dense_pareto_front)
    if length(bad_vals) > 0
        good_vals = findall(x -> isfinite(x), dense_pareto_front)
        if length(good_vals) == 0
            rolling_search_statistics.normalized_dense_pareto_front .= fill(one(T), length(dense_pareto_front))
            return nothing
        end
        dense_pareto_front[bad_vals] .= maximum(dense_pareto_front[good_vals])
    end
    # Now, it is safe to normalize:
    rolling_search_statistics.normalized_dense_pareto_front .=
        dense_pareto_front ./ maximum(dense_pareto_front)
    return nothing
end

function normalize_statistics!(rolling_search_statistics::RollingSearchStatistics)::Nothing
    normalize_frequencies!(rolling_search_statistics)
    normalize_dense_pareto_front!(rolling_search_statistics)
    return nothing
end

function move_window!(rolling_search_statistics::RollingSearchStatistics)
    frequencies = rolling_search_statistics.frequencies
    smallest_frequency_allowed = rolling_search_statistics.smallest_frequency_allowed
    window_size = rolling_search_statistics.window_size

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
    return nothing
end

end
