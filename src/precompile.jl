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
function do_precompilation(; mode=:precompile)
    limited_precompilation = parse(Bool, get(ENV, "SR_LIMITED_PRECOMPILATION", "false"))
    @maybe_setup_workload mode begin
        types = limited_precompilation ? [Float32] : [Float32, Float64]
        all_nout = 1:2
        for T in types, nout in all_nout
            N = 2
            X = randn(T, 5, N)
            y = nout == 1 ? randn(T, N) : randn(T, nout, N)
            @maybe_compile_workload mode begin
                options = SymbolicRegression.Options(;
                    binary_operators=[+, *, /, -, ^],
                    unary_operators=[sin, cos, exp, log, sqrt, abs],
                    npopulations=nout == 1 ? 3 : 1,
                    npop=nout == 1 ? 50 : 12,
                    ncycles_per_iteration=nout == 1 ? 100 : 1,
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
                    niterations=3,
                    options=options,
                    parallelism=:multithreading,
                    return_state=true,
                )
                nout == 1 && calculate_pareto_frontier(state[2])
                if nout > 2
                    equation_search(
                        X,
                        y;
                        niterations=0,
                        options=options,
                        parallelism=:multithreading,
                        saved_state=state,
                        return_state=false,
                    )
                end
            end
        end
    end
end
