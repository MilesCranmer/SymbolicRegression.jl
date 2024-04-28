module ProgressBarsModule

using ProgressBars: ProgressBar, set_multiline_postfix

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
function manually_iterate!(pbar::WrappedProgressBar)
    cur_cycle = pbar.cycle
    if cur_cycle === nothing
        pbar.cycle, pbar.state = iterate(pbar.bar)
    else
        pbar.cycle, pbar.state = iterate(pbar.bar, pbar.state)
    end
    return nothing
end

function set_multiline_postfix!(t::WrappedProgressBar, postfix::AbstractString)
    return set_multiline_postfix(t.bar, postfix)
end

end
