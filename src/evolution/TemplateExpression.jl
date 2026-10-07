module TemplateExpressionEvolutionModule

using Random: AbstractRNG, default_rng
using StatsBase: StatsBase
using DynamicExpressions.ExpressionModule: _copy
using DynamicExpressions:
    DynamicExpressions as DE,
    get_contents,
    get_metadata,
    with_contents,
    with_metadata,
    preserve_sharing
using ...InterfacesModule: AbstractOptions, Dataset, DATA_TYPE, ConstantMutation
using ...ExpressionsModule: TemplateExpression, ParamVector, has_params
using ...ExpressionsModule.TemplateExpressionModule: TemplateOptimizableRefs, has_constants
using ...ExpressionsModule: AbstractComposableExpression
using ...EvaluationModule: ComplexityModule
using ..ConstantOptimizationModule: ConstantOptimizationModule as CO
using ..MutationFunctionsModule: MutationFunctionsModule as MF
using ..HallOfFameModule: HallOfFameModule as HOF
using ..MutateModule: MutateModule as MM
using ..PopMemberModule: AbstractPopMember

function CO.get_optimizable_parameters(e::TemplateExpression, options)
    combiner = get_metadata(e).structure.combine
    return CO.get_optimizable_parameters(combiner, e, options)
end
function CO.get_optimizable_parameters(_context, e::TemplateExpression, _options)
    parameters, scalar_refs = DE.get_scalar_constants(e)
    return parameters, TemplateOptimizableRefs(scalar_refs, length(parameters))
end
function CO.set_optimizable_parameters!(
    e::TemplateExpression, parameters, refs::TemplateOptimizableRefs
)
    length(parameters) == refs.length || throw(
        DimensionMismatch(
            "received $(length(parameters)) optimizable parameters but expected $(refs.length)",
        ),
    )
    return DE.set_scalar_constants!(e, parameters, refs.scalar_refs)
end
function CO.extract_optimizable_gradient(
    grad, e::TemplateExpression, _refs::TemplateOptimizableRefs
)
    return DE.extract_gradient(grad, e)
end

function HOF.make_prefix(::TemplateExpression, ::AbstractOptions, ::Dataset)
    return ""
end

function MM.condition_mutation_weights!(
    weights::AbstractVector,
    @nospecialize(member::P),
    @nospecialize(options::AbstractOptions),
    curmaxsize::Int,
    nfeatures::Int,
) where {T,L,N<:TemplateExpression,P<:AbstractPopMember{T,L,N}}
    if !preserve_sharing(typeof(member.tree))
        MM._set_weight!(weights, MM.FormConnectionMutation, 0.0)
        MM._set_weight!(weights, MM.BreakConnectionMutation, 0.0)
    end

    MM.condition_mutate_constant!(typeof(member.tree), weights, member, options, curmaxsize)

    if nfeatures <= 1
        MM._set_weight!(weights, MM.FeatureMutation, 0.0)
    end

    complexity = ComplexityModule.compute_complexity(member, options)

    if complexity >= curmaxsize
        MM._set_weight!(weights, MM.AddNodeMutation, 0.0)
        MM._set_weight!(weights, MM.InsertNodeMutation, 0.0)
    end

    if !options.should_simplify
        MM._set_weight!(weights, MM.SimplifyMutation, 0.0)
    end
    return nothing
end

"""
We pick a random subexpression to mutate,
and also return the symbol we mutated on so that we can put it back together later.
"""
function MF.get_contents_for_mutation(ex::TemplateExpression, rng::AbstractRNG)
    raw_contents = get_contents(ex)
    function_keys = keys(raw_contents)

    key_to_mutate = rand(rng, function_keys)
    return raw_contents[key_to_mutate], key_to_mutate
end

function _crossover_template_inners(
    ex1::E, ex2::E, rng::AbstractRNG
) where {E<:AbstractComposableExpression}
    return MF.crossover_trees(copy(ex1), copy(ex2), rng)
