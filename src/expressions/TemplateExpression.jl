module TemplateExpressionModule

using Random: AbstractRNG
using Compat: Fix
using Random: default_rng
using DynamicDiff: DynamicDiff
using DispatchDoctor: @unstable, @stable
using StyledStrings: @styled_str, annotatedstring
using DynamicExpressions:
    DynamicExpressions as DE,
    AbstractStructuredExpression,
    AbstractExpressionNode,
    AbstractExpression,
    AbstractOperatorEnum,
    Node,
    OperatorEnum,
    Metadata,
    EvalContext,
    get_contents,
    get_metadata,
    get_operators,
    get_variable_names,
    get_tree,
    with_metadata,
    with_contents,
    node_type,
    count_nodes
using DynamicExpressions.InterfacesModule:
    ExpressionInterface, Interfaces, @implements, all_ei_methods_except, Arguments
using DynamicExpressions.ExpressionModule: _copy

using ...UtilsModule: FixKws
using ...InterfacesModule: InterfaceDataTypesModule as IDT, DatasetModule as DM
using ...ConfigModule: OptionsStructModule as OS, OptionsModule as OM
using ...InterfacesModule: AbstractOptions
using ...ConfigModule: Options
using ...InterfacesModule: Dataset, AbstractExpressionSpec, ExpressionSpecModule as ES
using ..InterfaceDynamicExpressionsModule:
    InterfaceDynamicExpressionsModule as IDE, _process_eval_options
using ..ExpressionBuilderModule: ExpressionBuilderModule as EB
using ..ComposableExpressionModule:
    AbstractComposableExpression, ComposableExpression, ValidVector, get_eval_context

struct ParamVector{T} <: AbstractVector{T}
    _data::Vector{T}
end
Base.size(pv::ParamVector) = size(pv._data)
Base.getindex(pv::ParamVector, i::Integer) = pv._data[i]

# TODO: This likely slows down evaluation a bit. In the future
#       we might want to have integers passed explicitly.
Base.getindex(pv::ParamVector, i::Number) = pv[Int(i)]

function Base.setindex!(::ParamVector, _, _)
    return error(
        "ParamVector should be treated as read-only. Create a new ParamVector instead."
    )
end
function Base.getindex(pv::ParamVector, I::ValidVector)
    data = pv[I.x]
    return ValidVector(data, I.valid)
end
function Base.copy(pv::ParamVector)
    return ParamVector(copy(pv._data))
end

"""
    TemplateStructure{K,E,NF} <: Function

A struct that defines a prescribed structure for a `TemplateExpression`,
including functions that define the result in different contexts.

The `K` parameter is used to specify the symbols representing the inner expressions.
If not declared using the constructor `TemplateStructure{K}(...)`, the keys of the
`variable_constraints` `NamedTuple` will be used to infer this.

The `Kp` parameter is used to specify the symbols representing the parameters, if any.

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
- `num_parameters`: Optional `NamedTuple` of parameter keys => integers representing the number of
    parameters required for each parameter vector.
- `prototype`: Optional example dataset element used as dummy data when inferring `num_features`.
    This is useful when `combine` only accepts a custom element type. Defaults to `1.0`.
"""
struct TemplateStructure{K,Kp,E<:Function,NF<:NamedTuple{K},NP<:NamedTuple{Kp}} <: Function
    combine::E
    num_features::NF
    num_parameters::NP
end

function TemplateStructure{K}(
    combine::E,
    _deprecated_num_features=nothing;
    num_features=nothing,
    num_parameters=nothing,
    prototype=nothing,
) where {K,E<:Function}
    return TemplateStructure{K,()}(
        combine, _deprecated_num_features; num_features, num_parameters, prototype
    )
end
function TemplateStructure{K,Kp}(
    combine::E,
    _deprecated_num_features=nothing;
    num_features::Union{NamedTuple,Nothing}=nothing,
    num_parameters::Union{NamedTuple,Nothing}=nothing,
    prototype=nothing,
) where {K,Kp,E<:Function}
    isdisjoint(K, Kp) ||
        throw(ArgumentError("Template expression and parameter names must be disjoint"))
    if _deprecated_num_features !== nothing
        Base.depwarn(
            "Passing `num_features` as an argument is deprecated, pass it explicitly as a keyword argument instead",
            :TemplateStructure,
        )
    end
    if !isempty(Kp)
        @assert(
            num_parameters !== nothing,
            "Expected `num_parameters` to be provided to indicate the number of parameters for each symbol in `$Kp`"
        )
    end
    num_parameters = @something(num_parameters, NamedTuple(),)
    issetequal(keys(num_parameters), Kp) ||
        throw(ArgumentError("`num_parameters` keys must match `$Kp`"))
    num_parameters = NamedTuple{Kp}(map(k -> getproperty(num_parameters, k), Kp))
    num_features = @something(
        num_features,
        _deprecated_num_features,
        infer_variable_constraints(Val(K), num_parameters, combine, prototype)
    )
    issetequal(keys(num_features), K) ||
        throw(ArgumentError("`num_features` keys must match `$K`"))
    num_features = NamedTuple{K}(map(k -> getproperty(num_features, k), K))
    return TemplateStructure{K,Kp,E,typeof(num_features),typeof(num_parameters)}(
        combine, num_features, num_parameters
    )
