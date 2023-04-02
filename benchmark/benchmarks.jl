using SymbolicRegression, BenchmarkTools, Random
using SymbolicRegression: eval_tree_array

const SUITE = BenchmarkGroup()

const simple_tree = Node(
    2,
    Node(
        1,
        Node(3, Node(1, Node(; val=1.0f0), Node(; feature=2)), Node(2, Node(; val=-1.0f0))),
        Node(1, Node(; feature=3), Node(; feature=4)),
    ),
    Node(
        4,
        Node(3, Node(1, Node(; val=1.0f0), Node(; feature=2)), Node(2, Node(; val=-1.0f0))),
        Node(1, Node(; feature=3), Node(; feature=4)),
    ),
)

SUITE["evaluation"] = BenchmarkGroup()
for T in (Float32, Float64, BigFloat)
    local options, tree, X
    options = Options(;
        binary_operators=(+, -, /, *),
        unary_operators=(cos, exp),
        verbosity=0,
        progress=false,
    )
    X = T.(randn(MersenneTwister(0), Float32, 5, 1000))
    tree = convert(Node{T}, copy_node(simple_tree))
    SUITE["evaluation"][string(T)] = @benchmarkable eval_tree_array($tree, $X, options) evals =
        1000
end

SUITE["search"] = BenchmarkGroup()
for parallelism in (:serial,)
    # TODO: Add determinism for other parallelisms
    function f(turbo)
        for seed in 1:3
            extra_kws = hasfield(Options, :turbo) ? (turbo=turbo,) : NamedTuple()
            local options, X, y, niterations
            niterations = 100
            options = Options(;
                binary_operators=(+, -, /, *),
                unary_operators=(exp, abs),
                maxsize=30,
                verbosity=0,
                progress=false,
                deterministic=true,
                seed=seed,
                extra_kws...,
            )
            X = rand(MersenneTwister(seed), Float32, 5, 1000) .* 10 .- 5

            # We create an equation that cannot be found exactly, so the search
            # is more realistic.
            y = @. cos(2.13 * X[1, :]) + 0.5 * X[2, :] * abs(X[3, :])^0.9 -
                0.3 * abs(X[4, :])^1.5
            # Also, add some noise:
            y .+= 0.1 .* randn(MersenneTwister(seed + 1), Float32, length(y))

            X = Float32.(X)
            y = Float32.(y)

            EquationSearch(X, y; options, parallelism, niterations)
        end
    end
    SUITE["search"][string(parallelism)] = @benchmarkable ($f)(true) evals = 10
end
