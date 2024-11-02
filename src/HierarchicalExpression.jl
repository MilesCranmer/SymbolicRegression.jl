module HierarchicalExpressionModule

using Random: AbstractRNG
using Compat: Fix
using DispatchDoctor: @unstable
using StyledStrings: @styled_str, annotatedstring
using DynamicExpressions:
    DynamicExpressions as DE,
    AbstractStructuredExpression,
    AbstractExpressionNode,
    AbstractExpression,
    AbstractOperatorEnum,
    OperatorEnum,
    Expression,
    Metadata,
    get_contents,
    with_contents,
    get_metadata,
    get_operators,
    get_variable_names,
    get_tree,
    node_type,
    eval_tree_array,
    count_nodes
using DynamicExpressions.InterfacesModule:
    ExpressionInterface, Interfaces, @implements, all_ei_methods_except, Arguments

using ..CoreModule:
    AbstractOptions, Dataset, CoreModule as CM, AbstractMutationWeights, has_units
using ..ConstantOptimizationModule: ConstantOptimizationModule as CO
using ..InterfaceDynamicExpressionsModule: InterfaceDynamicExpressionsModule as IDE
using ..MutationFunctionsModule: MutationFunctionsModule as MF
using ..ExpressionBuilderModule: ExpressionBuilderModule as EB
using ..DimensionalAnalysisModule: DimensionalAnalysisModule as DA
using ..CheckConstraintsModule: CheckConstraintsModule as CC
using ..ComplexityModule: ComplexityModule
using ..LossFunctionsModule: LossFunctionsModule as LF
using ..MutateModule: MutateModule as MM
using ..PopMemberModule: PopMember
using ..ComposableExpressionModule: ComposableExpression, VectorWrapper

"""
    HierarchicalStructure{K,S,N,E,C} <: Function

A struct that defines a prescribed structure for a `HierarchicalExpression`,
including functions that define the result in different contexts.

The `K` parameter is used to specify the symbols representing the inner expressions.
If not declared using the constructor `HierarchicalStructure{K}(...)`, the keys of the
`variable_constraints` `NamedTuple` will be used to infer this.

# Fields
- `combine`: Required function taking a `NamedTuple` of function keys => expressions,
    returning a single expression. Fallback method used by `get_tree`
    on a `HierarchicalExpression` to generate a single `Expression`.
"""
struct HierarchicalStructure{K,E<:Function} <: Function
    combine::E
end

function HierarchicalStructure{K}(combine::E) where {K,E<:Function}
    return HierarchicalStructure{K,E}(combine)
end

function combine(template::HierarchicalStructure, args...)
    return template.combine(args...)
end

get_function_keys(::HierarchicalStructure{K}) where {K} = K

"""
    HierarchicalExpression{T,F,N,E,TS,D} <: AbstractStructuredExpression{T,F,N,E,D}

A symbolic expression that allows the combination of multiple sub-expressions
in a structured way, with constraints on variable usage.

`HierarchicalExpression` is designed for symbolic regression tasks where
domain-specific knowledge or constraints must be imposed on the model's structure.

# Constructor

- `HierarchicalExpression(trees; structure, operators, variable_names)`
    - `trees`: A `NamedTuple` holding the sub-expressions (e.g., `f = Expression(...)`, `g = Expression(...)`).
    - `structure`: A `HierarchicalStructure` which holds functions that define how the sub-expressions are combined
        in different contexts.
    - `operators`: An `OperatorEnum` that defines the allowed operators for the sub-expressions.
    - `variable_names`: An optional `Vector` of `String` that defines the names of the variables in the dataset.

# Example

Let's create an example `HierarchicalExpression` that combines two sub-expressions `f(x1, x2)` and `g(x3)`:

```julia
# Define operators and variable names
options = Options(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
operators = options.operators
variable_names = ["x1", "x2", "x3"]

# Create sub-expressions
x1 = Expression(Node{Float64}(; feature=1); operators, variable_names)
x2 = Expression(Node{Float64}(; feature=2); operators, variable_names)
x3 = Expression(Node{Float64}(; feature=3); operators, variable_names)

# Create HierarchicalExpression
example_expr = (; f=x1, g=x3)
st_expr = HierarchicalExpression(
    example_expr;
    structure=HierarchicalStructure{(:f, :g)}(
        ((; f, g), (x1, x2, x3)) -> sin(f(x1, x2)) + g(x3)^2
    ),
    operators,
    variable_names,
)
```

When fitting a model in SymbolicRegression.jl, you would provide the `HierarchicalExpression`
as the `expression_type` argument, and then pass `expression_options=(; structure=HierarchicalStructure(...))`
as additional options. The `variable_constraints` will constraint `f` to only have access to `x1` and `x2`,
and `g` to only have access to `x3`.
"""
struct HierarchicalExpression{
    T,
    F<:HierarchicalStructure,
    N<:AbstractExpressionNode{T},
    E<:ComposableExpression{T,N},
    TS<:NamedTuple{<:Any,<:NTuple{<:Any,E}},
    D<:@NamedTuple{
        structure::F, operators::O, variable_names::V
    } where {O<:AbstractOperatorEnum,V},
} <: AbstractStructuredExpression{T,F,N,E,D}
    trees::TS
    metadata::Metadata{D}

    function HierarchicalExpression(
        trees::TS, metadata::Metadata{D}
    ) where {
        TS,
        F<:HierarchicalStructure,
        D<:@NamedTuple{structure::F, operators::O, variable_names::V} where {O,V},
    }
        @assert keys(trees) == get_function_keys(metadata.structure)
        E = typeof(first(values(trees)))
        N = node_type(E)
        return new{eltype(N),F,N,E,TS,D}(trees, metadata)
    end
