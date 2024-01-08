module SymbolicRegressionLatexifyExt

using SymbolicRegression: Options, Node, string_tree
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
