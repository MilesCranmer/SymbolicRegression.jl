module SymbolicRegressionEnzymeExt

import Enzyme: autodiff, Duplicated, Const, Reverse
import SymbolicRegression: Dataset, Options
import SymbolicRegression.ConstantOptimizationModule: opt_func!, opt_func_g!

@inline function opt_func_g!(
    x,
    dx,
    dataset::Dataset{T,L},
    tree,
    ctree,
    constant_nodes,
    c_constant_nodes,
    options::Options,
    idx,
) where {T,L}
    result = [zero(L)]
    dresult = [one(L)]
    dx .= one(T)
    foreach(ctree) do t
        if t.degree == 0 && t.constant
            t.val::T = zero(T)
        end
    end
    autodiff(
        Reverse,
        opt_func!,
        Duplicated(result, dresult),
        Duplicated(x, dx),
        Const(dataset),
        Duplicated(tree, ctree),
        Duplicated(constant_nodes, c_constant_nodes),
        Const(options),
        Const(idx),
    )
    return nothing
end

end