end

function HierarchicalExpression(
    trees::NamedTuple{<:Any,<:NTuple{<:Any,<:AbstractExpression}};
    structure::F,
    operators::Union{AbstractOperatorEnum,Nothing}=nothing,
    variable_names::Union{AbstractVector{<:AbstractString},Nothing}=nothing,
) where {F<:HierarchicalStructure}
    example_tree = first(values(trees))::AbstractExpression
    operators = get_operators(example_tree, operators)
    variable_names = get_variable_names(example_tree, variable_names)
    metadata = (; structure, operators, variable_names)
    return HierarchicalExpression(trees, Metadata(metadata))
end

@unstable DE.constructorof(::Type{<:HierarchicalExpression}) = HierarchicalExpression

@implements(
    ExpressionInterface{all_ei_methods_except(())}, HierarchicalExpression, [Arguments()]
)

function combine(ex::HierarchicalExpression, args...)
    return combine(get_metadata(ex).structure, args...)
end
function get_function_keys(ex::HierarchicalExpression)
    return get_function_keys(get_metadata(ex).structure)
end

function EB.create_expression(
    t::AbstractExpressionNode{T},
    options::AbstractOptions,
    dataset::Dataset{T,L},
    ::Type{<:AbstractExpressionNode},
    ::Type{E},
    ::Val{embed}=Val(false),
) where {T,L,embed,E<:HierarchicalExpression}
    function_keys = get_function_keys(options.expression_options.structure)

    # NOTE: We need to copy over the operators so we can call the structure function
    operators = options.operators
    variable_names = embed ? dataset.variable_names : nothing
    inner_expressions = ntuple(
        _ -> ComposableExpression(copy(t); operators, variable_names),
        Val(length(function_keys)),
    )
    # TODO: Generalize to other inner expression types
    return DE.constructorof(E)(
        NamedTuple{function_keys}(inner_expressions);
        EB.init_params(options, dataset, nothing, Val(embed))...,
    )
end
function EB.extra_init_params(
    ::Type{E},
    prototype::Union{Nothing,AbstractExpression},
    options::AbstractOptions,
    dataset::Dataset{T},
    ::Val{embed},
) where {T,embed,E<:HierarchicalExpression}
    # We also need to include the operators here to be consistent with `create_expression`.
    return (; options.operators, options.expression_options...)
end
function EB.sort_params(params::NamedTuple, ::Type{<:HierarchicalExpression})
    return (; params.structure, params.operators, params.variable_names)
end

function ComplexityModule.compute_complexity(
    tree::HierarchicalExpression, options::AbstractOptions; break_sharing=Val(false)
)
    # Rather than including the complexity of the combined tree,
    # we only sum the complexity of each inner expression, which will be smaller.
    return sum(
        ex -> ComplexityModule.compute_complexity(ex, options; break_sharing),
        values(get_contents(tree)),
    )
end

_color_string(s::AbstractString, c::Symbol) = styled"{$c:$s}"
function DE.string_tree(
    tree::HierarchicalExpression,
    operators::Union{AbstractOperatorEnum,Nothing}=nothing;
    kws...,
)
    raw_contents = get_contents(tree)
    function_keys = keys(raw_contents)
    colors = Base.Iterators.cycle((:magenta, :green, :red, :blue, :yellow, :cyan))
    inner_strings = NamedTuple{function_keys}(
        map(ex -> DE.string_tree(ex, operators; kws...), values(raw_contents))
    )
    colored_strings = NamedTuple{function_keys}(map(_color_string, inner_strings, colors))
    return join(
        (annotatedstring(k, " = ", v) for (k, v) in pairs(colored_strings)), styled"\n"
    )
end
function DE.eval_tree_array(
    tree::HierarchicalExpression{T},
    cX::AbstractMatrix{T},
    operators::Union{AbstractOperatorEnum,Nothing}=nothing;
    kws...,
) where {T}
    raw_contents = get_contents(tree)
    result = combine(
        tree, raw_contents, map(x -> VectorWrapper(copy(x), true), eachrow(cX))
    )
    return result.value, result.valid
