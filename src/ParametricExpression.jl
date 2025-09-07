"""
Note that ParametricExpression is defined within DynamicExpressions.jl,
this file just adds custom behavior for SymbolicRegression.jl, where needed.
"""
module ParametricExpressionModule

using DynamicExpressions:
    DynamicExpressions as DE,
    ParametricExpression,
    ParametricNode,
    get_metadata,
    get_contents,
    with_contents,
    get_tree
using StatsBase: StatsBase
using Random: default_rng, AbstractRNG

using ..CoreModule:
    AbstractOptions,
    Dataset,
    DATA_TYPE,
    AbstractMutationWeights,
    AbstractExpressionSpec,
    get_indices,
    ExpressionSpecModule as ES
using ..PopMemberModule: PopMember
using ..InterfaceDynamicExpressionsModule: InterfaceDynamicExpressionsModule as IDE
using ..LossFunctionsModule: LossFunctionsModule as LF
using ..ExpressionBuilderModule: ExpressionBuilderModule as EB
using ..MutateModule: MutateModule as MM
using ..MutationFunctionsModule: MutationFunctionsModule as MF
using ..ConstantOptimizationModule: ConstantOptimizationModule as CO

function EB.extra_init_params(
    ::Type{E},
    prototype::Union{Nothing,ParametricExpression},
    options::AbstractOptions,
    dataset::Dataset{T},
    ::Val{embed},
) where {T,embed,E<:ParametricExpression}
    num_params = options.expression_options.max_parameters
    num_classes = length(unique(dataset.extra.class))
    parameter_names = embed ? ["p$i" for i in 1:num_params] : nothing
    _parameters = if prototype === nothing
        randn(T, (num_params, num_classes))
    else
        copy(get_metadata(prototype).parameters)
    end
    return (; parameters=_parameters, parameter_names)
end
function EB.consistency_checks(options::AbstractOptions, prototype::ParametricExpression)
    @assert(
        options.expression_type <: ParametricExpression,
        "Need prototype to be of type $(options.expression_type), but got $(prototype)::$(typeof(prototype))"
    )
    if get_metadata(prototype).parameter_names !== nothing
        @assert(
            length(get_metadata(prototype).parameter_names) ==
                options.expression_options.max_parameters,
            "Mismatch between options.expression_options.max_parameters=$(options.expression_options.max_parameters) and prototype.metadata.parameter_names=$(get_metadata(prototype).parameter_names)"
        )
    end
    @assert size(get_metadata(prototype).parameters, 1) ==
        options.expression_options.max_parameters
    return nothing
end

function DE.eval_tree_array(
    tree::ParametricExpression,
    X::AbstractMatrix,
    class::AbstractVector{<:Integer},
    options::AbstractOptions;
    kws...,
)
    A = IDE.expected_array_type(X, typeof(tree))
    out, complete = DE.eval_tree_array(
        tree,
        X,
        class,
        DE.get_operators(tree, options);
        turbo=options.turbo,
        bumper=options.bumper,
        kws...,
    )
    return out::A, complete::Bool
end
function LF.eval_tree_dispatch(
    tree::ParametricExpression, dataset::Dataset, options::AbstractOptions
)
    A = IDE.expected_array_type(dataset.X, typeof(tree))
    indices = get_indices(dataset)
    out, complete = DE.eval_tree_array(
        tree,
        dataset.X,
        isnothing(indices) ? dataset.extra.class : view(dataset.extra.class, indices),
        options.operators,
    )
    return out::A, complete::Bool
end

function MM.condition_mutate_constant!(
    ::Type{<:ParametricExpression},
    weights::AbstractMutationWeights,
    member::PopMember,
    options::AbstractOptions,
    curmaxsize::Int,
)
    # Avoid modifying the mutate_constant weight, since
    # otherwise we would be mutating constants all the time!
    return nothing
