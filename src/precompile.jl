import PrecompileTools: @compile_workload, @setup_workload

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
function do_precompilation(::Val{mode}) where {mode}
    @maybe_setup_workload mode begin
        for T in [Float32, Float64], nout in 1:2
            start = nout == 1
            N = 30
            X = randn(T, 3, N)
            y = start ? randn(T, N) : randn(T, nout, N)
            @maybe_compile_workload mode begin
                options = SymbolicRegression.Options(;
                    binary_operators=[+, *, /, -, ^],
                    unary_operators=[sin, cos, exp, log, sqrt, abs],
                    populations=3,
                    population_size=start ? 50 : 12,
                    ncycles_per_iteration=start ? 30 : 1,
                    mutation_weights=MutationWeights(;
                        mutate_constant=1.0,
                        mutate_operator=1.0,
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
                    parallelism=:multithreading,
                    return_state=true,
                )
                hof = equation_search(
                    X,
                    y;
                    niterations=0,
                    options=options,
                    parallelism=:multithreading,
                    saved_state=state,
                    return_state=false,
                )
                nout == 1 && calculate_pareto_frontier(hof)
            end
        end
    end
    return nothing
end
