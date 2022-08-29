module EquationModule

import ..OptionsStructModule: Options

################################################################################
# Node defines a symbolic expression stored in a binary tree.
# A single `Node` instance is one "node" of this tree, and
# has references to its children. By tracing through the children
# nodes, you can evaluate or print a given expression.
# `CT` is the type of constants. It is assumed to be the same type for all children.
mutable struct Node{CT<:AbstractFloat} 
    degree::Int  # 0 for constant/variable, 1 for cos/sin, 2 for +/* etc.
    constant::Bool  # false if variable
    val::CT  # If is a constant, this stores the actual value
    # ------------------- (possibly undefined below)
    feature::Int  # If is a variable (e.g., x in cos(x)), this stores the feature index.
    op::Int  # If operator, this is the index of the operator in options.binary_operators, or options.unary_operators
    l::Node{CT}  # Left child node. Only defined for degree=1 or degree=2.
    r::Node{CT}  # Right child node. Only defined for degree=2. 

    #################
    ## Constructors:
    #################
    Node(d::Int, c::Bool, v::_CT) where {_CT<:AbstractFloat} = new{_CT}(d, c, v)
    Node(d::Int, c::Bool, v::_CT, f::Int) where {_CT<:AbstractFloat}  = new{_CT}(d, c, v, f)
    Node(d::Int, c::Bool, v::_CT, f::Int, o::Int, l::Node) where {_CT<:AbstractFloat}  = new{_CT}(d, c, v, f, o, l)
    function Node(d::Int, c::Bool, v::_CT, f::Int, o::Int, l::Node, r::Node) where {_CT<:AbstractFloat} 
        return new{_CT}(d, c, v, f, o, l, r)
    end
end
################################################################################

function Base.convert(::Type{Node{CT1}}, tree::Node{CT2}) where {CT1,CT2}
    if tree.degree == 0
        return Node(0, tree.constant, convert(CT1, tree.val))
    elseif tree.degree == 1
        return Node(1, tree.constant, convert(CT1, tree.val), tree.feature, tree.op, tree.l)
    else
        return Node(2, tree.constant, convert(CT1, tree.val), tree.feature, tree.op, tree.l, tree.r)
    end
end

Node(val::CT) where {CT<:AbstractFloat} = Node(0, true, val) #Leave other values undefined
Node(val::CT, ::Type{CT}) where {CT<:AbstractFloat} = Node(0, true, val) #Leave other values undefined

"""
    Node(feature::Int)

Create a variable node using feature `feature::Int`
"""
Node(feature::Int, ::Type{CT}) where {CT<:AbstractFloat}  = Node(0, false, convert(CT, 0.0f0), feature)
"""
    Node(op::Int, l::Node)

Apply unary operator `op` (enumerating over the order given) to `Node` `l`
"""
Node(op::Int, l::Node{CT}) where {CT} = Node(1, false, convert(CT, 0.0f0), 0, op, l)
"""
    Node(op::Int, l::AbstractFloat)

Short-form for creating a scalar/variable node, and applying a unary operator
"""
function Node(op::Int, l::CT) where {CT<:AbstractFloat}
    return Node(1, false, convert(CT, 0.0f0), 0, op, Node(l, CT))
end
"""
    Node(op::Int, l::Int)

Short-form for creating a scalar/variable node, and applying a unary operator
"""
function Node(op::Int, l::Int, ::Type{CT}) where {CT<:AbstractFloat}
    return Node(1, false, 0.0f0, 0, op, Node(l, CT))
end
"""
    Node(op::Int, l::Node, r::Node)

Apply binary operator `op` (enumerating over the order given) to `Node`s `l` and `r`
"""
Node(op::Int, l::Node{CT}, r::Node{CT}) where {CT} = Node(2, false, convert(CT, 0.0f0), 0, op, l, r)
"""
    Node(op::Int, l::AbstractFloat, r::Node)

Short-form to create a scalar node, and apply a binary operator
"""
function Node(op::Int, l::CT, r::Node{CT}) where {CT<:AbstractFloat}
    return Node(2, false, convert(CT, 0.0f0), 0, op, Node(l, CT), r)
end
"""
    Node(op::Int, l::Int, r::Node)

Short-form to create a variable node, and apply a binary operator
"""
function Node(op::Int, l::Int, r::Node{CT}) where {CT<:AbstractFloat}
    return Node(2, false, convert(CT, 0.0f0), 0, op, Node(l, CT), r)
end
"""
    Node(op::Int, l::Node, r::AbstractFloat)

Short-form to create a scalar node, and apply a binary operator
"""
function Node(op::Int, l::Node{CT}, r::CT) where {CT<:AbstractFloat}
    return Node(2, false, convert(CT, 0.0f0), 0, op, l, Node(r, CT))
end
"""
    Node(op::Int, l::Node, r::Int)

Short-form to create a variable node, and apply a binary operator
"""
function Node(op::Int, l::Node{CT}, r::Int) where {CT<:AbstractFloat}
    return Node(2, false, convert(CT, 0.0f0), 0, op, l, Node(r, CT))
end
"""
    Node(op::Int, l::Union{AbstractFloat, Int}, r::Union{AbstractFloat, Int})

Short-form for creating two scalar/variable node, and applying a binary operator
"""
function Node(op::Int, l::CT1, r::CT2; CT::Union{Type{CT},Nothing}=nothing) where {CT1,CT2}
    if CT1 <: AbstractFloat
        float_type = CT1
        if CT2 <: AbstractFloat
            # If they are both floats, must be the same type!
            @assert CT1 == CT2
        end
    elseif CT2 <: AbstractFloat
        float_type = CT2
    else
        @assert CT !== nothing
        float_type = CT
    end
    return Node(2, false, convert(float_type, 0.0f0), 0, op, Node(l, float_type), Node(r, float_type))
end
"""
    Node(var_string::String)

Create a variable node, using the format `"x1"` to mean feature 1
"""
Node(var_string::String, ::Type{CT}) where {CT} = Node(parse(Int, var_string[2:end]), CT)
"""
    Node(var_string::String, varMap::Array{String, 1})

Create a variable node, using a user-passed format
"""
function Node(var_string::String, varMap::Array{String,1}, ::Type{CT}) where {CT}
    return Node(
        [i for (i, _variable) in enumerate(varMap) if _variable == var_string][1]::Int,
        CT
    )
end

# Copy an equation (faster than deepcopy)
function copy_node(tree::Node{CT})::Node{CT} where {CT}
    if tree.degree == 0
        if tree.constant
            return Node(copy(tree.val), CT)
        else
            return Node(copy(tree.feature), CT)
        end
    elseif tree.degree == 1
        return Node(copy(tree.op), copy_node(tree.l), CT)
    else
        return Node(copy(tree.op), copy_node(tree.l), copy_node(tree.r), CT)
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
