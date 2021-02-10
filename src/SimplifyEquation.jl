using FromFile
@from "Core.jl" import CONST_TYPE, Node, copyNode, Options
@from "EquationUtils.jl" import countNodes
@from "CustomSymbolicUtilsSimplification.jl" import custom_simplify
@from "InterfaceSymbolicUtils.jl" import node_to_symbolic, symbolic_to_node
@from "CheckConstraints.jl" import check_constraints

# Simplify tree
function combineOperators(tree::Node, options::Options)::Node
    # NOTE: (const (+*-) const) already accounted for. Call simplifyTree before.
    # ((const + var) + const) => (const + var)
    # ((const * var) * const) => (const * var)
    # ((const - var) - const) => (const - var)
    # (want to add anything commutative!)
    # TODO - need to combine plus/sub if they are both there.
    if tree.degree == 0
        return tree
    elseif tree.degree == 1
        tree.l = combineOperators(tree.l, options)
    elseif tree.degree == 2
        tree.l = combineOperators(tree.l, options)
        tree.r = combineOperators(tree.r, options)
    end

    top_level_constant = tree.degree == 2 && (tree.l.constant || tree.r.constant)
    if tree.degree == 2 && (options.binops[tree.op] == (*) || options.binops[tree.op] == (+)) && top_level_constant
        op = tree.op
        # Put the constant in r. Need to assume var in left for simplification assumption.
        if tree.l.constant
            tmp = tree.r
            tree.r = tree.l
            tree.l = tmp
        end
        topconstant = tree.r.val
        # Simplify down first
        below = tree.l
        if below.degree == 2 && below.op == op
            if below.l.constant
                tree = below
                tree.l.val = options.binops[op](tree.l.val, topconstant)
            elseif below.r.constant
                tree = below
                tree.r.val = options.binops[op](tree.r.val, topconstant)
            end
        end
    end

    if tree.degree == 2 && options.binops[tree.op] == (-) && top_level_constant
        # Currently just simplifies subtraction. (can't assume both plus and sub are operators)
        # Not commutative, so use different op.
        if tree.l.constant
            if tree.r.degree == 2 && options.binops[tree.r.op] == (-)
                if tree.r.l.constant
                    #(const - (const - var)) => (var - const)
                    l = tree.l
                    r = tree.r
                    simplified_const = -(l.val - r.l.val) #neg(sub(l.val, r.l.val))
                    tree.l = tree.r.r
                    tree.r = l
                    tree.r.val = simplified_const
                elseif tree.r.r.constant
                    #(const - (var - const)) => (const - var)
                    l = tree.l
                    r = tree.r
                    simplified_const = l.val + r.r.val #plus(l.val, r.r.val)
                    tree.r = tree.r.l
                    tree.l.val = simplified_const
                end
            end
        else #tree.r.constant is true
            if tree.l.degree == 2 && options.binops[tree.l.op] == (-)
                if tree.l.l.constant
                    #((const - var) - const) => (const - var)
                    l = tree.l
                    r = tree.r
                    simplified_const = l.l.val - r.val#sub(l.l.val, r.val)
                    tree.r = tree.l.r
                    tree.l = r
                    tree.l.val = simplified_const
                elseif tree.l.r.constant
                    #((var - const) - const) => (var - const)
                    l = tree.l
                    r = tree.r
                    simplified_const = r.val + l.r.val #plus(r.val, l.r.val)
                    tree.l = tree.l.l
                    tree.r.val = simplified_const
                end
            end
        end
    end
    return tree
end

# Simplify tree
function simplifyTree(tree::Node, options::Options)::Node
    if tree.degree == 1
        tree.l = simplifyTree(tree.l, options)
        if tree.l.degree == 0 && tree.l.constant
            return Node(convert(CONST_TYPE, options.unaops[tree.op](tree.l.val)))
        end
    elseif tree.degree == 2
        tree.l = simplifyTree(tree.l, options)
        tree.r = simplifyTree(tree.r, options)
        constantsBelow = (
             tree.l.degree == 0 && tree.l.constant &&
             tree.r.degree == 0 && tree.r.constant
        )
        if constantsBelow
            return Node(convert(CONST_TYPE, options.binops[tree.op](tree.l.val, tree.r.val)))
        end
    end
    return tree
end


# Expensive but powerful simplify using SymbolicUtils
function simplifyWithSymbolicUtils(tree::Node, options::Options)::Node
    if !(((+) in options.binops) && ((*) in options.binops))
        return tree
    end
    init_node = copyNode(tree)
    init_size = countNodes(tree)
    symbolic_util_form = node_to_symbolic(tree, options, index_functions=true)
    eqn_form = custom_simplify(symbolic_util_form, options)
    final_node = symbolic_to_node(eqn_form, options)
    final_size = countNodes(tree)
    did_simplification_improve = (final_size <= init_size) && (check_constraints(final_node, options))
    output = did_simplification_improve ? final_node : init_node

    return output
end

