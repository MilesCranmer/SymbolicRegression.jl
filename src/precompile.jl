using PrecompileTools: @compile_workload, @setup_workload
using Preferences: @load_preference
using Serialization: Serialization

# The precompile workload can be tuned with Preferences.jl. For example, to
# disable the Float64 precompilation, set the `precompile_float64` preference
# to `false`:
#
#     using Preferences
#     Preferences.set_preferences!(SymbolicRegression, "precompile_float64" => false)
#
# (Changing this requires a restart of Julia to trigger re-precompilation.)
const PRECOMPILE_FLOAT64 = @load_preference("precompile_float64", true)
const PRECOMPILE_TYPES = PRECOMPILE_FLOAT64 ? (Float32, Float64) : (Float32,)

macro maybe_setup_workload(mode, ex)
    precompile_ex = Expr(
        :macrocall, Symbol("@setup_workload"), LineNumberNode(@__LINE__), ex
    )
    return quote
        if $(esc(mode)) == :compile
            $(esc(ex))
        elseif $(esc(mode)) == :precompile
            $(esc(precompile_ex))
        else
            error("Invalid value for mode: " * show($(esc(mode))))
        end
    end
end

macro maybe_compile_workload(mode, ex)
    precompile_ex = Expr(
        :macrocall, Symbol("@compile_workload"), LineNumberNode(@__LINE__), ex
    )
    return quote
        if $(esc(mode)) == :compile
            $(esc(ex))
        elseif $(esc(mode)) == :precompile
            $(esc(precompile_ex))
        else
            error("Invalid value for mode: " * show($(esc(mode))))
        end
    end
end

"""`mode=:precompile` will use `@precompile_*` directives; `mode=:compile` runs."""
function do_precompilation(
    ::Val{mode};
    operator_kwargs=(;
        binary_operators=[+, *, /, -, ^], unary_operators=[sin, cos, exp, log, sqrt, abs]
    ),
    search_kwargs=(;),
    parallelism=:multithreading,
    search_verbosity::Int=0,
    precompile_serialization=false,
) where {mode}
    @maybe_setup_workload mode begin
        for T in PRECOMPILE_TYPES, nout in (1,)
            start = nout == 1
            N = 30
            X = randn(T, 3, N)
            y = start ? randn(T, N) : randn(T, nout, N)
            @maybe_compile_workload mode begin
                options = SymbolicRegression.Options(;
                    operator_kwargs...,
                    populations=3,
                    population_size=start ? 50 : 12,
                    tournament_selection_n=6,
                    ncycles_per_iteration=start ? 30 : 1,
                    mutation_weights=(;
                        mutate_constant=1.0,
                        mutate_operator=1.0,
                        swap_operands=1.0,
                        add_node=1.0,
                        insert_node=1.0,
                        delete_node=1.0,
                        simplify=1.0,
                        randomize=1.0,
                        do_nothing=1.0,
                        optimize=1.0,
                    ),
                    fraction_replaced=0.2,
                    fraction_replaced_hof=0.2,
                    define_helper_functions=false,
                    optimizer_probability=0.05,
                    save_to_file=false,
                )
                state = equation_search(
                    X,
                    y;
                    niterations=start ? 3 : 1,
                    options=options,
                    parallelism=parallelism,
                    return_state=true,
                    saved_state=nothing,
                    verbosity=search_verbosity,
                    search_kwargs...,
                )
                hof = equation_search(
                    X,
                    y;
                    niterations=0,
                    options=options,
                    parallelism=parallelism,
                    saved_state=state,
                    return_state=false,
                    verbosity=search_verbosity,
                    search_kwargs...,
                )
                nout == 1 && calculate_pareto_frontier(hof::HallOfFame)
                if precompile_serialization
                    for value in (options, state)
                        buffer = IOBuffer()
                        Serialization.serialize(buffer, value)
                        seekstart(buffer)
                        Serialization.deserialize(buffer)
                    end
                end
            end
        end
    end
    return nothing
end