end

@unstable function combine(template::TemplateStructure, args...)
    return template.combine(args...)
end

# COV_EXCL_START
get_function_keys(::TemplateStructure{K}) where {K} = K
get_parameter_keys(::TemplateStructure{<:Any,Kp}) where {Kp} = Kp

has_params(s::TemplateStructure) = !isempty(get_parameter_keys(s))
# COV_EXCL_STOP

function _record_composable_expression!(
    variable_constraints, zero_arg_result, ::Val{k}, args...
) where {k}
    vc = variable_constraints[k][]
    if vc == -1
        variable_constraints[k][] = length(args)
    elseif vc != length(args)
        throw(ArgumentError("Inconsistent number of arguments passed to $k"))
    end
    return isempty(args) ? zero_arg_result : first(args)
end

struct ArgumentRecorder{F} <: Function
    f::F
end
(f::ArgumentRecorder)(args...) = f.f(args...)

# We pass through the derivative operators, since
# we just want to record the number of arguments.
DynamicDiff.D(f::ArgumentRecorder, ::Integer) = f

function check_combiner_applicability(
    @nospecialize(combiner),
    @nospecialize(dummy_expressions),
    @nospecialize(dummy_params),
    @nospecialize(dummy_valid_vectors),
)
    if isempty(dummy_params)
        if !applicable(combiner, dummy_expressions, dummy_valid_vectors)
            throw(
                ArgumentError(
                    "Your template structure's `combine` function must accept\n" *
                    "\t1. A `NamedTuple` of `ComposableExpression`s (or `ArgumentRecorder`s)\n" *
                    "\t2. A tuple of `ValidVector`s",
                ),
            )
        end
    else
        if !applicable(combiner, dummy_expressions, dummy_params, dummy_valid_vectors)
            throw(
                ArgumentError(
                    "Your template structure's `combine` function must accept\n" *
                    "\t1. A `NamedTuple` of `ComposableExpression`s (or `ArgumentRecorder`s)\n" *
                    "\t2. A `NamedTuple` of `ParamVector`s\n" *
                    "\t3. A tuple of `ValidVector`s",
                ),
            )
        end
    end
    return nothing
end

"""Infers number of features used by each subexpression, by passing in test data."""
function infer_variable_constraints(
    ::Val{K},
    @nospecialize(num_parameters::NamedTuple),
    @nospecialize(combiner),
    @nospecialize(prototype = nothing),
) where {K}
    proto = @something(prototype, 1.0)
    zero_arg_result = @something(prototype, 0.0)
    variable_constraints = NamedTuple{K}(map(_ -> Ref(-1), K))
    inner = Fix{1}(
        Fix{1}(_record_composable_expression!, variable_constraints), zero_arg_result
    )
    dummy_expressions = NamedTuple{K}(map(k -> ArgumentRecorder(Fix{1}(inner, Val(k))), K))
    dummy_valid_vectors = Base.Iterators.repeated(ValidVector([proto], true))
    dummy_params = NamedTuple{keys(num_parameters)}(
        map(n -> ParamVector(fill(proto, n)), values(num_parameters))
    )

    check_combiner_applicability(
        combiner, dummy_expressions, dummy_params, dummy_valid_vectors
    )

    # Actually call the combiner
    if isempty(dummy_params)
        combiner(dummy_expressions, dummy_valid_vectors)
    else
        combiner(dummy_expressions, dummy_params, dummy_valid_vectors)
    end

    inferred = NamedTuple{K}(map(x -> x[], values(variable_constraints)))
    if any(==(-1), values(inferred))
        failed_keys = filter(k -> inferred[k] == -1, K)
        throw(ArgumentError("Failed to infer number of features used by $failed_keys"))
    end
    return inferred
end

