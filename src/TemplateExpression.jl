module TemplateExpressionModule

using Random: AbstractRNG
using DispatchDoctor: @unstable
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

using ..CoreModule: AbstractOptions, Dataset, CoreModule as CM, AbstractMutationWeights
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

"""
    TemplateStructure{K,S,N,E,C} <: Function

A struct that defines a prescribed structure for a `TemplateExpression`,
including functions that define the result of combining sub-expressions in different contexts.

The `K` parameter is used to specify the symbols representing the inner expressions.
If not declared using the constructor `TemplateStructure{K}(...)`, the keys of the
`variable_constraints` `NamedTuple` will be used to infer this.

# Fields
- `combine`: Optional function taking a `NamedTuple` of function keys => expressions,
    returning a single expression. Fallback method used by `get_tree`
    on a `TemplateExpression` to generate a single `Expression`.
- `combine_vectors`: Optional function taking a `NamedTuple` of function keys => vectors,
    returning a single vector. Used for evaluating the expression tree.
    You may optionally define a method with a second argument `X` for if you wish
    to include the data matrix `X` (of shape `[num_features, num_rows]`) in the
    computation.
- `combine_strings`: Optional function taking a `NamedTuple` of function keys => strings,
    returning a single string. Used for printing the expression tree.
- `variable_constraints`: Optional `NamedTuple` that defines which variables each sub-expression is allowed to access.
    For example, requesting `f(x1, x2)` and `g(x3)` would be equivalent to `(; f=[1, 2], g=[3])`.
"""
struct TemplateStructure{
    K,
    E<:Union{Nothing,Function},
    N<:Union{Nothing,Function},
    S<:Union{Nothing,Function},
    C<:Union{Nothing,NamedTuple{<:Any,<:Tuple{Vararg{Vector{Int}}}}},
} <: Function
    combine::E
    combine_vectors::N
    combine_strings::S
    variable_constraints::C
end

function TemplateStructure{K}(combine::E; kws...) where {K,E<:Function}
    return TemplateStructure{K}(; combine, kws...)
end
function TemplateStructure{K}(; kws...) where {K}
    return TemplateStructure(; _function_keys=Val(K), kws...)
end
function TemplateStructure(combine::E; kws...) where {E<:Function}
    return TemplateStructure(; combine, kws...)
end
function TemplateStructure(;
    combine::E=nothing,
    combine_vectors::N=nothing,
    combine_strings::S=nothing,
    variable_constraints::C=nothing,
    _function_keys::Val{K}=Val(nothing),
) where {
    K,
    E<:Union{Nothing,Function},
    N<:Union{Nothing,Function},
    S<:Union{Nothing,Function},
    C<:Union{Nothing,NamedTuple{<:Any,<:Tuple{Vararg{Vector{Int}}}}},
}
    K === nothing &&
        variable_constraints === nothing &&
        throw(
            ArgumentError(
                "If `variable_constraints` is not provided, " *
                "you must initialize `TemplateStructure` with " *
                "`TemplateStructure{K}(...)`, for tuple of symbols `K`.",
            ),
        )
    K !== nothing &&
        variable_constraints !== nothing &&
        K != keys(variable_constraints) &&
        throw(ArgumentError("`K` must match the keys of `variable_constraints`."))

    Kout = K === nothing ? keys(variable_constraints::NamedTuple) : K
    return TemplateStructure{Kout,E,N,S,C}(
        combine, combine_vectors, combine_strings, variable_constraints
    )
end
# TODO: This interface is ugly. Part of this is due to AbstractStructuredExpression,
# which was not written with this `TemplateStructure` in mind, but just with a
# single callable function.

function combine(template::TemplateStructure, nt::NamedTuple)
    return (template.combine::Function)(nt)
end
function combine_vectors(
    template::TemplateStructure, nt::NamedTuple, X::Union{AbstractMatrix,Nothing}=nothing
)
    combiner = template.combine_vectors::Function
    if X !== nothing && hasmethod(combiner, typeof((nt, X)))
        # TODO: Refactor this
        return combiner(nt, X)
    else
        return combiner(nt)
    end
end
function combine_strings(template::TemplateStructure, nt::NamedTuple)
    return (template.combine_strings::Function)(nt)
end

function (template::TemplateStructure)(
    nt::NamedTuple{<:Any,<:Tuple{AbstractExpression,Vararg{AbstractExpression}}}
)
    return combine(template, nt)
end
function (template::TemplateStructure)(
    nt::NamedTuple{<:Any,<:Tuple{AbstractVector,Vararg{AbstractVector}}},
    X::Union{AbstractMatrix,Nothing}=nothing,
)
    return combine_vectors(template, nt, X)
end
function (template::TemplateStructure)(
    nt::NamedTuple{<:Any,<:Tuple{AbstractString,Vararg{AbstractString}}}
)
    return combine_strings(template, nt)
end

