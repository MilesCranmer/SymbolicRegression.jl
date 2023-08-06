using SymbolicRegression
import SymbolicRegression: eval_loss
using Random
using Test
include("test_params.jl")

_loss = SymbolicRegression.LossFunctionsModule._loss
_weighted_loss = SymbolicRegression.LossFunctionsModule._weighted_loss

customloss(x, y) = abs(x - y)^2.5
customloss(x, y, w) = w * (abs(x - y)^2.5)
testl1(x, y) = abs(x - y)
testl1(x, y, w) = abs(x - y) * w

for (loss_fnc, evaluator) in [(L1DistLoss(), testl1), (customloss, customloss)]
    local options = Options(;
        default_params...,
        binary_operators=(+, *, -, /),
        unary_operators=(cos, exp),
        populations=4,
        elementwise_loss=loss_fnc,
    )
    x = randn(MersenneTwister(0), Float32, 100)
    y = randn(MersenneTwister(1), Float32, 100)
    w = abs.(randn(MersenneTwister(2), Float32, 100))
    @test abs(_loss(x, y, options.elementwise_loss) - sum(evaluator.(x, y)) / length(x)) <
        1e-6
    @test abs(
        _weighted_loss(x, y, w, options.elementwise_loss) -
        sum(evaluator.(x, y, w)) / sum(w),
    ) < 1e-6
end

function custom_objective_batched(
    tree::Node{T}, dataset::Dataset{T,L}, options, ::Nothing
) where {T,L}
    return one(T)
end
function custom_objective_batched(
    tree::Node{T}, dataset::Dataset{T,L}, options, idx
) where {T,L}
    return sum(dataset.X[:, idx])
end
let options = Options(; binary_operators=[+, *], loss_function=custom_objective_batched),
    d = Dataset(randn(3, 10), randn(10))

    @test eval_loss(Node(; val=1.0), d, options) === 1.0
    @test eval_loss(Node(; val=1.0), d, options; idx=[1, 2]) == sum(d.X[:, [1, 2]])
end

custom_objective_bad_batched(tree, dataset, options) = sum(dataset.X)

let options = Options(;
        binary_operators=[+, *], loss_function=custom_objective_bad_batched, batching=true
    ),
    d = Dataset(randn(3, 10), randn(10))

    @test_throws ErrorException eval_loss(Node(; val=1.0), d, options; idx=[1, 2])
end
