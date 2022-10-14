module ProgressBarsModule

"""
Customisable progressbar decorator for iterators.
Copied from https://github.com/cloud-oak/ProgressBars.jl to allow for custom modifications.
Usage:
> using ProgressBars
> for i in ProgressBar(1:10)
> ....
> end
"""

import Printf: @sprintf

EIGHTS = Dict(
    0 => ' ', 1 => '▏', 2 => '▎', 3 => '▍', 4 => '▌', 5 => '▋', 6 => '▊', 7 => '▉', 8 => '█'
)

# Split this because UTF-8 indexing is horrible otherwise
# IDLE = collect("◢◤ ")
IDLE = collect("╱   ")

PRINTING_DELAY = 0.05 * 1e9

"""
Decorate an iterable object, returning an iterator which acts exactly
like the original iterable, but prints a dynamically updating
progressbar every time a value is requested.
"""
mutable struct ProgressBar
    wrapped::Any
    total::Int
    current::Int
    width::Int
    fixwidth::Bool
    leave::Bool
    start_time::UInt
    last_print::UInt
    description::AbstractString
    postfix::NamedTuple
    extra_lines::Int
    last_extra_lines::Int
    multilinepostfix::AbstractString

    function ProgressBar(wrapped::Any; total::Int=-2, width=nothing, leave=true)
        this = new()
        this.wrapped = wrapped
        if width === nothing
            this.width = displaysize(stdout)[2]
            this.fixwidth = false
        else
            this.width = width
            this.fixwidth = true
        end
        this.leave = leave
        this.start_time = time_ns()
        this.last_print = this.start_time - 2 * PRINTING_DELAY
        this.description = ""
        this.postfix = NamedTuple()
        this.multilinepostfix = ""
        this.extra_lines = 0
        this.last_extra_lines = 0
        this.current = 0

        if total == -2  # No total given
            try
                this.total = length(wrapped)
            catch
                this.total = -1
            end
        else
            this.total = total
        end

        return this
    end
end

function format_time(seconds)
    if isfinite(seconds)
        mins, s = divrem(round(Int, seconds), 60)
        h, m = divrem(mins, 60)
    else
        h = 0
        m = Inf
        s = Inf
    end
    if h != 0
        return @sprintf("%02d:%02d:%02d", h, m, s)
    else
        return @sprintf("%02d:%02d", m, s)
    end
end

function display_progress(t::ProgressBar)
    seconds = (time_ns() - t.start_time) * 1e-9
    iteration = t.current - 1

    elapsed = format_time(seconds)
    speed = iteration / seconds
    if seconds == 0
        # Dummy value of 1 it/s if no time has elapsed
        speed = 1
    end
    iterations_per_second = @sprintf("%.1f it/s", speed)

    barwidth = t.width - 2 # minus two for the separators

    postfix_string = postfix_repr(t.postfix)

    # Reset Cursor to beginning of the line
    for line in 1:(t.extra_lines)
        move_up_1_line()
    end
    go_to_start_of_line()

    if t.description != ""
        barwidth -= length(t.description) + 1
        print(t.description * " ")
    end

    if (t.total <= 0)
        status_string = "$(t.current)it $elapsed [$iterations_per_second$postfix_string]"
        barwidth -= length(status_string) + 1
        if barwidth < 0
            barwidth = 0
        end

        print("┣")
        print(join(IDLE[1 + ((i + t.current) % length(IDLE))] for i in 1:barwidth))
        print("┫ ")
        print(status_string)
    else
        ETA = (t.total - t.current) / speed

        percentage_string = string(@sprintf("%.1f%%", t.current / t.total * 100))

        eta = format_time(ETA)
        status_string = "$(t.current)/$(t.total) [$elapsed<$eta, $iterations_per_second$postfix_string]"

        barwidth -= length(status_string) + length(percentage_string) + 1
        if barwidth < 0
            barwidth = 0
        end

        cellvalue = t.total / barwidth
        full_cells, remain = divrem(t.current, cellvalue)

        print(percentage_string)
        print("┣")
        print(repeat("█", Int(full_cells)))
        if (full_cells < barwidth)
            part = Int(floor(9 * remain / cellvalue))
            print(EIGHTS[part])
            print(repeat(" ", Int(barwidth - full_cells - 1)))
        end

        print("┫ ")
        print(status_string)
    end
    multiline_postfix_string = newline_to_spaces(t.multilinepostfix, t.width)
    t.last_extra_lines = t.extra_lines
    t.extra_lines = ceil(Int, length(multiline_postfix_string) / t.width) + 1
    print(multiline_postfix_string)
    return println() #Newline is required for Python to read in.