can_combine(template::TemplateStructure) = template.combine !== nothing
can_combine_vectors(template::TemplateStructure) = template.combine_vectors !== nothing
can_combine_strings(template::TemplateStructure) = template.combine_strings !== nothing
get_function_keys(::TemplateStructure{K}) where {K} = K

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
    structure=TemplateStructure{(:f, :g)}(nt -> sin(nt.f) + nt.g * nt.g),
    operators,
    variable_names,
)
```

We can also define constraints on which variables each sub-expression is allowed to access:

```julia
variable_constraints = (; f=[1, 2], g=[3])
st_expr = TemplateExpression(
    example_expr;
    structure=TemplateStructure(
        nt -> sin(nt.f) + nt.g * nt.g; variable_constraints
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
    E<:Expression{T,N},  # TODO: Generalize this
    TS<:NamedTuple{<:Any,<:NTuple{<:Any,E}},
    D<:@NamedTuple{structure::F, operators::O, variable_names::V} where {O,V},
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

function combine(ex::TemplateExpression, nt::NamedTuple)
    return combine(get_metadata(ex).structure, nt)
end
function combine_vectors(
    ex::TemplateExpression, nt::NamedTuple, X::Union{AbstractMatrix,Nothing}=nothing
)
    return combine_vectors(get_metadata(ex).structure, nt, X)
end
function combine_strings(ex::TemplateExpression, nt::NamedTuple)
    return combine_strings(get_metadata(ex).structure, nt)
end

function can_combine(ex::TemplateExpression)
    return can_combine(get_metadata(ex).structure)
end
function can_combine_vectors(ex::TemplateExpression)
    return can_combine_vectors(get_metadata(ex).structure)
end
function can_combine_strings(ex::TemplateExpression)
    return can_combine_strings(get_metadata(ex).structure)
end
get_function_keys(ex::TemplateExpression) = get_function_keys(get_metadata(ex).structure)

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
        _ -> Expression(copy(t); operators, variable_names), length(function_keys)
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

function DE.string_tree(
    tree::TemplateExpression, operators::Union{AbstractOperatorEnum,Nothing}=nothing; kws...
)
    raw_contents = get_contents(tree)
    if can_combine_strings(tree)
        function_keys = keys(raw_contents)
        inner_strings = NamedTuple{function_keys}(
            map(ex -> DE.string_tree(ex, operators; kws...), values(raw_contents))
        )
        return combine_strings(tree, inner_strings)
    else
        @assert can_combine(tree)
        return DE.string_tree(combine(tree, raw_contents), operators; kws...)
    end
end
function DE.eval_tree_array(
    tree::TemplateExpression{T},
    cX::AbstractMatrix{T},
    operators::Union{AbstractOperatorEnum,Nothing}=nothing;
    kws...,
) where {T}
    raw_contents = get_contents(tree)
    if can_combine_vectors(tree)
        # Raw numerical results of each inner expression:
        outs = map(
            ex -> DE.eval_tree_array(ex, cX, operators; kws...), values(raw_contents)
        )
        # Combine them using the structure function:
        results = NamedTuple{keys(raw_contents)}(map(first, outs))
        return combine_vectors(tree, results, cX), all(last, outs)
    else
        @assert can_combine(tree)
        return DE.eval_tree_array(combine(tree, raw_contents), cX, operators; kws...)
    end
end
function (ex::TemplateExpression)(
    X, operators::Union{AbstractOperatorEnum,Nothing}=nothing; kws...
)
    raw_contents = get_contents(ex)
    if can_combine_vectors(ex)
        results = NamedTuple{keys(raw_contents)}(
            map(ex -> ex(X, operators; kws...), values(raw_contents))
        )
        return combine_vectors(ex, results, X)
    else
        @assert can_combine(ex)
        callable = combine(ex, raw_contents)
        return callable(X, operators; kws...)
    end
end

function DA.violates_dimensional_constraints(
    tree::TemplateExpression, dataset::Dataset, options::AbstractOptions
)
    @assert dataset.X_units === nothing && dataset.y_units === nothing
    return false
end
function MM.condition_mutation_weights!(
    weights::AbstractMutationWeights, member::P, options::AbstractOptions, curmaxsize::Int
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
    raw_contents = get_contents(ex)
    variable_constraints = get_metadata(ex).structure.variable_constraints

    # First, we check the variable constraints at the top level:
    has_invalid_variables = any(keys(raw_contents)) do key
        tree = raw_contents[key]
        allowed_variables = variable_constraints[key]
        contains_other_features_than(tree, allowed_variables)
    end
    if has_invalid_variables
        return false
    end

    # We also check the combined complexity:
    ((cursize === nothing) ? ComplexityModule.compute_complexity(ex, options) : cursize) >
    maxsize && return false

    # Then, we check other constraints for inner expressions:
    return all(
        t -> CC.check_constraints(t, options, maxsize, nothing), values(raw_contents)
    )
    # TODO: The concept of `cursize` doesn't really make sense here.
end
function contains_other_features_than(tree::AbstractExpression, features)
    return contains_other_features_than(get_tree(tree), features)
end
function contains_other_features_than(tree::AbstractExpressionNode, features)
    any(tree) do node
        node.degree == 0 && !node.constant && node.feature ∉ features
    end
end

# TODO: Add custom behavior to adjust what feature nodes can be generated

end
