using BenchmarkTools
using SymbolicRegression, BenchmarkTools, Random
using SymbolicRegression: eval_tree_array, gen_random_tree_fixed_size

function create_evaluation_benchmark()
    suite = BenchmarkGroup()
    make_options =
        extra_kws -> Options(;
            binary_operators=(+, -, /, *),
            unary_operators=(cos, exp),
            verbosity=0,
            progress=false,
            extra_kws...,
        )
    for T in (Float32, Float64), node_count in (2 .^ (2:5))
        extra_kws = NamedTuple()
        if hasfield(Options, :define_helper_functions)
            extra_kws = merge(extra_kws, (define_helper_functions=false,))
        end
        if hasfield(Options, :turbo) && T in (Float32, Float64)
            extra_kws = merge(extra_kws, (turbo=true,))
        end
        if hasfield(Options, :save_to_file)
            extra_kws = merge(extra_kws, (save_to_file=false,))
        end
        options = make_options(extra_kws)
        evals = 100
        samples = 10_000
        if !haskey(suite, string(T))
            suite[T] = BenchmarkGroup()
        end
        suite[T][node_count] = @benchmarkable eval_tree_array(tree, X, $options) evals = evals samples =
            samples seconds = 50.0 setup = (
            X=randn($T, 5, 1000);
            tree=gen_random_tree_fixed_size($node_count, $options, 5, $T)
        )
    end
    return suite
end

function create_search_benchmark()
    suite = BenchmarkGroup()

    n = 1000
    T = Float32

    extra_kws = NamedTuple()
    if hasfield(Options, :turbo)
        extra_kws = merge(extra_kws, (turbo=true,))
    end
    if hasfield(Options, :save_to_file)
        extra_kws = merge(extra_kws, (save_to_file=false,))
    end
    if hasfield(Options, :define_helper_functions)
        extra_kws = merge(extra_kws, (define_helper_functions=false,))
    end
    option_kws = (;
        binary_operators=(+, -, /, *),
        unary_operators=(exp, abs),
        maxsize=30,
        verbosity=0,
        progress=false,
        extra_kws...,
    )
    seeds = 1:3
    niterations = 30
    # We create an equation that cannot be found exactly, so the search
    # is more realistic.
    eqn(x) = Float32(cos(2.13 * x[1]) + 0.5 * x[2] * abs(x[3])^0.9 - 0.3 * abs(x[4])^1.5)
    all_options = Dict(
        :serial =>
            [Options(; seed=seed, deterministic=true, option_kws...) for seed in seeds],
        :multithreading =>
            [Options(; seed=seed, deterministic=false, option_kws...) for seed in seeds],
    )
    all_X = [rand(MersenneTwister(seed), T, 5, n) .* 10 .- 5 for seed in seeds]
    all_y = [
        [eqn(x) for x in eachcol(X)] .+ 0.1f0 .* randn(MersenneTwister(seed + 1), T, n) for
        (X, seed) in zip(all_X, seeds)
    ]

    for parallelism in (:serial, :multithreading)
        # TODO: Add determinism for other parallelisms
        function f()
            for (options, X, y) in zip(all_options[parallelism], all_X, all_y)
                EquationSearch(X, y; options, parallelism, niterations)
            end
        end
        f() # Warmup
        samples = if parallelism == :serial
            1
        else
            5
        end
        suite[parallelism] = @benchmarkable ($f)() evals = 1 samples = samples seconds =
            1_000
    end
    return suite
end

function create_benchmark()
    suite = BenchmarkGroup()
    suite["evaluation"] = create_evaluation_benchmark()
    # suite["search"] = create_search_benchmark()
    return suite
end

const SUITE = create_benchmark()
