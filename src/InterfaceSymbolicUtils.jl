using FromFile
using SymbolicUtils
@from "Core.jl" import CONST_TYPE, Node, Options
@from "Utils.jl" import isgood, isbad, @return_on_false

const SYMBOLIC_UTILS_TYPES = Union{<:Number,SymbolicUtils.Sym{<:Number},SymbolicUtils.Term{<:Number}}

const SUPPORTED_OPS = (cos, sin, exp, cot, tan, csc, sec, +, -, *, /)

isgood(x::SymbolicUtils.Symbolic) = SymbolicUtils.istree(x) ? all(isgood.([SymbolicUtils.operation(x);SymbolicUtils.arguments(x)])) : true
subs_bad(x) = isgood(x) ? x : Inf

function parse_tree_to_eqs(tree::Node, options::Options, index_functions::Bool=false, evaluate_functions::Bool=false)
    if tree.degree == 0
        # Return constant if needed
        tree.constant && return subs_bad(tree.val)
        return SymbolicUtils.Sym{Number}(Symbol("x$(tree.feature)"))
    end
    # Collect the next children
    children = tree.degree >= 2 ? (tree.l, tree.r) : (tree.l,)
    # Get the operation
    op = tree.degree > 1 ? options.binops[tree.op] : options.unaops[tree.op]
    # Create an N tuple of Numbers for each argument
    dtypes = map(x->Number, 1:tree.degree)
    #
    if index_functions
        op = SymbolicUtils.Sym{(SymbolicUtils.FnType){Tuple{dtypes...}, Number}}(Symbol(op))
    else
        op = ((op ∈ SUPPORTED_OPS) || evaluate_functions) ? op : SymbolicUtils.Sym{(SymbolicUtils.FnType){Tuple{dtypes...}, Number}}(Symbol(op))
    end
    return subs_bad(op(map(x->parse_tree_to_eqs(x, options, index_functions, evaluate_functions), children)...))
end

## Convert symbolic function back
convert_to_function(x, args...) = x

function convert_to_function(x::SymbolicUtils.Sym{SymbolicUtils.FnType{T, Number}}, options::Options) where {T <: Tuple}
    degree = length(T.types)
    if degree == 1
        ind = findoperation(x.name, options.unaops)
        return options.unaops[ind]
    elseif degree == 2
        ind = findoperation(x.name, options.binops)
        return options.binops[ind]
    else
        throw(AssertionError("Function $(String(x.name)) has degree > 2 !"))
    end
end

# Split equation
function split_eq(op, args, options::Options; varMap::Union{Array{String, 1}, Nothing}=nothing)
    !(op ∈ (sum, prod, +, *)) && throw(error("Unsupported operation $op in expression!"))
    if Symbol(op) == Symbol(sum)
        ind = findoperation(+, options.binops)
    elseif Symbol(op) === Symbol(prod)
        ind = findoperation(*, options.binops)
    else
        ind = findoperation(op, options.binops)
    end
    return Node(ind, convert(Node, args[1], options; varMap=varMap), convert(Node, op(args[2:end]...), options; varMap=varMap))
end

function findoperation(op, ops)
    for (i,oi) in enumerate(ops)
        Symbol(oi) == Symbol(op) && return i
    end
end

function Base.convert(::typeof(Node), x::Number, options::Options; varMap::Union{Array{String, 1}, Nothing}=nothing)
    return Node(x)
end

function Base.convert(::typeof(Node), x::Symbol, options::Options; varMap::Union{Array{String, 1}, Nothing}=nothing)
    varMap == nothing && return Node(String(x))
    return Node(String(x), varMap=varMap)
end

function Base.convert(::typeof(Node), x::SymbolicUtils.Symbolic, options::Options; varMap::Union{Array{String, 1}, Nothing}=nothing)
    if !SymbolicUtils.istree(x)
        varMap == nothing && return Node(String(x.name))
        return Node(String(x.name), varMap)
    end

    op = convert_to_function(SymbolicUtils.operation(x))
    args = SymbolicUtils.arguments(x)

    length(args) > 2 && return split_eq(op, args, options; varMap=varMap)
    ind = length(args) == 2 ? findoperation(op, options.binops) : findoperation(op, options.unaops)

    return Node(ind, map(x->convert(Node, x, options, varMap=varMap), args)...)
end

"""
    node_to_symbolic(tree::Node, options::Options;
                varMap::Union{Array{String, 1}, Nothing}=nothing,
                evaluate_functions::Bool=false,
                index_functions::Bool=false)

The interface to SymbolicUtils.jl. Passing a tree to this function
will generate a symbolic equation in SymbolicUtils.jl format.

## Arguments

- `tree::Node`: The equation to convert.
- `options::Options`: Options, which contains the operators used in the equation.
- `varMap::Union{Array{String, 1}, Nothing}=nothing`: What variable names to use for
    each feature. Default is [x1, x2, x3, ...].
- `evaluate_functions::Bool=false`: Whether to evaluate the operators, or
    leave them as symbolic.
- `index_functions::Bool=false`: Whether to generate special names for the
    operators, which then allows one to convert back to a `Node` format
    using `symbolic_to_node`.
"""
function node_to_symbolic(tree::Node, options::Options;
                     varMap::Union{Array{String, 1}, Nothing}=nothing,
                     evaluate_functions::Bool=false,
                     index_functions::Bool=false
                     )
    expr = subs_bad(parse_tree_to_eqs(tree, options, index_functions, evaluate_functions))
    # Check for NaN and Inf
    @assert isgood(expr) "The recovered equation contains NaN or Inf."
    # Return if no varMap is given
    varMap == nothing && return expr
    # Create a substitution tuple
    subs = Dict(
        [SymbolicUtils.Sym{Number}(Symbol("x$(i)")) => SymbolicUtils.Sym{Number}(Symbol(varMap[i])) for i in 1:length(varMap)]...
    )
    return substitute(expr, subs)
end

function symbolic_to_node(eqn::T, options::Options;
                          varMap::Union{Array{String, 1}, Nothing}=nothing)::Node where {T<:SymbolicUtils.Symbolic}

    convert(Node, eqn, options; varMap=varMap)
end
