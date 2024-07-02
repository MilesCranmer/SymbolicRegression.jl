"""This module defines a mutation which solves for a sparse linear expansion at some node."""
module SparseLinearExpansionModule

using TestItems: @testitem

using DynamicExpressions: AbstractExpression, with_contents
using LossFunctions: L2DistLoss
using Random: AbstractRNG, default_rng

using ..CoreModule: Options, Dataset
using ..PopMemberModule: PopMember
using ..MutationFunctionsModule: gen_random_tree_fixed_size

function make_random_basis(
    rng::AbstractRNG, prototype::AbstractExpression, dataset::Dataset{T,L}, options::Options
) where {T,L}
    basis_functions = [copy(prototype) for _ in 1:128]  # TODO: Make this a parameter
    for i in eachindex(basis_functions)
        num_nodes = rand(rng, 1:5)  # TODO: Make this a parameter
        basis_functions[i] = with_contents(
            basis_functions[i],
            gen_random_tree_fixed_size(num_nodes, options, dataset.nfeatures, T, rng),
        )
    end
    return basis_functions
end

"""Sparse solver available for L2DistLoss"""
function find_sparse_linear_expression(
    rng::AbstractRNG, prototype::AbstractExpression, dataset::Dataset{T,L}, options::Options
) where {T,L}
    @assert options.elementwise_loss isa L2DistLoss && options.loss_function === nothing
    basis = make_random_basis(rng, prototype, dataset, options)
    @show basis
end
function find_sparse_linear_expression(
    prototype::AbstractExpression, dataset::Dataset, options::Options
)
    return find_sparse_linear_expression(default_rng(), prototype, dataset, options)
end

@testitem "Test random basis" begin
    using SymbolicRegression
    using SymbolicRegression.SparseLinearExpansionModule: make_random_basis
    using Random: MersenneTwister

    options = Options(; binary_operators=[+, -, *, /], unary_operators=[sin, cos])
    rng = MersenneTwister(0)
    X = randn(rng, 5, 128)
    y = @. 1.5 * X[1, :] * X[2, :] + 2.0 * X[3, :] * X[4, :] + 3.0 * X[5, :]

    ex = Expression(
        Node{Float64}(; val=1.0);
        operators=options.operators,
        variable_names=["x1", "x2", "x3", "x4", "x5"],
    )

    @show ex
end

end