"""
    TemplateExpression{T,F,N,E,TS,D} <: AbstractExpression{T,N}

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

When fitting a model in SymbolicRegression.jl, you can provide
`expression_spec=TemplateExpressionSpec(; structure=TemplateStructure(...))`
as an option. The `variable_constraints` will constraint `f` to only have access to `x1` and `x2`,
and `g` to only have access to `x3`.
"""
struct TemplateExpression{
    T,
    F<:TemplateStructure,
    N<:AbstractExpressionNode{T},
    E<:AbstractComposableExpression{T,N},
    TS<:NamedTuple{<:Any,<:NTuple{<:Any,E}},
    D<:@NamedTuple{
        structure::F, operators::O, variable_names::V, parameters::P
    } where {O<:AbstractOperatorEnum,V,P<:NamedTuple{<:Any,<:NTuple{<:Any,ParamVector}}},
} <: AbstractExpression{T,N}
    trees::TS
    metadata::Metadata{D}

    function TemplateExpression(
        trees::TS, metadata::Metadata{D}
    ) where {
        TS,
        F<:TemplateStructure,
        D<:@NamedTuple{
            structure::F, operators::O, variable_names::V, parameters::P
        } where {O,V,P<:NamedTuple{<:Any,<:NTuple{<:Any,ParamVector}}},
    }
        @assert keys(trees) == get_function_keys(metadata.structure)
        @assert keys(metadata.parameters) == keys(metadata.structure.num_parameters)
        E = typeof(first(values(trees)))
        N = node_type(E)
        return new{eltype(N),F,N,E,TS,D}(trees, metadata)
    end
end

function TemplateExpression(
    trees::NamedTuple{<:Any,<:NTuple{<:Any,<:AbstractExpression{T}}};
    structure::TemplateStructure,
    operators::Union{AbstractOperatorEnum,Nothing}=nothing,
    variable_names::Union{AbstractVector{<:AbstractString},Nothing}=nothing,
    parameters::Union{NamedTuple,Nothing}=nothing,
) where {T}
    example_tree = first(values(trees))::AbstractExpression
    operators = get_operators(example_tree, operators)
    variable_names = get_variable_names(example_tree, variable_names)
    final_parameters = if has_params(structure)
        supplied_parameters = @something(parameters, NamedTuple())
        expected_keys = keys(structure.num_parameters)
        issubset(keys(supplied_parameters), expected_keys) || throw(
            ArgumentError(
                "Template parameter names $(keys(supplied_parameters)) must be a subset of $(expected_keys)",
            ),
        )
        NamedTuple{expected_keys}(
            map(expected_keys, values(structure.num_parameters)) do key, expected_length
                parameter = if hasproperty(supplied_parameters, key)
                    supplied_parameters[key]
                else
                    T[IDT.init_value(T) for _ in 1:expected_length]
                end
                parameter isa AbstractVector || throw(
                    ArgumentError(
                        "Expected `parameters.$key` to be an `AbstractVector`, got $(typeof(parameter))",
                    ),
                )
                length(parameter) == expected_length || throw(
                    DimensionMismatch(
                        "Expected `parameters.$key` to have length $expected_length, got $(length(parameter))",
                    ),
                )
                return if parameter isa ParamVector{T}
                    parameter
                else
                    ParamVector(convert(Vector{T}, parameter))
                end
            end,
        )
    else
        @assert(
            parameters === nothing || isempty(parameters),
            "Expected `parameters` to not be specified for `structure.num_parameters=$(structure.num_parameters)`"
        )
        NamedTuple()
    end
    metadata = (; structure, operators, variable_names, parameters=final_parameters)
    return TemplateExpression(trees, Metadata(metadata))
end

@unstable DE.constructorof(::Type{<:TemplateExpression}) = TemplateExpression  # COV_EXCL_LINE

@implements(
    ExpressionInterface{all_ei_methods_except(())}, TemplateExpression, [Arguments()]
)

has_params(ex::TemplateExpression) = has_params(get_metadata(ex).structure)

@unstable function combine(ex::TemplateExpression, args...)
    return combine(get_metadata(ex).structure, args...)
end

function Base.copy(e::TemplateExpression)
    ts = get_contents(e)
    copy_ts = NamedTuple{keys(ts)}(map(copy, values(ts)))
    copy_parameters = _copy(get_metadata(e).parameters::NamedTuple)
    return with_metadata(with_contents(e, copy_ts); parameters=copy_parameters)
end
function DE.get_contents(e::TemplateExpression)
    return e.trees
end
function DE.get_metadata(e::TemplateExpression)
    return e.metadata
end
function DE.get_operators(
    e::TemplateExpression, operators::Union{AbstractOperatorEnum,Nothing}=nothing
)
    return @something(operators, get_metadata(e).operators)
end
function DE.get_variable_names(
    e::TemplateExpression,
    variable_names::Union{AbstractVector{<:AbstractString},Nothing}=nothing,
)
    return if variable_names !== nothing
        variable_names
    elseif hasproperty(get_metadata(e), :variable_names)
        get_metadata(e).variable_names
    else
        nothing
    end
end
function _pack_parameters(p::ParamVector{T}) where {T}
    buffer = Vector{DE.get_number_type(T)}(undef, DE.count_scalar_constants(p))
    idx = firstindex(buffer)
    for value in p._data
        idx = DE.pack_scalar_constants!(buffer, idx, value)
    end
    return buffer
