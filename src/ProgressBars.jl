module ProgressBarsModule

using Compat: Fix
using ProgressMeter: ProgressMeter, Progress, next!
using StyledStrings: @styled_str, annotatedstring
using ..UtilsModule: AnnotatedString

# Simple wrapper for a progress bar which stores its own state
mutable struct WrappedProgressBar
    bar::Progress
    postfix::Vector{Tuple{AnnotatedString,AnnotatedString}}
    clean_postfix::Vector{Tuple{AnnotatedString,AnnotatedString}}
    last_update::Float64

    function WrappedProgressBar(n::Integer, niterations::Integer; kwargs...)
        init_vector = Tuple{AnnotatedString,AnnotatedString}[]
        kwargs = (; kwargs..., desc="Evolving for $niterations iterations...")
        last_update = time()
        if get(ENV, "SYMBOLIC_REGRESSION_TEST", "false") == "true"
            # For testing, create a progress bar that writes to devnull
            output = devnull
            return new(
                Progress(n; output, kwargs...), init_vector, copy(init_vector), last_update
            )
        end
        return new(Progress(n; kwargs...), init_vector, copy(init_vector), last_update)
    end
end

function barlen(pbar::WrappedProgressBar)::Int
    return @something(pbar.bar.barlen, displaysize(stdout)[2])
end

function ProgressMeter.finish!(pbar::WrappedProgressBar)
    ProgressMeter.finish!(pbar.bar)
    return nothing
end

"""Iterate a progress bar."""
function manually_iterate!(pbar::WrappedProgressBar)
    width = barlen(pbar)
    last_update = pbar.last_update
    update_interval = 0.005
    if time() - last_update > update_interval
        pbar.clean_postfix = map(Fix{2}(format_for_meter, width), pbar.postfix)
        pbar.last_update = time()
    end
    next!(pbar.bar; showvalues=pbar.clean_postfix, valuecolor=:none)
    return nothing
end

function format_for_meter((k, s), width::Integer)
    new_s = if occursin('\n', s)
        left_margin = length("  $(string(k)):  ")
        left_padding = ' '^(width - left_margin)
        annotatedstring(left_padding, newlines_to_spaces(s, width))
    else
        s
    end
    return (k, new_s)
end

function newlines_to_spaces(s::AbstractString, width::Integer)
    return join(rpad(line, width) for line in split(s, '\n'))
end

end
