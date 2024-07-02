module ExpressionBuilderModule

using DispatchDoctor: @unstable
using DynamicExpressions:
    AbstractExpressionNode,
    AbstractExpression,
    Expression,
    ParametricExpression,
    ParametricNode,
    constructorof,
    parse_expression,
    get_tree,
    get_contents,
    get_metadata,
    with_contents,
    with_metadata,
    count_constants,
    eval_tree_array
using Random: default_rng, AbstractRNG
using StatsBase: StatsBase
using ..CoreModule: Options, Dataset, DATA_TYPE, LOSS_TYPE
using ..HallOfFameModule: HallOfFame
using ..LossFunctionsModule: maybe_getindex
using ..InterfaceDynamicExpressionsModule: expected_array_type
using ..PopulationModule: Population
using ..PopMemberModule: PopMember

import DynamicExpressions: get_operators, string_tree
import ..CoreModule: create_expression
import ..MutationFunctionsModule:
    make_random_leaf, crossover_trees, mutate_constant, mutate_factor
import ..LossFunctionsModule: eval_tree_dispatch
import ..ConstantOptimizationModule: count_constants_for_optimization

@unstable function create_expression(
    t::T, options::Options, dataset::Dataset{T,L}, ::Val{embed}=Val(false)
) where {T,L,embed}
    return create_expression(
        constructorof(options.node_type)(; val=t), options, dataset, Val(embed)
    )
end
@unstable function create_expression(
    t::AbstractExpressionNode{T},
    options::Options,
    dataset::Dataset{T,L},
    ::Val{embed}=Val(false),
) where {T,L,embed}
    return constructorof(options.expression_type)(
        t; init_params(options, dataset, nothing, Val(embed))...
    )
end
function create_expression(
    ex::AbstractExpression{T}, ::Options, ::Dataset{T,L}, ::Val{embed}=Val(false)
) where {T,L,embed}
    return ex
end
@unstable function init_params(
    options::Options,
    dataset::Dataset{T,L},
    prototype::Union{Nothing,AbstractExpression},
    ::Val{embed},
) where {T,L,embed}
    return (;
        operators=embed ? options.operators : nothing,
        variable_names=embed ? dataset.variable_names : nothing,
        extra_init_params(
            options.expression_type, prototype, options, dataset, Val(embed)
        )...,
    )
end
function extra_init_params(args...)
    return (;)
end
function extra_init_params(
    ::Type{<:ParametricExpression},
    prototype::Union{Nothing,ParametricExpression},
    options,
    dataset::Dataset{T,L},
    ::Val{embed},
) where {T,L,embed}
    num_params = options.expression_options.max_parameters
    num_classes = length(unique(dataset.extra.classes))
    parameter_names = embed ? ["p$i" for i in 1:num_params] : nothing
    _parameters = if prototype === nothing
        randn(T, (num_params, num_classes))
    else
        copy(get_metadata(prototype).parameters)
    end
    return (; parameters=_parameters, parameter_names)
end

@unstable begin
    function embed_metadata(
        ex::AbstractExpression, options::Options, dataset::Dataset{T,L}
    ) where {T,L}
        return with_metadata(ex; init_params(options, dataset, ex, Val(true))...)
    end
    function embed_metadata(
        member::PopMember, options::Options, dataset::Dataset{T,L}
    ) where {T,L}
        return PopMember(
            embed_metadata(member.tree, options, dataset),
            member.score,
            member.loss,
            nothing;
            member.ref,
            member.parent,
            deterministic=options.deterministic,
        )
    end
    function embed_metadata(
        pop::Population, options::Options, dataset::Dataset{T,L}
    ) where {T,L}
        return Population(
            map(member -> embed_metadata(member, options, dataset), pop.members)
        )
    end
    function embed_metadata(
        hof::HallOfFame, options::Options, dataset::Dataset{T,L}
    ) where {T,L}
        return HallOfFame(
            map(member -> embed_metadata(member, options, dataset), hof.members), hof.exists
        )
    end
    function embed_metadata(
        vec::Vector{H}, options::Options, dataset::Dataset{T,L}
    ) where {T,L,H<:Union{HallOfFame,Population,PopMember}}
        return map(elem -> embed_metadata(elem, options, dataset), vec)
    end
