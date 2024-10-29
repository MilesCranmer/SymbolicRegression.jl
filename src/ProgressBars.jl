module ProgressBarsModule

using Compat: Fix
using ProgressMeter: Progress, next!
using StyledStrings: @styled_str
using ..UtilsModule: AnnotatedString

# Simple wrapper for a progress bar which stores its own state
mutable struct WrappedProgressBar
    bar::Progress
    postfix::Vector{Tuple{AnnotatedString,AnnotatedString}}

    function WrappedProgressBar(n::Integer, niterations::Integer; kwargs...)
        init_vector = Tuple{AnnotatedString,AnnotatedString}[]
        kwargs = (; kwargs..., desc="Evolving for $niterations iterations...")
        if get(ENV, "SYMBOLIC_REGRESSION_TEST", "false") == "true"
            # For testing, create a progress bar that writes to devnull
            output = devnull
            return new(Progress(n; output, kwargs...), init_vector)
        end
        return new(Progress(n; kwargs...), init_vector)
    end
end

function barlen(pbar::WrappedProgressBar)::Int
    return @something(pbar.bar.barlen, displaysize(stdout)[2])
end

"""Iterate a progress bar without needing to store cycle/state externally."""
function manually_iterate!(pbar::WrappedProgressBar)
    width = barlen(pbar)
    postfix = map(Fix{2}(format_for_meter, width), pbar.postfix)
    next!(pbar.bar; showvalues=postfix, valuecolor=:none)
    return nothing
end

function format_for_meter((k, s), width::Integer)
    new_s = if occursin('\n', s)
        pieces = [rpad(line, width) for line in split(s, '\n')]
        left_margin = length("  $(string(k)):  ")
        ' '^(width - left_margin) * join(pieces)
    else
        s
    end
    return (k, new_s)
end

end
