module TemplateExpressionModule

using Random: AbstractRNG
using Compat: Fix
using DispatchDoctor: @unstable, @stable
using StyledStrings: @styled_str, annotatedstring
using DynamicExpressions:
    DynamicExpressions as DE,
    AbstractStructuredExpression,
    AbstractExpressionNode,
    AbstractExpression,
    AbstractOperatorEnum,
    OperatorEnum,
    Metadata,
    get_contents,
    with_contents,
    get_metadata,
    get_operators,
    get_variable_names,
    get_tree,
    node_type,
    count_nodes
using DynamicExpressions.InterfacesModule:
    ExpressionInterface, Interfaces, @implements, all_ei_methods_except, Arguments

using ..CoreModule:
    AbstractOptions, Options, Dataset, CoreModule as CM, AbstractMutationWeights, has_units
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
using ..ComposableExpressionModule: ComposableExpression, ValidVector

"""
    TemplateStructure{K,E,NF} <: Function

A struct that defines a prescribed structure for a `TemplateExpression`,
including functions that define the result in different contexts.

The `K` parameter is used to specify the symbols representing the inner expressions.
If not declared using the constructor `TemplateStructure{K}(...)`, the keys of the
`variable_constraints` `NamedTuple` will be used to infer this.

# Fields
- `combine`: Required function taking a `NamedTuple` of `ComposableExpression`s (sharing the keys `K`),
    and then tuple representing the data of `ValidVector`s. For example,
    `((; f, g), (x1, x2, x3)) -> f(x1, x2) + g(x3)` would be a valid `combine` function. You may also
    re-use the callable expressions and use different inputs, such as
    `((; f, g), (x1, x2)) -> f(x1 + g(x2)) - g(x1)` is another valid choice.
- `num_features`: Optional `NamedTuple` of function keys => integers representing the number of
    features used by each expression. If not provided, it will be inferred using the `combine`
    function. For example, if `f` takes two arguments, and `g` takes one, then
    `num_features = (; f=2, g=1)`.
"""
struct TemplateStructure{K,E<:Function,NF<:NamedTuple{K}} <: Function
    combine::E
    num_features::NF
end

function TemplateStructure{K}(combine::E, num_features=nothing) where {K,E<:Function}
    num_features = @something(num_features, infer_variable_constraints(Val(K), combine))
    return TemplateStructure{K,E,typeof(num_features)}(combine, num_features)
end

@unstable function combine(template::TemplateStructure, args...)
    return template.combine(args...)
end

get_function_keys(::TemplateStructure{K}) where {K} = K

function _record_composable_expression!(variable_constraints, ::Val{k}, args...) where {k}
    vc = variable_constraints[k][]
    if vc == -1
        variable_constraints[k][] = length(args)
    elseif vc != length(args)
        throw(ArgumentError("Inconsistent number of arguments passed to $k"))
    end
    return first(args)
end

"""Infers number of features used by each subexpression, by passing in test data."""
function infer_variable_constraints(::Val{K}, combiner::F) where {K,F}
    variable_constraints = NamedTuple{K}(map(_ -> Ref(-1), K))
    # Now, we need to evaluate the `combine` function to see how many
    # features are used for each function call. If unset, we record it.
    # If set, we validate.
    inner = Fix{1}(_record_composable_expression!, variable_constraints)
    _recorders_of_composable_expressions = NamedTuple{K}(map(k -> Fix{1}(inner, Val(k)), K))
    # We use an evaluation to get the variable constraints
    combiner(
        _recorders_of_composable_expressions,
        Base.Iterators.repeated(ValidVector(ones(Float64, 1), true)),
    )
    inferred = NamedTuple{K}(map(x -> x[], values(variable_constraints)))
    if any(==(-1), values(inferred))
        failed_keys = filter(k -> inferred[k] == -1, K)
        throw(ArgumentError("Failed to infer number of features used by $failed_keys"))
    end
    return inferred
end