end

"""Strips all metadata except for top-level information"""
function strip_metadata(ex::Expression, options::Options, dataset::Dataset{T,L}) where {T,L}
    return with_metadata(ex; init_params(options, dataset, ex, Val(false))...)
end
function strip_metadata(
    ex::ParametricExpression, options::Options, dataset::Dataset{T,L}
) where {T,L}
    return with_metadata(ex; init_params(options, dataset, ex, Val(false))...)
end
function strip_metadata(
    member::PopMember, options::Options, dataset::Dataset{T,L}
) where {T,L}
    return PopMember(
        strip_metadata(member.tree, options, dataset),
        member.score,
        member.loss,
        nothing;
        member.ref,
        member.parent,
        deterministic=options.deterministic,
    )
end
function strip_metadata(
    pop::Population, options::Options, dataset::Dataset{T,L}
) where {T,L}
    return Population(map(member -> strip_metadata(member, options, dataset), pop.members))
end
function strip_metadata(
    hof::HallOfFame, options::Options, dataset::Dataset{T,L}
) where {T,L}
    return HallOfFame(
        map(member -> strip_metadata(member, options, dataset), hof.members), hof.exists
    )
end

function eval_tree_dispatch(
    tree::ParametricExpression{T}, dataset::Dataset{T}, options::Options, idx
) where {T<:DATA_TYPE}
    A = expected_array_type(dataset.X)
    return eval_tree_array(
        tree,
        maybe_getindex(dataset.X, :, idx),
        maybe_getindex(dataset.extra.classes, idx),
        options.operators,
    )::Tuple{A,Bool}
end

function make_random_leaf(
    nfeatures::Int,
    ::Type{T},
    ::Type{N},
    rng::AbstractRNG=default_rng(),
    options::Union{Options,Nothing}=nothing,
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
        tree.parameter = rand(
            rng, UInt16(1):UInt16(options.expression_options.max_parameters)
        )
        return tree
    end
end

function crossover_trees(
    ex1::ParametricExpression{T}, ex2::AbstractExpression{T}, rng::AbstractRNG=default_rng()
) where {T}
    tree1 = get_contents(ex1)
    tree2 = get_contents(ex2)
    out1, out2 = crossover_trees(tree1, tree2, rng)
    ex1 = with_contents(ex1, out1)
    ex2 = with_contents(ex2, out2)

    # We also randomly share parameters
    nparams1 = size(ex1.metadata.parameters, 1)
    nparams2 = size(ex2.metadata.parameters, 1)
    num_params_switch = min(nparams1, nparams2)
    idx_to_switch = StatsBase.sample(
        rng, 1:num_params_switch, num_params_switch; replace=false
    )
    for param_idx in idx_to_switch
        ex2_params = ex2.metadata.parameters[param_idx, :]
        ex2.metadata.parameters[param_idx, :] .= ex1.metadata.parameters[param_idx, :]
        ex1.metadata.parameters[param_idx, :] .= ex2_params
    end

    return ex1, ex2
end

function count_constants_for_optimization(ex::ParametricExpression)
    return count_constants(get_tree(ex)) + length(ex.metadata.parameters)
end

function mutate_constant(
    ex::ParametricExpression{T},
    temperature,
    options::Options,
    rng::AbstractRNG=default_rng(),
) where {T<:DATA_TYPE}
    if rand(rng, Bool)
        # Normal mutation of inner constant
        tree = get_contents(ex)
        return with_contents(ex, mutate_constant(tree, temperature, options, rng))
    else
        # Mutate parameters
        parameter_index = rand(rng, 1:(options.expression_options.max_parameters))
        # We mutate all the parameters at once
        factor = mutate_factor(T, temperature, options, rng)
        ex.metadata.parameters[parameter_index, :] .*= factor
        return ex
    end
end

@unstable function get_operators(ex::AbstractExpression, options::Options)
    return get_operators(ex, options.operators)
end
@unstable function get_operators(ex::AbstractExpressionNode, options::Options)
    return get_operators(ex, options.operators)
end

end
