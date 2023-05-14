using BenchmarkTools
using SymbolicRegression, BenchmarkTools, Random
using SymbolicRegression.AdaptiveParsimonyModule: RunningSearchStatistics
using SymbolicRegression.PopulationModule: best_of_sample
using SymbolicRegression.ConstantOptimizationModule: optimize_constants
using SymbolicRegression.CheckConstraintsModule: check_constraints

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
        loss=(pred, target) -> (pred - target)^2,
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
                equation_search(X, y; options, parallelism, niterations)
            end
        end
        f() # Warmup
        samples = if parallelism == :serial
            5
        else
            10
        end
        suite[parallelism] = @benchmarkable(
            ($f)(), evals = 1, samples = samples, seconds = 2_000
        )
    end
    return suite
end

function create_utils_benchmark()
    suite = BenchmarkGroup()

    options = Options(; unary_operators=[sin, cos], binary_operators=[+, -, *, /])

    suite["best_of_sample"] = @benchmarkable(
        best_of_sample(pop, rss, $options),
        setup = (
            nfeatures = 1;
            dataset = Dataset(randn(nfeatures, 32), randn(32));
            pop = Population(dataset; npop=100, nlength=20, options=$options, nfeatures);
            rss = RunningSearchStatistics(; options=$options)
        )
    )

    ntrees = 10
    suite["optimize_constants_x10"] = @benchmarkable(
        foreach(members) do member
            optimize_constants(dataset, member, $options)
        end,
        seconds = 20,
        setup = (
            nfeatures = 1;
            T = Float64;
            dataset = Dataset(randn(nfeatures, 512), randn(512));
            ntrees = $ntrees;
            trees = [
                gen_random_tree_fixed_size(20, $options, nfeatures, T) for i in 1:ntrees
            ];
            members = [
                PopMember(dataset, tree, $options; deterministic=false) for tree in trees
            ]
        )
    )

    ntrees = 10
    suite["compute_complexity_x10"] = let s = BenchmarkGroup()
        for T in (Float64, Int, nothing)
            options = Options(;
                unary_operators=[sin, cos],
                binary_operators=[+, -, *, /],
                complexity_of_constants=T === nothing ? T : T(1),
            )
            s[T] = @benchmarkable(
                foreach(trees) do tree
                    compute_complexity(tree, $options)
                end,
                setup = (
                    T = Float64;
                    nfeatures = 3;
                    trees = [
                        gen_random_tree_fixed_size(20, $options, nfeatures, T) for
                        i in 1:($ntrees)
                    ]
                )
            )
        end
        s
    end

    ntrees = 10
    options = Options(;
        unary_operators=[sin, cos],
        binary_operators=[+, -, *, /],
        maxsize=30,
        maxdepth=20,
        nested_constraints=[
            (+) => [(/) => 1, (+) => 2],
            sin => [sin => 0, cos => 2],
            cos => [sin => 0, cos => 0, (+) => 1, (-) => 1],
        ],
        constraints=[(+) => (-1, 10), (/) => (10, 10), sin => 12, cos => 5],
    )
    suite["check_constraints_x10"] = @benchmarkable(
        foreach(trees) do tree
            check_constraints(tree, $options, $options.maxsize)
        end,
        setup = (
            T = Float64;
            nfeatures = 3;
            trees = [
                gen_random_tree_fixed_size(20, $options, nfeatures, T) for i in 1:($ntrees)
            ]
        )
    )

    return suite
end

function create_benchmark()
    suite = BenchmarkGroup()
    suite["search"] = create_search_benchmark()
    suite["utils"] = create_utils_benchmark()
    return suite
end

const SUITE = create_benchmark()
