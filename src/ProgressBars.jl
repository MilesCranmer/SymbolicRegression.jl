module ProgressBarsModule

import ProgressBars: ProgressBar, set_multiline_postfix

# Simple wrapper for a progress bar which stores its own state
mutable struct WrappedProgressBar
    bar::ProgressBar
    state::Union{Int,Nothing}
    cycle::Union{Int,Nothing}

    function WrappedProgressBar(args...; kwargs...)
        if haskey(ENV, "SYMBOLIC_REGRESSION_TEST") &&
            ENV["SYMBOLIC_REGRESSION_TEST"] == "true"
            output_stream = devnull
            return new(ProgressBar(args...; output_stream, kwargs...), nothing, nothing)
        end
        return new(ProgressBar(args...; kwargs...), nothing, nothing)
    end
end

"""Iterate a progress bar without needing to store cycle/state externally."""
function manually_iterate!(progress_bar::WrappedProgressBar)
    cur_cycle = progress_bar.cycle
    cur_state = progress_bar.state
    if cur_cycle === nothing
        cur_cycle, cur_state = iterate(progress_bar.bar)
    else
        cur_cycle, cur_state = iterate(progress_bar.bar, cur_state)
    end
    progress_bar.cycle = cur_cycle
    progress_bar.state = cur_state
    return nothing
end

function set_multiline_postfix!(t::WrappedProgressBar, postfix::AbstractString)
    return set_multiline_postfix(t.bar, postfix)
end

end