end
function _unpack_parameters!(p::ParamVector, constants, idx::Int)
    for i in eachindex(p._data)
        (idx, p._data[i]) = DE.unpack_scalar_constants(constants, idx, p._data[i])
    end
    return idx
end
function DE.get_scalar_constants(e::TemplateExpression)
    # Get constants for each inner expression
    consts_and_refs = map(DE.get_scalar_constants, values(get_contents(e)))
    parameter_chunks = if has_params(e)
        map(_pack_parameters, values(get_metadata(e).parameters))
    else
        ()
    end
    flat_constants = vcat(map(first, consts_and_refs)..., parameter_chunks...)
    # Collect info so we can put them back in the right place,
    # like the indexes of the constants in the flattened array
    refs = map(c_ref -> (; n=length(first(c_ref)), ref=last(c_ref)), consts_and_refs)
    return flat_constants, refs
end
function DE.set_scalar_constants!(e::TemplateExpression, constants, refs)
    cursor = Ref(1)
    foreach(values(get_contents(e)), refs) do tree, r
        n = r.n
        i = cursor[]
        c = constants[i:(i + n - 1)]
        DE.set_scalar_constants!(tree, c, r.ref)
        cursor[] = i + n
    end
    if has_params(e)
        parameters = get_metadata(e).parameters
        for k in keys(parameters)
            cursor[] = _unpack_parameters!(parameters[k], constants, cursor[])
        end
    end
    return e
end

struct TemplateOptimizableRefs{R}
    scalar_refs::R
    length::Int
end

Base.@kwdef struct PreallocatedTemplateExpression{A,B}
    trees::A
    parameters::B
end

function DE.allocate_container(e::TemplateExpression, n::Union{Nothing,Integer}=nothing)
    ts = get_contents(e)
    parameters = get_metadata(e).parameters
    preallocated_trees = NamedTuple{keys(ts)}(
        map(t -> DE.allocate_container(t, n), values(ts))
    )
    preallocated_parameters = NamedTuple{keys(parameters)}(
        map(p -> similar(p), values(parameters))
    )
    return PreallocatedTemplateExpression(preallocated_trees, preallocated_parameters)
end
function DE.copy_into!(dest::PreallocatedTemplateExpression, src::TemplateExpression)
    ts = get_contents(src)
    parameters = get_metadata(src).parameters
    new_contents = NamedTuple{keys(ts)}(map(DE.copy_into!, values(dest.trees), values(ts)))
    for k in keys(parameters)
        dest.parameters[k][:] = (parameters[k]::ParamVector)[:]
    end
    new_parameters = NamedTuple{keys(parameters)}(
        map(p -> ParamVector(p), values(dest.parameters))
    )
    return with_metadata(with_contents(src, new_contents); parameters=new_parameters)
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
    if has_params(ex)
        throw(
            ArgumentError(
                "`get_tree` is not implemented for TemplateExpression with parameters"
            ),
        )
    end

    return DE.get_tree(
        combine(get_metadata(ex).structure, raw_contents, variable_expressions)
    )
end

# `::Type{IET}` keeps IET as a static parameter inside the closure; a runtime
# `Type` capture widens to `DataType` (see `Core._typeof_captured_variable`).
@inline function _build_inner_template_expressions(
    ::Type{IET},
    t,
    operators,
    variable_names,
    eval_context,
    inner_expression_options::NamedTuple,
    ::Val{N},
) where {IET,N}
    return ntuple(
        _ -> DE.constructorof(IET)(
            copy(t);
            operators,
            variable_names,
            eval_context,
            inner_expression_options...,
        ),
        Val(N),
    )
end

