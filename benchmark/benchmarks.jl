using BenchmarkTools
using SymbolicRegression, BenchmarkTools, Random
using SymbolicRegression.AdaptiveParsimonyModule: RunningSearchStatistics
using SymbolicRegression.MutateModule: next_generation
using SymbolicRegression.RecorderModule: RecordType
using SymbolicRegression.PopulationModule: best_of_sample
using SymbolicRegression.ConstantOptimizationModule: optimize_constants
using SymbolicRegression.CheckConstraintsModule: check_constraints
using Bumper, LoopVectorization

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
        mutation_weights=MutationWeights(),
        loss=(pred, target) -> (pred - target)^2,
        extra_kws...,
    )
    if hasfield(MutationWeights, :swap_operands)
        option_kws.mutation_weights.swap_operands = 0.0
    end
    if hasfield(MutationWeights, :form_connection)
        option_kws.mutation_weights.form_connection = 0.0
    end
    if hasfield(MutationWeights, :break_connection)
        option_kws.mutation_weights.break_connection = 0.0
    end
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
            pop = Population(dataset; npop=100, nlength=20, options=($options), nfeatures);
            rss = RunningSearchStatistics(; options=($options))
        )
    )

    suite["next_generation_x100"] = @benchmarkable(
        let
            for member in members
                next_generation(
                    dataset,
                    member,
                    temperature,
                    curmaxsize,
                    rss,
                    options;
                    tmp_recorder=recorder,
                )
            end
        end,
        setup = (
            nfeatures = 1;
            dataset = Dataset(randn(nfeatures, 32), randn(32));
            mutation_weights = MutationWeights(;
                mutate_constant=1.0,
                mutate_operator=1.0,
                swap_operands=1.0,
                rotate_tree=1.0,
                add_node=1.0,
                insert_node=1.0,
                simplify=0.0,
                randomize=0.0,
                do_nothing=0.0,
                form_connection=0.0,
                break_connection=0.0,
            );
            options = Options(;
                unary_operators=[sin, cos], binary_operators=[+, -, *, /], mutation_weights
            );
            recorder = RecordType();
            temperature = 1.0;
            curmaxsize = 20;
            rss = RunningSearchStatistics(; options);
            trees = [
                gen_random_tree_fixed_size(15, options, nfeatures, Float64) for _ in 1:100
            ];
            expressions = [
                Expression(tree; operators=options.operators, variable_names=["x1"]) for
                tree in trees
            ];
            members = [
                PopMember(dataset, expression, options; deterministic=false) for
                expression in expressions
            ]
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
            ntrees = ($ntrees);
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

    if isdefined(SymbolicRegression.MutationFunctionsModule, :randomly_rotate_tree!)
        suite["randomly_rotate_tree_x10"] = @benchmarkable(
            foreach(trees) do tree
                SymbolicRegression.MutationFunctionsModule.randomly_rotate_tree!(tree)
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

    suite["insert_random_op_x10"] = @benchmarkable(
        foreach(trees) do tree
            SymbolicRegression.MutationFunctionsModule.insert_random_op(
                tree, $options, nfeatures
            )
        end,
        setup = (
            T = Float64;
            nfeatures = 3;
            trees = [
                gen_random_tree_fixed_size(20, $options, nfeatures, T) for i in 1:($ntrees)
            ]
        )
    )

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