"""
    TemplateExpression{T,F,N,E,TS,D} <: AbstractStructuredExpression{T,F,N,E,D}

A symbolic expression that allows the combination of multiple sub-expressions
in a structured way, with constraints on variable usage.

`TemplateExpression` is designed for symbolic regression tasks where
domain-specific knowledge or constraints must be imposed on the model's structure.

# Constructor

- `TemplateExpression(trees; structure, operators, variable_names)`
    - `trees`: A `NamedTuple` holding the sub-expressions (e.g., `f = Expression(...)`, `g = Expression(...)`).
    - `structure`: A `TemplateStructure` which holds functions that define how the sub-expressions are combined
        in different contexts.
    - `operators`: An `OperatorEnum` that defines the allowed operators for the sub-expressions.
    - `variable_names`: An optional `Vector` of `String` that defines the names of the variables in the dataset.

# Example

Let's create an example `TemplateExpression` that combines two sub-expressions `f(x1, x2)` and `g(x3)`:

```julia
# Define operators and variable names
options = Options(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
operators = options.operators
variable_names = ["x1", "x2", "x3"]

# Create sub-expressions
x1 = Expression(Node{Float64}(; feature=1); operators, variable_names)
x2 = Expression(Node{Float64}(; feature=2); operators, variable_names)
x3 = Expression(Node{Float64}(; feature=3); operators, variable_names)

# Create TemplateExpression
example_expr = (; f=x1, g=x3)
st_expr = TemplateExpression(
    example_expr;
    structure=TemplateStructure{(:f, :g)}(
        ((; f, g), (x1, x2, x3)) -> sin(f(x1, x2)) + g(x3)^2
    ),
    operators,
    variable_names,
)
```

When fitting a model in SymbolicRegression.jl, you would provide the `TemplateExpression`
as the `expression_type` argument, and then pass `expression_options=(; structure=TemplateStructure(...))`
as additional options. The `variable_constraints` will constraint `f` to only have access to `x1` and `x2`,
and `g` to only have access to `x3`.
"""
struct TemplateExpression{
    T,
    F<:TemplateStructure,
    N<:AbstractExpressionNode{T},
    E<:ComposableExpression{T,N},
    TS<:NamedTuple{<:Any,<:NTuple{<:Any,E}},
    D<:@NamedTuple{
        structure::F, operators::O, variable_names::V
    } where {O<:AbstractOperatorEnum,V},
} <: AbstractStructuredExpression{T,F,N,E,D}
    trees::TS
    metadata::Metadata{D}

    function TemplateExpression(
        trees::TS, metadata::Metadata{D}
    ) where {
        TS,
        F<:TemplateStructure,
        D<:@NamedTuple{structure::F, operators::O, variable_names::V} where {O,V},
    }
        @assert keys(trees) == get_function_keys(metadata.structure)
        E = typeof(first(values(trees)))
        N = node_type(E)
        return new{eltype(N),F,N,E,TS,D}(trees, metadata)
    end
end

function TemplateExpression(
    trees::NamedTuple{<:Any,<:NTuple{<:Any,<:AbstractExpression}};
    structure::F,
    operators::Union{AbstractOperatorEnum,Nothing}=nothing,
    variable_names::Union{AbstractVector{<:AbstractString},Nothing}=nothing,
) where {F<:TemplateStructure}
    example_tree = first(values(trees))::AbstractExpression
    operators = get_operators(example_tree, operators)
    variable_names = get_variable_names(example_tree, variable_names)
    metadata = (; structure, operators, variable_names)
    return TemplateExpression(trees, Metadata(metadata))
end

@unstable DE.constructorof(::Type{<:TemplateExpression}) = TemplateExpression

@implements(
    ExpressionInterface{all_ei_methods_except(())}, TemplateExpression, [Arguments()]
)

@unstable function combine(ex::TemplateExpression, args...)
    return combine(get_metadata(ex).structure, args...)
end

function DE.get_tree(ex::TemplateExpression{<:Any,<:Any,<:Any,E}) where {E}
    raw_contents = get_contents(ex)
    total_num_features = max(values(get_metadata(ex).structure.num_features)...)
    example_inner_ex = first(values(raw_contents))
    example_tree = get_contents(example_inner_ex)::AbstractExpressionNode

    variable_trees = [
        DE.constructorof(typeof(example_tree))(; feature=i) for i in 1:total_num_features
    ]
    variable_expressions = [
        with_contents(inner_ex, variable_tree) for
        (inner_ex, variable_tree) in zip(values(raw_contents), variable_trees)
    ]

    return DE.get_tree(
        combine(get_metadata(ex).structure, raw_contents, variable_expressions)
    )
end

function EB.create_expression(
    t::AbstractExpressionNode{T},
    options::AbstractOptions,
    dataset::Dataset{T,L},
    ::Type{<:AbstractExpressionNode},
    ::Type{E},
    ::Val{embed}=Val(false),
) where {T,L,embed,E<:TemplateExpression}
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
) where {T,embed,E<:TemplateExpression}
    # We also need to include the operators here to be consistent with `create_expression`.
    return (; options.operators, options.expression_options...)
end
function EB.sort_params(params::NamedTuple, ::Type{<:TemplateExpression})
    return (; params.structure, params.operators, params.variable_names)
end

function ComplexityModule.compute_complexity(
    tree::TemplateExpression, options::AbstractOptions; break_sharing=Val(false)
)
    # Rather than including the complexity of the combined tree,
    # we only sum the complexity of each inner expression, which will be smaller.
    return sum(
        ex -> ComplexityModule.compute_complexity(ex, options; break_sharing),
        values(get_contents(tree)),
    )
end

# Rather than using iterator with repeat, just make a tuple:
function _colors(::Val{n}) where {n}
    return ntuple(
        (i -> (:magenta, :green, :red, :blue, :yellow, :cyan)[mod1(i, n)]), Val(n)
    )
end