end
function MF.make_random_leaf(
    nfeatures::Int,
    ::Type{T},
    ::Type{N},
    rng::AbstractRNG=default_rng(),
    options::Union{AbstractOptions,Nothing}=nothing,
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

function MF.crossover_trees(
    ex1::ParametricExpression{T},
    ex2::ParametricExpression{T},
    rng::AbstractRNG=default_rng(),
) where {T}
    tree1 = get_contents(ex1)
    tree2 = get_contents(ex2)
    out1, out2 = MF.crossover_trees(tree1, tree2, rng)
    ex1 = with_contents(ex1, out1)
    ex2 = with_contents(ex2, out2)

    # We also randomly share parameters
    nparams1 = size(get_metadata(ex1).parameters, 1)
    nparams2 = size(get_metadata(ex2).parameters, 1)
    num_params_switch = min(nparams1, nparams2)
    idx_to_switch = StatsBase.sample(
        rng, 1:num_params_switch, num_params_switch; replace=false
    )
    for param_idx in idx_to_switch
        # TODO: Ensure no issues from aliasing here
        ex2_params = get_metadata(ex2).parameters[param_idx, :]
        get_metadata(ex2).parameters[param_idx, :] .= get_metadata(ex1).parameters[
            param_idx, :,
        ]
        get_metadata(ex1).parameters[param_idx, :] .= ex2_params
    end

    return ex1, ex2
end

function CO.count_constants_for_optimization(ex::ParametricExpression)
    return CO.count_scalar_constants(get_tree(ex)) + length(get_metadata(ex).parameters)
end

function MF.mutate_constant(
    ex::ParametricExpression{T},
    temperature,
    options::AbstractOptions,
    rng::AbstractRNG=default_rng(),
) where {T<:DATA_TYPE}
    if rand(rng, Bool)
        # Normal mutation of inner constant
        tree = get_contents(ex)
        return with_contents(ex, MF.mutate_constant(tree, temperature, options, rng))
    else
        # Mutate parameters
        parameter_index = rand(rng, 1:(options.expression_options.max_parameters))
        # We mutate all the parameters at once
        factor = MF.mutate_factor(T, temperature, options, rng)
        get_metadata(ex).parameters[parameter_index, :] .*= factor
        return ex
    end
end

# ParametricExpression handles class columns
IDE.handles_class_column(::Type{<:ParametricExpression}) = true

"""
    ParametricExpressionSpec <: AbstractExpressionSpec

!!! warning
    `ParametricExpressionSpec` is no longer recommended. Please use `@template_spec` (creating a `TemplateExpressionSpec`) instead.

(Experimental) Specification for parametric expressions with configurable maximum parameters.
"""
struct ParametricExpressionSpec <: AbstractExpressionSpec
    max_parameters::Int

    function ParametricExpressionSpec(; max_parameters::Int, warn::Bool=true)
        # Build a generic deprecation message
        msg = """
        ParametricExpressionSpec is no longer recommended – it is both faster, safer, and more explicit to
        use TemplateExpressionSpec with the `@template_spec` macro instead.

        Example with @template_spec macro:

            n_categories = length(unique(X.class))
            expression_spec = @template_spec(
                expressions=(f,),
                parameters=($(join(["p$i=n_categories" for i in 1:max_parameters], ", "))),
            ) do x, #= other variable names..., =# category #= additional category feature =#
                f(x1, #= other variable names..., =#  $(join(["p$i[category]" for i in 1:max_parameters], ", ")))
            end

        Then, when passing your dataset, include another feature with the category column.
        """

        warn && @warn msg maxlog = 1

        return new(max_parameters)
    end
end

# COV_EXCL_START
ES.get_expression_type(::ParametricExpressionSpec) = ParametricExpression
ES.get_expression_options(spec::ParametricExpressionSpec) = (; spec.max_parameters)
ES.get_node_type(::ParametricExpressionSpec) = ParametricNode
# COV_EXCL_STOP

end
