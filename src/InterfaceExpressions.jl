module InterfaceParametricExpressionModule

using DynamicExpressions:
    AbstractExpressionNode,
    AbstractExpression,
    ParametricExpression,
    ParametricNode,
    constructorof,
    parse_expression,
    get_tree,
    with_tree
using Random: default_rng, AbstractRNG
using StatsBase: StatsBase
using ..CoreModule: Options, Dataset, DATA_TYPE, LOSS_TYPE
using ..LossFunctionsModule: maybe_getindex
using ..InterfaceDynamicExpressionsModule: eval_tree_array

import ..CoreModule: create_expression
import ..MutationFunctionsModule: make_random_leaf, crossover_trees
import ..LossFunctionsModule: eval_tree_dispatch

function create_expression(t, options::Options, dataset::Dataset{T,L}) where {T,L}
    return create_expression(t, options, dataset, options.node_type, options.expression_type)
end
function create_expression(t, options::Options, ::Dataset{T,L}, ::Type{N}, ::Type{E}) where {T,L,N<:AbstractExpressionNode,E<:AbstractExpression}
    return parse_expression(t; operators=options.operators, node_type=N, expression_type=E)
end
function create_expression(t, options::Options, dataset::Dataset{T,L}, ::Type{N}, ::Type{E}) where {T,L,N<:ParametricNode,E<:ParametricExpression}
    return parse_expression(
        t;
        operators=options.operators,
        node_type=N,
        expression_type=E,
        parameter_names=["p$i" for i in 1:options.expression_options.max_parameters],
        parameters=randn(T, (options.expression_options.max_parameters, only(size(dataset.extra.classes))))
    )
end
function eval_tree_dispatch(tree::ParametricExpression{T}, dataset::Dataset{T}, options::Options, idx) where {T<:DATA_TYPE}
    return eval_tree_array(
        tree,
        maybe_getindex(dataset.X, :, idx),
        maybe_getindex(dataset.extra.classes, idx),
        options.operators,
    )
end

function make_random_leaf(
    nfeatures::Int, ::Type{T}, ::Type{N}, rng::AbstractRNG=default_rng(), options::Union{Options,Nothing}=nothing
) where {T<:DATA_TYPE,N<:ParametricNode}
    choice = rand(rng, 1:3)
    if choice == 1
        return ParametricNode(; val=randn(rng, T))
    elseif choice == 2
        return ParametricNode(T; feature=rand(rng, 1:nfeatures))
    else
        tree = ParametricNode{T}()
        tree.val = zero(T)
        tree.degree = 0
        tree.feature = 0
        tree.constant = false
        tree.is_parameter = true
        tree.parameter = rand(rng, UInt16(1):UInt16(options.expression_options.max_parameters))
        return tree
    end
end

function crossover_trees(
    ex1::ParametricExpression{T}, ex2::AbstractExpression{T}, rng::AbstractRNG=default_rng()
) where {T}
    tree1 = get_tree(ex1)
    tree2 = get_tree(ex2)
    out1, out2 = crossover_trees(tree1, tree2, rng)
    ex1 = with_tree(ex1, out1)
    ex2 = with_tree(ex2, out2)

    # We also randomly share parameters
    nparams1 = size(ex1.metadata.parameters, 1)
    nparams2 = size(ex2.metadata.parameters, 1)
    num_params_switch = min(nparams1, nparams2)
    idx_to_switch = StatsBase.sample(rng, 1:num_params_switch, num_params_switch; replace=false)
    for param_idx in idx_to_switch
        ex2_params = ex2.metadata.parameters[param_idx, :]
        ex2.metadata.parameters[param_idx, :] .= ex1.metadata.parameters[param_idx, :]
        ex1.metadata.parameters[param_idx, :] .= ex2_params
    end

    return ex1, ex2
end

end