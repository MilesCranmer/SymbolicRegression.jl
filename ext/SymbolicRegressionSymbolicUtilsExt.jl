module SymbolicRegressionSymbolicUtilsExt

import Base: convert
if isdefined(Base, :get_extension)
    using SymbolicUtils
    import SymbolicRegression: node_to_symbolic, symbolic_to_node
    import SymbolicRegression: Node, Options
else
    using ..SymbolicUtils
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
    node_to_symbolic(eqn::T, options::Options; kws...) where {T}

Convert a SymbolicUtils.jl expression to SymbolicRegression.jl's `Node` type.
"""
function symbolic_to_node(
    eqn::T, options::Options; kws...
) where {T<:SymbolicUtils.Symbolic}
    return symbolic_to_node(eqn, options.operators; kws...)
end

function convert(s::typeof(SymbolicUtils.Symbolic), tree::Node, options::Options; kws...)
    return convert(s, tree, options.operators; kws...)
end

function convert(
    n::typeof(Node), x::Union{Number,SymbolicUtils.Symbolic}, options::Options; kws...
)
    return convert(n, x, options.operators; kws...)
end

end