end

erase_to_end_of_line() = print("\033[K")
move_up_1_line() = print("\033[1A")
move_down_1_line() = print("\033[1B")
go_to_start_of_line() = print("\r")
erase_line() = begin
    go_to_start_of_line()
    erase_to_end_of_line()
end

# Clear the progress bar
function clear_progress(t::ProgressBar)
    # Reset cursor, fill width with empty spaces, and then reset again
    if t.last_extra_lines > t.extra_lines
        for line in 1:(t.last_extra_lines - t.extra_lines)
            move_down_1_line()
        end
    end
    for line in 1:max(t.extra_lines, t.last_extra_lines)
        erase_line()
        move_up_1_line()
    end
    return erase_line()
end

function set_multiline_postfix!(t::ProgressBar, postfix::AbstractString)
    mistakenly_used_newline_at_start = postfix[1] == '\n' && length(postfix) > 1
    if mistakenly_used_newline_at_start
        postfix = postfix[2:end]
    end
    return t.multilinepostfix = postfix
end

function postfix_repr(postfix::NamedTuple)::AbstractString
    return join(map(tpl -> ", $(tpl[1]): $(tpl[2])", zip(keys(postfix), postfix)))
end

function Base.iterate(iter::ProgressBar)
    if displaysize(stdout)[2] != iter.width && !iter.fixwidth
        iter.width = displaysize(stdout)[2]
        print("\n"^(iter.extra_lines + 2))
    end
    iter.start_time = time_ns() - PRINTING_DELAY
    iter.current = 0
    display_progress(iter)
    return iterate(iter.wrapped)
end

function Base.iterate(iter::ProgressBar, s)
    if displaysize(stdout)[2] != iter.width && !iter.fixwidth
        iter.width = displaysize(stdout)[2]
        print("\n"^(iter.extra_lines + 2))
    end
    iter.current += 1
    if (time_ns() - iter.last_print > PRINTING_DELAY)
        display_progress(iter)
        iter.last_print = time_ns()
    end
    state = iterate(iter.wrapped, s)
    if state === nothing
        if iter.total > 0
            iter.current = iter.total
        end
        display_progress(iter)
        if iter.leave
            println()
        else
            clear_progress(iter)
        end
        return nothing
    end
    return state
end
Base.length(iter::ProgressBar) = length(iter.wrapped)
Base.eltype(iter::ProgressBar) = eltype(iter.wrapped)

function newline_to_spaces(string, terminal_width)
    new_string = ""
    width_cumulator = 0
    for c in string
        if c == '\n'
            spaces_required = terminal_width - width_cumulator
            new_string *= " "^spaces_required
            width_cumulator = 0
        else
            new_string *= c
            width_cumulator += 1
        end
        if width_cumulator == terminal_width
            width_cumulator = 0
        end
    end
    return new_string
end

# Simple wrapper for a progress bar which stores its own state
mutable struct WrappedProgressBar
    bar::ProgressBar
    state::Union{Int,Nothing}
    cycle::Union{Int,Nothing}

    function WrappedProgressBar(args...; kwargs...)
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
    return set_multiline_postfix!(t.bar, postfix)
end

end
