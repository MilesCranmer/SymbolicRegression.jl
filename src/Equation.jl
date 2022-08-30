module EquationModule

import ..ProgramConstantsModule: CONST_TYPE
import ..OptionsStructModule: Options

################################################################################
# Node defines a symbolic expression stored in a binary tree.
# A single `Node` instance is one "node" of this tree, and
# has references to its children. By tracing through the children
# nodes, you can evaluate or print a given expression.
mutable struct Node{T<:AbstractFloat}
    degree::Int  # 0 for constant/variable, 1 for cos/sin, 2 for +/* etc.
    constant::Bool  # false if variable
    val::T  # If is a constant, this stores the actual value
    # ------------------- (possibly undefined below)
    feature::Int  # If is a variable (e.g., x in cos(x)), this stores the feature index.
    op::Int  # If operator, this is the index of the operator in options.binary_operators, or options.unary_operators
    l::Node{T}  # Left child node. Only defined for degree=1 or degree=2.
    r::Node{T}  # Right child node. Only defined for degree=2. 

    #################
    ## Constructors:
    #################
    Node(d::Int, c::Bool, v::_T) where {_T<:AbstractFloat} = new{_T}(d, c, v)
    Node(d::Int, c::Bool, v::_T, f::Int) where {_T<:AbstractFloat} = new{_T}(d, c, v, f)
    function Node(
        d::Int, c::Bool, v::_T, f::Int, o::Int, l::Node{_T}
    ) where {_T<:AbstractFloat}
        return new{_T}(d, c, v, f, o, l)
    end
    function Node(
        d::Int, c::Bool, v::_T, f::Int, o::Int, l::Node{_T}, r::Node{_T}
    ) where {_T<:AbstractFloat}
        return new{_T}(d, c, v, f, o, l, r)
    end
end
################################################################################

function Base.convert(::Type{Node{T1}}, tree::Node{T2}) where {T1,T2}
    if T1 == T2
        return tree
    elseif tree.degree == 0
        if tree.constant
            return Node(0, tree.constant, convert(T1, tree.val))
        else
            return Node(0, tree.constant, convert(T1, tree.val), tree.feature)
        end
    elseif tree.degree == 1
        l = convert(Node{T1}, tree.l)
        return Node(1, tree.constant, convert(T1, tree.val), tree.feature, tree.op, l)
    else
        l = convert(Node{T1}, tree.l)
        r = convert(Node{T1}, tree.r)
        return Node(2, tree.constant, convert(T1, tree.val), tree.feature, tree.op, l, r)
    end
end

"""
    Node(val::AbstractFloat)

Create a scalar constant node
"""
Node(val::T) where {T<:AbstractFloat} = Node(0, true, val) #Leave other values undefined

"""
    Node(feature::Int)

Create a variable node using feature `feature::Int`
"""
Node(feature::Int) = Node(0, false, convert(CONST_TYPE, 0), feature)
"""
    Node(feature::Int)

Create a variable node using feature `feature::Int`, while specifying the node type.
"""
function Node(feature::Int, ::Type{T}) where {T<:AbstractFloat}
    return Node(0, false, convert(T, 0), feature)
end

"""
    Node(op::Int, l::Node)

Apply unary operator `op` (enumerating over the order given) to `Node` `l`
"""
Node(op::Int, l::Node{T}) where {T} = Node(1, false, convert(T, 0), 0, op, l)

"""
    Node(op::Int, l::AbstractFloat)

Short-form for creating a scalar node, and applying a unary operator
"""
function Node(op::Int, l::T) where {T<:AbstractFloat}
    return Node(1, false, convert(T, 0), 0, op, Node(l))
end
"""
    Node(op::Int, l::Int)

Short-form for creating a variable node, and applying a unary operator
"""
function Node(op::Int, l::Int)
    return Node(1, false, convert(CONST_TYPE, 0), 0, op, Node(l))
end

"""
    Node(op::Int, l::Node, r::Node)

Apply binary operator `op` (enumerating over the order given) to `Node`s `l` and `r`
"""
function Node(op::Int, l::Node{T1}, r::Node{T2}) where {T1<:AbstractFloat,T2<:AbstractFloat}
    # Get highest type:
    T = promote_type(T1, T2)
    l = convert(Node{T}, l)
    r = convert(Node{T}, r)
    return Node(2, false, convert(T, 0), 0, op, l, r)
end
"""
    Node(op::Int, l::Union{AbstractFloat, Int}, r::Node)

Short-form to create a scalar/variable node, and apply a binary operator
"""
function Node(op::Int, l::T2, r::Node{T1}) where {T1<:AbstractFloat,T2<:AbstractFloat}
    T = promote_type(T1, T2)
    l = convert(T, l)
    r = convert(Node{T}, r)
    return Node(2, false, convert(T, 0.0f0), 0, op, Node(l), r)
end
function Node(op::Int, l::Int, r::Node{T}) where {T<:AbstractFloat}
    return Node(2, false, convert(T, 0), 0, op, Node(l, T), r)
end

