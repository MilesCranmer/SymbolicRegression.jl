using SymbolicRegression
using Test

defs = quote
    using SymbolicRegression

    early_stop(loss, c) = ((loss <= 1e-10) && (c <= 4))
    function my_loss_expression(ex::Expression, dataset::Dataset, options::Options)
        prediction, complete = eval_tree_array(ex, dataset.X, options)
        if !complete
            return Inf
        end
        return sum((prediction .- dataset.y) .^ 2) / dataset.n
    end
end

# This is needed as workers are initialized in `Core.Main`!
if (@__MODULE__) != Core.Main
    Core.eval(Core.Main, defs)
    eval(:(using Main: early_stop, my_loss_expression))
else
    eval(defs)
end

X = randn(Float32, 5, 100)
y = @. 2 * cos(X[4, :])

options = SymbolicRegression.Options(;
    binary_operators=[*, +],
    unary_operators=[cos],
    early_stop_condition=early_stop,
    loss_function_expression=my_loss_expression,
    batching=true,
    batch_size=32,
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
    early_stop(member.loss, length(get_tree(member.tree))) for
    member in hof.members[hof.exists]
)