_color_string(s::AbstractString, c::Symbol) = styled"{$c:$s}"
function DE.string_tree(
    tree::TemplateExpression,
    operators::Union{AbstractOperatorEnum,Nothing}=nothing;
    pretty::Bool=false,
    variable_names=nothing,
    kws...,
)
    raw_contents = get_contents(tree)
    function_keys = keys(raw_contents)
    num_features = get_metadata(tree).structure.num_features
    total_num_features = max(values(num_features)...)
    colors = _colors(Val(length(function_keys)))
    variable_names = ["#" * string(i) for i in 1:total_num_features]
    inner_strings = NamedTuple{function_keys}(
        map(
            ex -> DE.string_tree(ex, operators; pretty, variable_names, kws...),
            values(raw_contents),
        ),
    )
    strings = NamedTuple{function_keys}(
        map(
            (k, s, c) -> let
                prefix = if !pretty || length(function_keys) == 1
                    ""
                elseif k == first(function_keys)
                    "╭ "
                elseif k == last(function_keys)
                    "╰ "
                else
                    "├ "
                end
                annotatedstring(prefix * string(k) * " = ", _color_string(s, c))
            end,
            function_keys,
            values(inner_strings),
            colors,
        ),
    )
    return annotatedstring(join(strings, pretty ? styled"\n" : "; "))
end
@stable(
    default_mode = "disable",
    default_union_limit = 2,
    begin
        function DE.eval_tree_array(
            tree::TemplateExpression{T},
            cX::AbstractMatrix{T},
            operators::Union{AbstractOperatorEnum,Nothing}=nothing;
            kws...,
        ) where {T}
            raw_contents = get_contents(tree)
            if has_invalid_variables(tree)
                return (nothing, false)
            end
            result = combine(
                tree, raw_contents, map(x -> ValidVector(copy(x), true), eachrow(cX))
            )
            return result.x, result.valid
        end
        function (ex::TemplateExpression)(
            X, operators::Union{AbstractOperatorEnum,Nothing}=nothing; kws...
        )
            result, valid = DE.eval_tree_array(ex, X, operators; kws...)
            if valid
                return result
            else
                return nothing
            end
        end
    end
)
@unstable IDE.expected_array_type(::AbstractMatrix, ::Type{<:TemplateExpression}) = Any

function DA.violates_dimensional_constraints(
    @nospecialize(tree::TemplateExpression),
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
) where {T,L,N<:TemplateExpression,P<:PopMember{T,L,N}}
    # HACK TODO
    return nothing
end

"""
We need full specialization for constrained expressions, as they rely on subexpressions being combined.
"""
function CM.operator_specialization(
    ::Type{O}, ::Type{<:TemplateExpression}
) where {O<:OperatorEnum}
    return O
end

function CM.max_features(
    dataset::Dataset, options::Options{<:Any,<:Any,<:Any,<:TemplateExpression}
)
    num_features = options.expression_options.structure.num_features
    return max(values(num_features)...)
end

"""
We pick a random subexpression to mutate,
and also return the symbol we mutated on so that we can put it back together later.
"""
function MF.get_contents_for_mutation(ex::TemplateExpression, rng::AbstractRNG)
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

"""We combine the operators of each inner expression."""
function DE.combine_operators(
    ex::TemplateExpression{T,N}, operators::Union{AbstractOperatorEnum,Nothing}=nothing
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
    ex::TemplateExpression{T,N}, operators::Union{AbstractOperatorEnum,Nothing}=nothing
) where {T,N}
    raw_contents = get_contents(ex)
    function_keys = keys(raw_contents)
    new_contents = NamedTuple{function_keys}(
        map(Base.Fix2(DE.simplify_tree!, operators), values(raw_contents))
    )
    return with_contents(ex, new_contents)
end

function CO.count_constants_for_optimization(ex::TemplateExpression)
    return sum(CO.count_constants_for_optimization, values(get_contents(ex)))
end

function CC.check_constraints(
    ex::TemplateExpression,
    options::AbstractOptions,
    maxsize::Int,
    cursize::Union{Int,Nothing}=nothing,
)::Bool
    # First, we check the variable constraints at the top level:
    if has_invalid_variables(ex)
        return false
    end

    # We also check the combined complexity:
    @something(cursize, ComplexityModule.compute_complexity(ex, options)) > maxsize &&
        return false

    # Then, we check other constraints for inner expressions:
    raw_contents = get_contents(ex)
    for t in values(raw_contents)
        if !CC.check_constraints(t, options, maxsize, nothing)
            return false
        end
    end
    return true
    # TODO: The concept of `cursize` doesn't really make sense here.
end
function has_invalid_variables(ex::TemplateExpression)
    raw_contents = get_contents(ex)
    num_features = get_metadata(ex).structure.num_features
    any(keys(raw_contents)) do key
        tree = raw_contents[key]
        max_feature = num_features[key]
        contains_features_greater_than(tree, max_feature)
    end
end
function contains_features_greater_than(tree::AbstractExpression, max_feature)
    return contains_features_greater_than(get_tree(tree), max_feature)
end
function contains_features_greater_than(tree::AbstractExpressionNode, max_feature)
    any(tree) do node
        node.degree == 0 && !node.constant && node.feature > max_feature
    end
end

# TODO: Add custom behavior to adjust what feature nodes can be generated

end
