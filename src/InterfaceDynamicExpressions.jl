using SymbolicUtils: SymbolicUtils

function eval_tree_array(tree::Node, X::AbstractArray, options::Options; kws...)
    return eval_tree_array(tree, X, options.operators; kws...)
end

function eval_diff_tree_array(
    tree::Node, X::AbstractArray, options::Options, direction::Int
)
    return eval_diff_tree_array(tree, X, options.operators, direction)
end

function eval_grad_tree_array(tree::Node, X::AbstractArray, options::Options; kws...)
    return eval_grad_tree_array(tree, X, options.operators; kws...)
end

function differentiable_eval_tree_array(
    tree::Node, X::AbstractArray, options::Options; kws...
)
    return differentiable_eval_tree_array(tree, X, options.operators; kws...)
end

function string_tree(tree::Node, options::Options; kws...)
    return string_tree(tree, options.operators; kws...)
end
function print_tree(tree::Node, options::Options; kws...)
    return print_tree(tree, options.operators; kws...)
end
function print_tree(io::IO, tree::Node, options::Options; kws...)
    return print_tree(io, tree, options.operators; kws...)
end

function Base.convert(::Type{Node{T}}, tree::Node, options::Options) where {T}
    return convert(Node{T}, tree, options.operators)
end

function Base.convert(
    s::typeof(SymbolicUtils.Symbolic), tree::Node, options::Options; kws...
)
    return convert(s, tree, options.operators; kws...)
end

function Base.convert(
    n::typeof(Node), x::Union{Number,SymbolicUtils.Symbolic}, options::Options; kws...
)
    return convert(n, x, options.operators; kws...)
end

function node_to_symbolic(tree::Node, options::Options; kws...)
    return node_to_symbolic(tree, options.operators; kws...)
end

function symbolic_to_node(
    eqn::T, options::Options; kws...
) where {T<:SymbolicUtils.Symbolic}
    return symbolic_to_node(eqn, options.operators; kws...)
end
