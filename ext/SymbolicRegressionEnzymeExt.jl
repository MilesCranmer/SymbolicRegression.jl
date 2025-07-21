module SymbolicRegressionEnzymeExt

using SymbolicRegression.LossFunctionsModule: eval_loss
using DynamicExpressions:
    AbstractExpression,
    AbstractExpressionNode,
    get_scalar_constants,
    set_scalar_constants!,
    extract_gradient,
    with_contents,
    get_contents
using ADTypes: AutoEnzyme
using Enzyme: autodiff, Reverse, Active, Const, Duplicated, make_zero, remake_zero!

import SymbolicRegression.ConstantOptimizationModule: Evaluator, GradEvaluator

# We prepare a copy of the tree and all arrays
function GradEvaluator(f::F, backend::AE) where {F<:Evaluator,AE<:AutoEnzyme}
    storage_tree = make_zero(f.tree)
    _, storage_refs = get_scalar_constants(storage_tree)
    storage_dataset = make_zero(f.ctx.dataset)
    storage_options = make_zero(f.ctx.options)
    # TODO: It is super inefficient to deepcopy; how can we skip this
    return GradEvaluator(
        f,
        nothing,
        backend,
        (; storage_tree, storage_refs, storage_dataset, storage_options),
    )
end

function evaluator(tree, dataset, options, output)
    output[] = eval_loss(tree, dataset, options; regularization=false)
    return nothing
end

with_stacksize(f::F, n) where {F} = fetch(schedule(Task(f, n)))

function (g::GradEvaluator{<:Any,<:AutoEnzyme})(_, G, x::AbstractVector{T}) where {T}
    set_scalar_constants!(g.e.tree, x, g.e.refs)
    remake_zero!(g.extra.storage_tree)
    remake_zero!(g.extra.storage_dataset)
    remake_zero!(g.extra.storage_options)

    output = [zero(T)]
    doutput = [one(T)]

    with_stacksize(32 * 1024 * 1024) do
        autodiff(
            Reverse,
            evaluator,
            Duplicated(g.e.tree, g.extra.storage_tree),
            Duplicated(g.e.ctx.dataset, g.extra.storage_dataset),
            Duplicated(g.e.ctx.options, g.extra.storage_options),
            Duplicated(output, doutput),
        )
    end

    if G !== nothing
        # TODO: This is redundant since we already have the references.
        # Should just be able to extract from the references directly.
        G .= first(get_scalar_constants(g.extra.storage_tree))
    end
    return output[]
end

end
