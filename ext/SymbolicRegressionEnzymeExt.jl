module LaSREnzymeExt

using LaSR.LossFunctionsModule: eval_loss
using DynamicExpressions:
    AbstractExpression,
    AbstractExpressionNode,
    get_scalar_constants,
    set_scalar_constants!,
    extract_gradient,
    with_contents,
    get_contents
using ADTypes: AutoEnzyme
using Enzyme: autodiff, Reverse, Active, Const, Duplicated

import LaSR.ConstantOptimizationModule: GradEvaluator

# We prepare a copy of the tree and all arrays
function GradEvaluator(f::F, backend::AE) where {F,AE<:AutoEnzyme}
    storage_tree = copy(f.tree)
    _, storage_refs = get_scalar_constants(storage_tree)
    storage_dataset = deepcopy(f.dataset)
    # TODO: It is super inefficient to deepcopy; how can we skip this
    return GradEvaluator(f, backend, (; storage_tree, storage_refs, storage_dataset))
end

function evaluator(tree, dataset, options, idx, output)
    output[] = eval_loss(tree, dataset, options; regularization=false, idx=idx)
    return nothing
end

with_stacksize(f::F, n) where {F} = fetch(schedule(Task(f, n)))

function (g::GradEvaluator{<:Any,<:AutoEnzyme})(_, G, x::AbstractVector{T}) where {T}
    set_scalar_constants!(g.f.tree, x, g.f.refs)
    set_scalar_constants!(g.extra.storage_tree, zero(x), g.extra.storage_refs)
    fill!(g.extra.storage_dataset, 0)

    output = [zero(T)]
    doutput = [one(T)]

    with_stacksize(32 * 1024 * 1024) do
        autodiff(
            Reverse,
            evaluator,
            Duplicated(g.f.tree, g.extra.storage_tree),
            Duplicated(g.f.dataset, g.extra.storage_dataset),
            Const(g.f.options),
            Const(g.f.idx),
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
