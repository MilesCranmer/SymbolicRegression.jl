import SnoopPrecompile: @precompile_all_calls, @precompile_setup

macro maybe_precompile_setup(mode, ex)
    precompile_ex = Expr(
        :macrocall, Symbol("@precompile_setup"), LineNumberNode(@__LINE__), ex
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

macro maybe_precompile_all_calls(mode, ex)
    precompile_ex = Expr(
        :macrocall, Symbol("@precompile_all_calls"), LineNumberNode(@__LINE__), ex
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
    @maybe_precompile_setup mode begin
        types = [Float32, Float64]
        for T in types
            @maybe_precompile_all_calls mode begin
                X = randn(T, 5, 100)
                y = 2 * cos.(X[4, :]) + X[1, :] .^ 2 .- 2
                options = SymbolicRegression.Options(;
                    binary_operators=[+, *, /, -],
                    unary_operators=[cos, exp],
                    npopulations=3,
                    npop=50,
                    ncycles_per_iteration=100,
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
                redirect_stderr(devnull) do
                    redirect_stdout(devnull) do
                        hall_of_fame = EquationSearch(
                            X,
                            y;
                            niterations=3,
                            options=options,
                            parallelism=:multithreading,
                        )
                        calculate_pareto_frontier(X, y, hall_of_fame, options)
                    end
                end
            end
        end
    end
end