end

function _template_crossover_child(
    ex::TemplateExpression, crossed_inner::AbstractComposableExpression, context::Symbol
)
    raw_contents = get_contents(ex)
    raw_contents_keys = keys(raw_contents)
    new_contents = NamedTuple{raw_contents_keys}(
        ntuple(length(raw_contents_keys)) do i
            key = raw_contents_keys[i]
            return key == context ? crossed_inner : copy(raw_contents[key])
        end,
    )
    new_parameters = _copy(get_metadata(ex).parameters::NamedTuple)
    return with_metadata(with_contents(ex, new_contents); parameters=new_parameters)
end

function MF.crossover_trees(
    ex1::E, ex2::E, rng::AbstractRNG=default_rng()
) where {E<:TemplateExpression}
    ex1 === ex2 && error("Attempted to crossover the same expression!")
    inner1, context1 = MF.get_contents_for_mutation(ex1, rng)
    inner2, context2 = MF.get_contents_for_mutation(ex2, rng)
    crossed1, crossed2 = _crossover_template_inners(inner1, inner2, rng)
    child1 = _template_crossover_child(ex1, crossed1, context1)
    child2 = _template_crossover_child(ex2, crossed2, context2)
    return child1, child2
end

"""See `get_contents_for_mutation(::TemplateExpression, ::AbstractRNG)`."""
function MF.with_contents_for_mutation(
    ex::TemplateExpression, new_inner_contents, context::Symbol
)
    raw_contents = get_contents(ex)
    raw_contents_keys = keys(raw_contents)
    new_contents = NamedTuple{raw_contents_keys}(
        ntuple(length(raw_contents_keys)) do i
            if raw_contents_keys[i] == context
                new_inner_contents
            else
                raw_contents[raw_contents_keys[i]]
            end
        end,
    )
    return with_contents(ex, new_contents)
end

"""We only want to mutate to a valid number of features."""
function MF.get_nfeatures_for_mutation(ex::TemplateExpression, ctx::Symbol, _::Int)
    return get_metadata(ex).structure.num_features[ctx]
end

function MM.condition_mutate_constant!(
    ::Type{<:TemplateExpression},
    weights::AbstractVector,
    member::AbstractPopMember,
    options::AbstractOptions,
    curmaxsize::Int,
)
    # Avoid modifying the mutate_constant weight, since
    # otherwise we would be mutating constants all the time!
    return nothing
end

function MF.mutate_constant(
    ex::TemplateExpression{T},
    temperature,
    options::AbstractOptions,
    m::ConstantMutation=ConstantMutation(),
    rng::AbstractRNG=default_rng(),
) where {T<:DATA_TYPE}
    regular_constant_mutation = !has_params(ex) || (has_constants(ex) && rand(rng, Bool))
    if regular_constant_mutation
        # Normal mutation of inner constant
        tree, context = MF.get_contents_for_mutation(ex, rng)
        new_tree = MF.mutate_constant(tree, temperature, options, m, rng)
        return MF.with_contents_for_mutation(ex, new_tree, context)
    else # Mutate parameters

        # We mutate between 1 and all of the parameter vector
        key_to_mutate = rand(rng, keys(get_metadata(ex).parameters))
        num_params = get_metadata(ex).structure.num_parameters[key_to_mutate]::Integer
        num_params_to_mutate = rand(rng, 1:num_params)
        # TODO: I feel we should mutate all keys at once, and only randomize which
        # parameters (of the combined list) to mutate.

        idx_to_mutate = StatsBase.sample(
            rng, 1:num_params, num_params_to_mutate; replace=false
        )
        parameters = get_metadata(ex).parameters[key_to_mutate]::ParamVector
        @inbounds for i in idx_to_mutate
            parameters._data[i] = MF._mutate_value(
                rng, parameters._data[i], temperature, m, options
            )
        end
        return ex
    end
end

end
