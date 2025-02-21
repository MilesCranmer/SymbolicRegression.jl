using SymbolicRegression
using Test

defs = quote
    _plus(x, y) = x + y
    _mult(x, y) = x * y
    _div(x, y) = x / y
    _min(x, y) = x - y
    _cos(x) = cos(x)
    _exp(x) = exp(x)
    early_stop(loss, c) = ((loss <= 1e-10) && (c <= 6))
    my_loss(x, y, w) = abs(x - y)^2 * w
    my_complexity(ex) = ceil(Int, length($(get_tree)(ex)) / 2)
end

# This is needed as workers are initialized in `Core.Main`!
if (@__MODULE__) != Core.Main
    Core.eval(Core.Main, defs)
    eval(
        :(using Main:
            _plus, _mult, _div, _min, _cos, _exp, early_stop, my_loss, my_complexity),
    )
else
    eval(defs)
end

X = randn(Float32, 5, 100)
y = _mult.(2, _cos.(X[4, :])) + _mult.(X[1, :], X[1, :])

options = SymbolicRegression.Options(;
    binary_operators=(_plus, _mult, _div, _min),
    unary_operators=(_cos, _exp),
    populations=20,
    maxsize=15,
    early_stop_condition=early_stop,
    elementwise_loss=my_loss,
    complexity_mapping=my_complexity,
    batching=true,
    batch_size=50,
)

hof = equation_search(
    X,
    y;
    weights=ones(Float32, 100),
    options=options,
    niterations=1_000_000_000,
    numprocs=2,
    parallelism=:multiprocessing,
)

@test any(
    early_stop(member.loss, my_complexity(member.tree)) for
    member in hof.members[hof.exists]
)
