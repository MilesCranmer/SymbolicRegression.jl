module SymbolicRegressionLatexifyExt

using SymbolicRegression:
    Options,
    Node,
    string_tree,
    plus,
    sub,
    mult,
    square,
    cube,
    pow,
    safe_pow,
    safe_log,
    safe_log2,
    safe_log10,
    safe_log1p,
    safe_sqrt,
    safe_acosh,
    neg,
    greater,
    cond,
    relu,
    logical_or,
    logical_and,
    gamma,
    erf,
    erfc,
    atanh_clip
using Latexify

@latexrecipe function latexify_node(::Node)
    throw(
        ArgumentError(
            "You must pass an Options object to latexify in addition to the `Node` object"
        ),
    )
end

@latexrecipe function latexify_node(tree::Node, options::Options; variable_names=:default)
    s = string_tree(
        tree,
        options;
        raw=false,
        variable_names=(variable_names == :default ? nothing : variable_names),
    )
    return s
end

end
