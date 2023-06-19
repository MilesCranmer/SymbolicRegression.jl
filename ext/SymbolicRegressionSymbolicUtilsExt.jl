module SymbolicRegressionSymbolicUtilsExt

import Base: convert
if isdefined(Base, :get_extension)
    using SymbolicUtils: Symbolic
    import SymbolicRegression: node_to_symbolic, symbolic_to_node
    import SymbolicRegression: Node, Options
else
    using ..SymbolicUtils: Symbolic
    import ..SymbolicRegression: node_to_symbolic, symbolic_to_node
    import ..SymbolicRegression: Node, Options
end

"""
    node_to_symbolic(tree::Node, options::Options; kws...)

Convert an expression to SymbolicUtils.jl form. 
"""
function node_to_symbolic(tree::Node, options::Options; kws...)
    return node_to_symbolic(tree, options.operators; kws...)
end

"""
    symbolic_to_node(eqn::Symbolic, options::Options; kws...)

Convert a SymbolicUtils.jl expression to SymbolicRegression.jl's `Node` type.
"""
function symbolic_to_node(eqn::Symbolic, options::Options; kws...)
    return symbolic_to_node(eqn, options.operators; kws...)
end

function convert(::Type{Symbolic}, tree::Node, options::Options; kws...)
    return convert(Symbolic, tree, options.operators; kws...)
end

function convert(::Type{Node}, x::Union{Number,Symbolic}, options::Options; kws...)
    return convert(Node, x, options.operators; kws...)
end

end