"""
    Node(op::Int, l::Node, r::Union{AbstractFloat, Int})

Short-form to create a scalar node, and apply a binary operator
"""
function Node(op::Int, l::Node{T1}, r::T2) where {T1<:AbstractFloat,T2<:AbstractFloat}
    T = promote_type(T1, T2)
    l = convert(Node{T}, l)
    r = convert(T, r)
    return Node(2, false, convert(T, 0), 0, op, l, Node(r))
end
"""
    Node(op::Int, l::Node, r::Union{AbstractFloat, Int})

Short-form to create a variable node, and apply a binary operator
"""
function Node(op::Int, l::Node{T}, r::Int) where {T<:AbstractFloat}
    return Node(2, false, convert(T, 0), 0, op, l, Node(r, T))
end

"""
    Node(op::Int, l::Union{AbstractFloat, Int}, r::Union{AbstractFloat, Int})

Short-form for creating two scalar/variable node, and applying a binary operator
"""
function Node(
    op::Int, l::T1, r::T2
) where {T1<:Union{AbstractFloat,Int},T2<:Union{AbstractFloat,Int}}
    if T1 <: AbstractFloat && T2 <: AbstractFloat
        T = promote_type(T1, T2)
        l = convert(T, l)
        r = convert(T, r)
        return Node(2, false, convert(T, 0.0f0), 0, op, Node(l), Node(r))
    elseif T1 <: AbstractFloat
        return Node(2, false, convert(T1, 0.0f0), 0, op, Node(l), Node(r, T1))
    elseif T2 <: AbstractFloat
        return Node(2, false, convert(T2, 0.0f0), 0, op, Node(l, T2), Node(r))
    else
        return Node(2, false, convert(CONST_TYPE, 0.0f0), 0, op, Node(l), Node(r))
    end
end
"""
    Node(var_string::String)

Create a variable node, using the format `"x1"` to mean feature 1
"""
Node(var_string::String) = Node(parse(Int, var_string[2:end]))
"""
    Node(var_string::String, varMap::Array{String, 1})

Create a variable node, using a user-passed format
"""
function Node(var_string::String, varMap::Array{String,1})
    return Node(
        [i for (i, _variable) in enumerate(varMap) if _variable == var_string][1]::Int
    )
end

# Copy an equation (faster than deepcopy)
function copy_node(tree::Node{T})::Node{T} where {T}
    if tree.degree == 0
        if tree.constant
            return Node(copy(tree.val))
        else
            return Node(copy(tree.feature), T)
        end
    elseif tree.degree == 1
        return Node(copy(tree.op), copy_node(tree.l))
    else
        return Node(copy(tree.op), copy_node(tree.l), copy_node(tree.r))
    end
end

function string_op(
    op::F,
    tree::Node,
    options::Options;
    bracketed::Bool=false,
    varMap::Union{Array{String,1},Nothing}=nothing,
)::String where {F}
    if op in [+, -, *, /, ^]
        l = string_tree(tree.l, options; bracketed=false, varMap=varMap)
        r = string_tree(tree.r, options; bracketed=false, varMap=varMap)
        if bracketed
            return "$l $(string(op)) $r"
        else
            return "($l $(string(op)) $r)"
        end
    else
        l = string_tree(tree.l, options; bracketed=true, varMap=varMap)
        r = string_tree(tree.r, options; bracketed=true, varMap=varMap)
        return "$(string(op))($l, $r)"
    end
end

"""
    string_tree(tree::Node, options::Options; kws...)

Convert an equation to a string.

# Arguments

- `varMap::Union{Array{String, 1}, Nothing}=nothing`: what variables
    to print for each feature.
"""
function string_tree(
    tree::Node,
    options::Options;
    bracketed::Bool=false,
    varMap::Union{Array{String,1},Nothing}=nothing,
)::String
    if tree.degree == 0
        if tree.constant
            return string(tree.val)
        else
            if varMap === nothing
                return "x$(tree.feature)"
            else
                return varMap[tree.feature]
            end
        end
    elseif tree.degree == 1
        return "$(options.unaops[tree.op])($(string_tree(tree.l, options, bracketed=true, varMap=varMap)))"
    else
        return string_op(
            options.binops[tree.op], tree, options; bracketed=bracketed, varMap=varMap
        )
    end
end

# Print an equation
function print_tree(
    io::IO, tree::Node, options::Options; varMap::Union{Array{String,1},Nothing}=nothing
)
    return println(io, string_tree(tree, options; varMap=varMap))
end

function print_tree(
    tree::Node, options::Options; varMap::Union{Array{String,1},Nothing}=nothing
)
    return println(string_tree(tree, options; varMap=varMap))
end

function Base.hash(tree::Node)::UInt
    if tree.degree == 0
        if tree.constant
            # tree.val used.
            return hash((0, tree.val))
        else
            # tree.feature used.
            return hash((1, tree.feature))
        end
    elseif tree.degree == 1
        return hash((1, tree.op, hash(tree.l)))
    else
        return hash((2, tree.op, hash(tree.l), hash(tree.r)))
    end
end

end
