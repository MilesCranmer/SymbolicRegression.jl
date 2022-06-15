module EquationModule

import ..ProgramConstantsModule: CONST_TYPE
import ..OptionsStructModule: Options

################################################################################
# Node defines a symbolic expression stored in a binary tree.
# A single `Node` instance is one "node" of this tree, and
# has references to its children. By tracing through the children
# nodes, you can evaluate or print a given expression.
mutable struct Node
    degree::Int  # 0 for constant/variable, 1 for cos/sin, 2 for +/* etc.
    constant::Bool  # false if variable
    val::CONST_TYPE  # If is a constant, this stores the actual value
    # ------------------- (possibly undefined below)
    feature::Int  # If is a variable (e.g., x in cos(x)), this stores the feature index.
    op::Int  # If operator, this is the index of the operator in options.binary_operators, or options.unary_operators
    l::Node  # Left child node. Only defined for degree=1 or degree=2.
    r::Node  # Right child node. Only defined for degree=2. 


    #################
    ## Constructors:
    #################
    Node(d::Int, c::Bool, v::CONST_TYPE) = new(d, c, v)
    Node(d::Int, c::Bool, v::CONST_TYPE, f::Int) = new(d, c, v, f)
    Node(d::Int, c::Bool, v::CONST_TYPE, f::Int, o::Int, l::Node) = new(d, c, v, f, o, l)
    function Node(d::Int, c::Bool, v::CONST_TYPE, f::Int, o::Int, l::Node, r::Node)
        return new(d, c, v, f, o, l, r)
    end
end
################################################################################

Node(val::CONST_TYPE) = Node(0, true, val) #Leave other values undefined
"""
    Node(feature::Int)

Create a variable node using feature `feature::Int`
"""
Node(feature::Int) = Node(0, false, convert(CONST_TYPE, 0.0f0), feature)
"""
    Node(op::Int, l::Node)

Apply unary operator `op` (enumerating over the order given) to `Node` `l`
"""
Node(op::Int, l::Node) = Node(1, false, convert(CONST_TYPE, 0.0f0), 0, op, l)
"""
    Node(op::Int, l::Union{AbstractFloat, Int})

Short-form for creating a scalar/variable node, and applying a unary operator
"""
function Node(op::Int, l::Union{AbstractFloat,Int})
    return Node(1, false, convert(CONST_TYPE, 0.0f0), 0, op, Node(l))
end
"""
    Node(op::Int, l::Node, r::Node)

Apply binary operator `op` (enumerating over the order given) to `Node`s `l` and `r`
"""
Node(op::Int, l::Node, r::Node) = Node(2, false, convert(CONST_TYPE, 0.0f0), 0, op, l, r)
"""
    Node(op::Int, l::Union{AbstractFloat, Int}, r::Node)

Short-form to create a scalar/variable node, and apply a binary operator
"""
function Node(op::Int, l::Union{AbstractFloat,Int}, r::Node)
    return Node(2, false, convert(CONST_TYPE, 0.0f0), 0, op, Node(l), r)
end
"""
    Node(op::Int, l::Node, r::Union{AbstractFloat, Int})

Short-form to create a scalar/variable node, and apply a binary operator
"""
function Node(op::Int, l::Node, r::Union{AbstractFloat,Int})
    return Node(2, false, convert(CONST_TYPE, 0.0f0), 0, op, l, Node(r))
end
"""
    Node(op::Int, l::Union{AbstractFloat, Int}, r::Union{AbstractFloat, Int})

Short-form for creating two scalar/variable node, and applying a binary operator
"""
function Node(op::Int, l::Union{AbstractFloat,Int}, r::Union{AbstractFloat,Int})
    return Node(2, false, convert(CONST_TYPE, 0.0f0), 0, op, Node(l), Node(r))
end
"""
    Node(val::AbstractFloat)

Create a scalar constant node
"""
Node(val::AbstractFloat) = Node(convert(CONST_TYPE, val))
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
function copy_node(tree::Node)::Node
    if tree.degree == 0
        if tree.constant
            return Node(copy(tree.val))
        else
            return Node(copy(tree.feature))
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

end
