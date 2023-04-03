using BenchmarkTools
using SymbolicRegression, BenchmarkTools, Random
using SymbolicRegression: eval_tree_array

function create_evaluation_benchmark()
    suite = BenchmarkGroup()
    extra_kws = hasfield(Options, :turbo) ? (turbo=true,) : NamedTuple()
    extra_kws = merge(
        extra_kws, hasfield(Options, :save_to_file) ? (save_to_file=false,) : NamedTuple()
    )
    options = Options(;
        binary_operators=(+, -, /, *),
        unary_operators=(cos, exp),
        verbosity=0,
        progress=false,
        define_helper_functions=false,
        extra_kws...,
    )
    simple_tree = Node(
        2,
        Node(
            1,
            Node(
                3,
                Node(1, Node(; val=1.0f0), Node(; feature=2)),
                Node(2, Node(; val=-1.0f0)),
            ),
            Node(1, Node(; feature=3), Node(; feature=4)),
        ),
        Node(
            4,
            Node(
                3,
                Node(1, Node(; val=1.0f0), Node(; feature=2)),
                Node(2, Node(; val=-1.0f0)),
            ),
            Node(1, Node(; feature=3), Node(; feature=4)),
        ),
    )
    for T in (Float32, Float64, BigFloat)
        X = T.(randn(MersenneTwister(0), Float32, 5, 1000))
        tree = convert(Node{T}, copy_node(simple_tree))
        f() = eval_tree_array(tree, X, options)
        suite[string(T)] = @benchmarkable ($f)() evals = 10 samples =
            1_000 seconds = 5.0
    end
    return suite
end

function create_search_benchmark()
    suite = BenchmarkGroup()

    n = 1000
    T = Float32

    extra_kws = hasfield(Options, :turbo) ? (turbo=true,) : NamedTuple()
    extra_kws = merge(
        extra_kws, hasfield(Options, :save_to_file) ? (save_to_file=false,) : NamedTuple()
    )
    option_kws = (;
        binary_operators=(+, -, /, *),
        unary_operators=(exp, abs),
        maxsize=30,
        verbosity=0,
        progress=false,
        deterministic=true,
        define_helper_functions=false,
        extra_kws...,
    )
    seeds = 1:3
    niterations = 100
    # We create an equation that cannot be found exactly, so the search
    # is more realistic.
    eqn(x) = Float32(cos(2.13 * x[1]) + 0.5 * x[2] * abs(x[3])^0.9 - 0.3 * abs(x[4])^1.5)
    all_options = [Options(; seed=seed, option_kws...) for seed in seeds]
    all_X = [rand(MersenneTwister(seed), T, 5, n) .* 10 .- 5 for seed in seeds]
    all_y = [
        [eqn(x) for x in eachcol(X)] .+ 0.1f0 .* randn(MersenneTwister(seed + 1), T, n) for
        (X, seed) in zip(all_X, seeds)
    ]

    for parallelism in (:serial,)
        # TODO: Add determinism for other parallelisms
        function f()
            for (options, X, y) in zip(all_options, all_X, all_y)
                EquationSearch(X, y; options, parallelism, niterations)
            end
        end
        suite[string(parallelism)] = @benchmarkable ($f)() evals = 3 samples = 3 seconds =
            10_000
    end
    return suite
end

function create_benchmark()
    suite = BenchmarkGroup()
    suite["evaluation"] = create_evaluation_benchmark()
    suite["search"] = create_search_benchmark()
    return suite
end

const SUITE = create_benchmark()