function EB.create_expression(
    t::AbstractExpressionNode{T},
    options::AbstractOptions,
    dataset::Dataset{T,L},
    ::Type{<:AbstractExpressionNode},
    ::Type{E},
    (::Val{embed})=Val(false),
) where {T,L,embed,E<:TemplateExpression}
    function_keys = get_function_keys(options.expression_options.structure)
    inner_expression_type = options.expression_options.inner_expression_type
    inner_expression_options = options.expression_options.inner_expression_options

    operators = options.operators
    variable_names = embed ? dataset.variable_names : nothing
    eval_context = EvalContext(; turbo=options.turbo, bumper=options.bumper)
    inner_expressions = _build_inner_template_expressions(
        inner_expression_type,
        t,
        operators,
        variable_names,
        eval_context,
        inner_expression_options,
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
    num_parameters = options.expression_options.structure.num_parameters
    parameters = if isempty(num_parameters)
        NamedTuple()
    else
        # COV_EXCL_START
        if prototype === nothing
            _initialize_template_parameters(
                default_rng(),
                T,
                num_parameters,
                options.expression_options.parameter_initializer,
                options,
            )
        else
            _copy(get_metadata(prototype).parameters::NamedTuple)
        end
        # COV_EXCL_STOP
    end
    # We also need to include the operators here to be consistent with `create_expression`.
    return (; options.operators, options.expression_options..., parameters)
end

function _initialize_template_parameters(
    rng::AbstractRNG,
    ::Type{T},
    num_parameters::NamedTuple,
    parameter_initializer::Nothing,
    options::AbstractOptions,
) where {T}
    return NamedTuple{keys(num_parameters)}(
        map(values(num_parameters)) do n
            ParamVector(T[IDT.sample_value(rng, T, options) for _ in 1:n])
        end,
    )
end
function _initialize_template_parameters(
    rng::AbstractRNG,
    ::Type{T},
    num_parameters::NamedTuple,
    parameter_initializer,
    ::AbstractOptions,
) where {T}
    initialized = parameter_initializer(rng, T, num_parameters)
    initialized isa NamedTuple || throw(
        ArgumentError(
            "`parameter_initializer` must return a `NamedTuple`, got $(typeof(initialized))",
        ),
    )

    expected_keys = keys(num_parameters)
    initialized_keys = keys(initialized)
    issetequal(initialized_keys, expected_keys) || throw(
        ArgumentError(
            "`parameter_initializer` returned keys $(initialized_keys), expected $(expected_keys)",
        ),
    )

    parameters = map(expected_keys, values(num_parameters)) do key, expected_length
        parameter = initialized[key]
        parameter isa AbstractVector || throw(
            ArgumentError(
                "`parameter_initializer` must return an `AbstractVector` for parameter `$(key)`, got $(typeof(parameter))",
            ),
        )
        length(parameter) == expected_length || throw(
            DimensionMismatch(
                "`parameter_initializer` returned $(length(parameter)) values for parameter `$(key)`, expected $(expected_length)",
            ),
        )
        return ParamVector(Vector{T}(parameter))
    end
    return NamedTuple{expected_keys}(parameters)
end

function EB.sort_params(params::NamedTuple, ::Type{<:TemplateExpression})
    return (; params.structure, params.operators, params.variable_names, params.parameters)
end

# Rather than using iterator with repeat, just make a tuple:
function _colors(::Val{n}) where {n}
    return ntuple(
        (i -> (:magenta, :green, :red, :blue, :yellow, :cyan)[mod1(i, 6)]), Val(n)
    )
end
_color_string(s::AbstractString, c::Symbol) = styled"{$c:$s}"

function _format_component(ex::AbstractExpression, c::Symbol; operators, kws...)
    return _color_string(DE.string_tree(ex, operators; kws...), c)
end
function _format_component(param::ParamVector, c::Symbol; pretty, f_constant::FC) where {FC}
    p_str = if !pretty || length(param) <= 5
        join(map(f_constant, param), ", ")
    else
        string(join(map(f_constant, param[1:3]), ", "), ", ..., ", f_constant(param[end]))
    end

    return _color_string('[' * p_str * ']', c)
end
function _prefix_string_with_pipe(k::Symbol, s; all_keys, pretty)
    prefix = if !pretty || length(all_keys) == 1
        ""
    elseif k == first(all_keys)
        "╭ "
    elseif k == last(all_keys)
        "╰ "
    else
        "├ "
    end
    return annotatedstring(prefix, string(k), " = ", s)
end
function DE.string_tree(
    ex::TemplateExpression,
    operators::Union{AbstractOperatorEnum,Nothing}=nothing;
    pretty::Bool=false,
    variable_names=nothing,  # ignored
    f_constant::FC=string,
    kws...,
) where {FC}
    expressions = get_contents(ex)
    num_features = get_metadata(ex).structure.num_features
    total_num_features = max(values(num_features)...)
    variable_names = ['#' * string(i) for i in 1:total_num_features]
    parameters = has_params(ex) ? get_metadata(ex).parameters : NamedTuple()
    all_keys = (keys(num_features)..., keys(parameters)...)
    colors = _colors(Val(length(all_keys)))

    strings = NamedTuple{all_keys}((
        map(
            FixKws(
                _format_component; operators, pretty, variable_names, f_constant, kws...
            ),
            values(expressions),
            colors[1:length(expressions)],
        )...,
        map(
            FixKws(_format_component; pretty, f_constant),
            values(parameters),
            colors[(length(expressions) + 1):end],
        )...,
    ))
    prefixed_strings = NamedTuple{all_keys}(
        map(FixKws(_prefix_string_with_pipe; all_keys, pretty), all_keys, values(strings))
    )
    return annotatedstring(join(prefixed_strings, pretty ? styled"\n" : styled"; "))
end

struct TemplateReturnError <: Exception end

function Base.showerror(io::IO, ::TemplateReturnError)
    return print(
        io,
        """
TemplateReturnError: Template expression returned a regular Vector, but ValidVector is required.

Template expressions must return ValidVector for proper handling:

    ```julia
    return ValidVector(my_data, computation_is_valid)
    ```

The .valid field is used to track whether any upstream computation failed.
It's important to handle this correctly.

Example of manually propagating validity:

    ```julia
    _f_result = f(x1, x2)  # Returns ValidVector
    _g_result = g(x3)      # Returns ValidVector

    # Combine results manually and propagate validity
    combined_data = _f_result.x .+ _g_result.x
    return ValidVector(combined_data, _f_result.valid && _g_result.valid)
    ```

Note that normally we could simply write `_f_result + _g_result`,
and this would automatically handle the validity and vectorization.
""",
    )
end

function _match_input_eltype(
    ::Type{<:AbstractMatrix{T1}}, result::AbstractVector{T2}
) where {T1,T2}
    if T1 != T2 && T1 <: AbstractFloat && T2 <: AbstractFloat
        # Just to handle cases where the user might write
        # 0.5 in their template spec, but the data is Float32.
        return Base.Fix1(convert, T1).(result)
    else
        return result
    end
end

_with_call_time_buffer(contents, ::Nothing) = contents
function _with_call_time_buffer(contents::NamedTuple, eval_context::EvalContext)
    eval_context.buffer === nothing && return contents
    return map(Base.Fix2(_with_call_time_buffer, eval_context), contents)
end
function _with_call_time_buffer(ex::AbstractComposableExpression, eval_context::EvalContext)
    stored = get_eval_context(ex)
    stored.bumper isa Val{true} && return ex
    merged = EvalContext(
        stored.turbo,
        stored.bumper,
        stored.early_exit,
        eval_context.buffer,
        stored.use_fused,
    )
    return with_metadata(ex; eval_context=merged)
end

@stable(
    default_mode = "disable",
    default_union_limit = 2,
    begin
        function DE.eval_tree_array(
            tree::TemplateExpression,
            cX::AbstractMatrix,
            operators::Union{AbstractOperatorEnum,Nothing}=nothing;
            eval_context=nothing,
            kws...,
        )
            eval_context = _process_eval_options(eval_context, kws, :eval_tree_array)
            raw_contents = get_contents(tree)
            metadata = get_metadata(tree)
            if has_invalid_variables(tree)
                return (nothing, false)
            end
            extra_args = if has_params(tree)
                (metadata.parameters,)
            else
                ()
            end
            result = combine(
                tree,
                _with_call_time_buffer(raw_contents, eval_context),
                extra_args...,
                map(x -> ValidVector(copy(x), true), eachrow(cX)),
            )
            # Validate that template expression returned a ValidVector
            if !(result isa ValidVector)
                throw(TemplateReturnError())
            end
            return _match_input_eltype(typeof(cX), result.x), result.valid
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
@unstable begin
    # COV_EXCL_START
    IDE.expected_array_type(::AbstractArray, ::Type{<:TemplateExpression}) = Any
    IDE.expected_array_type(::Matrix{T}, ::Type{<:TemplateExpression}) where {T} = Any
    IDE.expected_array_type(
        ::SubArray{T,2,Matrix{T}}, ::Type{<:TemplateExpression}
    ) where {T} = Any
    # COV_EXCL_STOP
end

"""
We need full specialization for constrained expressions, as they rely on subexpressions being combined.
"""
function OS.operator_specialization(
    ::Type{O}, ::Type{<:TemplateExpression}
) where {O<:OperatorEnum}
    return O
end

OM.recommend_loss_function_expression(::Type{<:TemplateExpression}) = true

function DM.max_features(
    dataset::Dataset, options::Options{<:Any,<:Any,<:Any,<:TemplateExpression}
)
    num_features = options.expression_options.structure.num_features
    return max(values(num_features)...)
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
function has_constants(tree::AbstractExpression)
    any(get_tree(tree)) do node
        node.degree == 0 && node.constant
    end
end
has_constants(ex::TemplateExpression) = any(has_constants, values(get_contents(ex)))

function DE.count_scalar_constants(ex::TemplateExpression)
    return (
        sum(DE.count_scalar_constants, values(get_contents(ex))) + (
            if has_params(ex)
                sum(DE.count_scalar_constants, values(get_metadata(ex).parameters))
            else
                0
            end
        )
    )
end
function DE.count_scalar_constants(p::ParamVector)
    return sum(DE.count_scalar_constants, p._data; init=0)
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

function Base.isempty(ex::TemplateExpression)
    return all(isempty, values(get_contents(ex)))
end

# TODO: Add custom behavior to adjust what feature nodes can be generated

"""
    TemplateExpressionSpec <: AbstractExpressionSpec

(Experimental) Specification for template expressions with pre-defined structure.

# Fields
- `structure`: The `TemplateStructure` defining how inner expressions and parameters
    are combined.
- `inner_expression_type`: The expression type used for each inner expression. Custom
    types must implement the DynamicExpressions expression interface, including
    `Base.copy` with independent copies of any mutable candidate-local metadata.
- `inner_expression_options`: Additional keyword arguments passed to inner expressions.
- `parameter_initializer`: **Experimental** optional function called as
    `parameter_initializer(rng, T, num_parameters)` when creating a new candidate.
    It must return a `NamedTuple` with the same keys and vector lengths as
    `num_parameters`. By default, template parameters are sampled with
    `sample_value`.
"""
struct TemplateExpressionSpec{ST<:TemplateStructure,IET,IEO<:NamedTuple,PI} <:
       AbstractExpressionSpec
    structure::ST
    inner_expression_type::Type{IET}
    inner_expression_options::IEO
    parameter_initializer::PI
    function TemplateExpressionSpec{ST,IET,IEO,PI}(
        structure, inner_expression_type, inner_expression_options, parameter_initializer
    ) where {ST<:TemplateStructure,IET,IEO<:NamedTuple,PI}
        return new{ST,IET,IEO,PI}(
            structure,
            inner_expression_type,
            inner_expression_options,
            parameter_initializer,
        )
    end
end
# Positional form. `::Type{IET}` with a positional default binds IET in the
# `where` clause (kwarg defaults don't), so the inferred return type stays
# concrete for downstream consumers.
function TemplateExpressionSpec(
    structure::TemplateStructure,
    (::Type{IET})=ComposableExpression,
    inner_expression_options::NamedTuple=NamedTuple(),
    parameter_initializer=nothing,
) where {IET}
    return TemplateExpressionSpec{
        typeof(structure),IET,typeof(inner_expression_options),typeof(parameter_initializer)
    }(
        structure, IET, inner_expression_options, parameter_initializer
    )
end
@unstable function TemplateExpressionSpec(;
    structure::TemplateStructure,
    inner_expression_type::Type=ComposableExpression,
    inner_expression_options::NamedTuple=NamedTuple(),
    parameter_initializer=nothing,
)
    return TemplateExpressionSpec(
        structure, inner_expression_type, inner_expression_options, parameter_initializer
    )
end

# COV_EXCL_START
ES.get_expression_type(::TemplateExpressionSpec) = TemplateExpression
# Explicit NamedTuple type pins `inner_expression_type` as `Type{IET}`
# (a `(; ...)` shorthand widens it to `Type`, killing inference).
function ES.get_expression_options(
    spec::TemplateExpressionSpec{ST,IET,IEO,PI}
) where {ST,IET,IEO,PI}
    return NamedTuple{
        (
            :structure,
            :inner_expression_type,
            :inner_expression_options,
            :parameter_initializer,
        ),
        Tuple{ST,Type{IET},IEO,PI},
    }((
        spec.structure,
        spec.inner_expression_type,
        spec.inner_expression_options,
        spec.parameter_initializer,
    ),)
end
ES.get_node_type(::TemplateExpressionSpec) = Node
# COV_EXCL_STOP

IDE.require_copy_to_workers(::Type{<:TemplateExpression}) = true  # COV_EXCL_LINE
function IDE.make_example_inputs(
    ::Type{<:TemplateExpression}, ::Type{T}, options, dataset
) where {T}
    ex = EB.create_expression(IDT.init_value(T), options, dataset)
    raw_contents = get_contents(ex)
    extra_args = has_params(ex) ? (get_metadata(ex).parameters,) : ()
    return (;
        ops=(get_metadata(ex).structure.combine,),
        example_inputs=(
            raw_contents,
            extra_args...,
            map(x -> ValidVector(copy(x), true), eachrow(dataset.X)),
        ),
    )
end

"""
    parse_expression(ex::NamedTuple; kws...)

Extension of `parse_expression` to handle named-tuple input for template expressions.
Expression names map to strings using `#N` placeholder syntax. Parameter names may map
to vectors in the same tuple, or may be supplied through the `parameters` keyword.

# Example
```julia
operators = OperatorEnum(; binary_operators=(+,))
spec = @template_spec(expressions = (f,), parameters = (p=2,)) do x
    f(x) + p[1]
end
parse_expression((; f="#1", p=[2.0, 3.0]); expression_spec=spec, operators)
```
"""
@unstable function DE.parse_expression(
    ex::NamedTuple;
    expression_spec::Union{ES.AbstractExpressionSpec,Nothing}=nothing,
    expression_options::Union{NamedTuple,Nothing}=nothing,
    eval_context::Union{EvalContext,Nothing}=nothing,
    eval_module::Union{Module,Nothing}=nothing,
    operators::Union{AbstractOperatorEnum,Nothing}=nothing,
    binary_operators::Union{Vector{<:Function},Nothing}=nothing,
    unary_operators::Union{Vector{<:Function},Nothing}=nothing,
    variable_names::Union{AbstractVector,Nothing}=nothing,
    expression_type::Union{Type,Nothing}=nothing,
    node_type::Union{Type,Nothing}=nothing,
    parameters::Union{NamedTuple,Nothing}=nothing,
    kws...,
)
    eval_context = _process_eval_options(eval_context, kws, :parse_expression)
    kws = Base.structdiff((; kws...), (; eval_options=nothing))
    if expression_spec !== nothing
        resolved_expression_type = ES.get_expression_type(expression_spec)
        resolved_expression_options = ES.get_expression_options(expression_spec)
        resolved_node_type = ES.get_node_type(expression_spec)
    else
        resolved_expression_type = something(expression_type, TemplateExpression)
        resolved_expression_options = expression_options
        resolved_node_type = something(node_type, Node)
    end

    # COV_EXCL_START
    @assert resolved_expression_type <: TemplateExpression
    @assert(
        resolved_expression_options !== nothing &&
            resolved_expression_options.structure isa TemplateStructure,
        "NamedTuple expressions require expression_options with a TemplateStructure"
    )
    # COV_EXCL_STOP

    eval_context_kws = if eval_context !== nothing
        (; eval_context)
    else
        NamedTuple()
    end
    inner_expression_type =
        if hasproperty(resolved_expression_options, :inner_expression_type)
            resolved_expression_options.inner_expression_type
        else
            ComposableExpression
        end
    inner_expression_options =
        if hasproperty(resolved_expression_options, :inner_expression_options)
            resolved_expression_options.inner_expression_options
        else
            NamedTuple()
        end
    structure = resolved_expression_options.structure
    function_keys = get_function_keys(structure)
    parameter_keys = get_parameter_keys(structure)
    supplied_keys = keys(ex)
    allowed_keys = (function_keys..., parameter_keys...)
    issubset(supplied_keys, allowed_keys) || throw(
        ArgumentError(
            "Template guess names $(supplied_keys) must be expression or parameter names from $(allowed_keys)",
        ),
    )
    issubset(function_keys, supplied_keys) || throw(
        ArgumentError("Template guesses must provide every expression in $(function_keys)"),
    )
    flat_parameter_keys = Tuple(k for k in parameter_keys if hasproperty(ex, k))
    isempty(flat_parameter_keys) ||
        parameters === nothing ||
        throw(
            ArgumentError(
                "Template parameters must be supplied either as flat NamedTuple entries or with the `parameters` keyword, not both",
            ),
        )
    supplied_parameters = if isempty(flat_parameter_keys)
        parameters
    else
        NamedTuple{flat_parameter_keys}(map(k -> getproperty(ex, k), flat_parameter_keys))
    end
    resolved_parameters = if supplied_parameters === nothing
        nothing
    else
        NamedTuple{keys(supplied_parameters)}(
            map(keys(supplied_parameters), values(supplied_parameters)) do key, parameter
                parameter isa AbstractVector || throw(
                    ArgumentError(
                        "Expected `parameters.$key` to be an `AbstractVector`, got $(typeof(parameter))",
                    ),
                )
                copy(parameter)
            end,
        )
    end
    inner_expressions = NamedTuple{function_keys}(
        map(function_keys) do key
            expr_str = getproperty(ex, key)
            expr_str isa AbstractString || throw(
                ArgumentError(
                    "Expected template expression `$key` to be a string, got $(typeof(expr_str))",
                ),
            )
            max_var_index = 0
            for m in eachmatch(r"#(\d+)", expr_str)
                capture = m.captures[1]
                if capture !== nothing
                    var_idx = parse(Int, capture)
                    max_var_index = max(max_var_index, var_idx)
                end
            end

            placeholder_variable_names = ["__arg_$i" for i in 1:max_var_index]
            expr_str = replace(expr_str, r"#(\d+)" => s"__arg_\1")

            parsed_expr = DE.parse_expression(
                expr_str;
                operators,
                binary_operators,
                unary_operators,
                variable_names=placeholder_variable_names,
                expression_type=DE.Expression,
                node_type=resolved_node_type,
                eval_module,
                kws...,
            )

            DE.constructorof(inner_expression_type)(
                parsed_expr.tree;
                operators,
                variable_names=nothing,
                eval_context_kws...,
                inner_expression_options...,
            )
        end,
    )

    return DE.constructorof(resolved_expression_type)(
        inner_expressions;
        structure,
        operators,
        variable_names=nothing,
        parameters=resolved_parameters,
        kws...,
    )
end

end