end
function (ex::HierarchicalExpression)(
    X, operators::Union{AbstractOperatorEnum,Nothing}=nothing; kws...
)
    result, valid = DE.eval_tree_array(ex, X, operators; kws...)
    if valid
        return result
    else
        nan = convert(eltype(result), NaN)
        return result .* nan
    end
end
@unstable IDE.expected_array_type(::AbstractMatrix, ::Type{<:HierarchicalExpression}) = Any

function DA.violates_dimensional_constraints(
    @nospecialize(tree::HierarchicalExpression),
    dataset::Dataset,
    @nospecialize(options::AbstractOptions)
)
    @assert !has_units(dataset)
    return false
end
function MM.condition_mutation_weights!(
    @nospecialize(weights::AbstractMutationWeights),
    @nospecialize(member::P),
    @nospecialize(options::AbstractOptions),
    curmaxsize::Int,
) where {T,L,N<:HierarchicalExpression,P<:PopMember{T,L,N}}
    # HACK TODO
    return nothing
end

"""
We need full specialization for constrained expressions, as they rely on subexpressions being combined.
"""
function CM.operator_specialization(
    ::Type{O}, ::Type{<:HierarchicalExpression}
) where {O<:OperatorEnum}
    return O
end

"""
We pick a random subexpression to mutate,
and also return the symbol we mutated on so that we can put it back together later.
"""
function MF.get_contents_for_mutation(ex::HierarchicalExpression, rng::AbstractRNG)
    raw_contents = get_contents(ex)
    function_keys = keys(raw_contents)

    # Sample weighted by number of nodes in each subexpression
    num_nodes = map(count_nodes, values(raw_contents))
    weights = map(Base.Fix2(/, sum(num_nodes)), num_nodes)
    cumsum_weights = cumsum(weights)
    rand_val = rand(rng)
    idx = findfirst(Base.Fix2(>=, rand_val), cumsum_weights)::Int

    key_to_mutate = function_keys[idx]
    return raw_contents[key_to_mutate], key_to_mutate
end

"""See `get_contents_for_mutation(::HierarchicalExpression, ::AbstractRNG)`."""
function MF.with_contents_for_mutation(
    ex::HierarchicalExpression, new_inner_contents, context::Symbol
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

"""We combine the operators of each inner expression."""
function DE.combine_operators(
    ex::HierarchicalExpression{T,N}, operators::Union{AbstractOperatorEnum,Nothing}=nothing
) where {T,N}
    raw_contents = get_contents(ex)
    function_keys = keys(raw_contents)
    new_contents = NamedTuple{function_keys}(
        map(Base.Fix2(DE.combine_operators, operators), values(raw_contents))
    )
    return with_contents(ex, new_contents)
end

"""We simplify each inner expression."""
function DE.simplify_tree!(
    ex::HierarchicalExpression{T,N}, operators::Union{AbstractOperatorEnum,Nothing}=nothing
) where {T,N}
    raw_contents = get_contents(ex)
    function_keys = keys(raw_contents)
    new_contents = NamedTuple{function_keys}(
        map(Base.Fix2(DE.simplify_tree!, operators), values(raw_contents))
    )
    return with_contents(ex, new_contents)
end

function CO.count_constants_for_optimization(ex::HierarchicalExpression)
    return sum(CO.count_constants_for_optimization, values(get_contents(ex)))
end

# function CC.check_constraints(
#     ex::HierarchicalExpression,
#     options::AbstractOptions,
#     maxsize::Int,
#     cursize::Union{Int,Nothing}=nothing,
# )::Bool
#     raw_contents = get_contents(ex)
#     variable_constraints = get_metadata(ex).structure.variable_constraints

#     # First, we check the variable constraints at the top level:
#     has_invalid_variables = any(keys(raw_contents)) do key
#         tree = raw_contents[key]
#         allowed_variables = variable_constraints[key]
#         contains_other_features_than(tree, allowed_variables)
#     end
#     if has_invalid_variables
#         return false
#     end

#     # We also check the combined complexity:
#     ((cursize === nothing) ? ComplexityModule.compute_complexity(ex, options) : cursize) >
#     maxsize && return false

#     # Then, we check other constraints for inner expressions:
#     for t in values(raw_contents)
#         if !CC.check_constraints(t, options, maxsize, nothing)
#             return false
#         end
#     end
#     return true
#     # TODO: The concept of `cursize` doesn't really make sense here.
# end
# function contains_other_features_than(tree::AbstractExpression, features)
#     return contains_other_features_than(get_tree(tree), features)
# end
# function contains_other_features_than(tree::AbstractExpressionNode, features)
#     any(tree) do node
#         node.degree == 0 && !node.constant && node.feature ∉ features
#     end
# end

# TODO: Add custom behavior to adjust what feature nodes can be generated

end
