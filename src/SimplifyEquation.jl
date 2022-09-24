module SimplifyEquationModule

import ..CoreModule: Node, left, right, set_left!, set_right!, copy_node, Options
import ..CheckConstraintsModule: check_constraints
import ..UtilsModule: isbad, isgood

# Simplify tree
function combine_operators(tree::Node{T}, options::Options)::Node{T} where {T}
    # NOTE: (const (+*-) const) already accounted for. Call simplify_tree before.
    # ((const + var) + const) => (const + var)
    # ((const * var) * const) => (const * var)
    # ((const - var) - const) => (const - var)
    # (want to add anything commutative!)
    # TODO - need to combine plus/sub if they are both there.
    if tree.degree == 0
        return tree
    elseif tree.degree == 1
        set_left!(tree, combine_operators(left(tree), options))
    elseif tree.degree == 2
        set_left!(tree, combine_operators(left(tree), options))
        set_right!(tree, combine_operators(tree.r, options))
    end

    top_level_constant = tree.degree == 2 && (left(tree).constant || tree.r.constant)
    if tree.degree == 2 &&
        (options.binops[tree.op] == (*) || options.binops[tree.op] == (+)) &&
        top_level_constant
        op = tree.op
        # Put the constant in r. Need to assume var in left for simplification assumption.
        if left(tree).constant
            tmp = tree.r
            set_right!(tree, left(tree))
            set_left!(tree, tmp)
        end
        topconstant = tree.r.val
        # Simplify down first
        below = left(tree)
        if below.degree == 2 && below.op == op
            if left(below).constant
                tree = below
                tree.l.val = options.binops[op](left(tree).val, topconstant)
            elseif below.r.constant
                tree = below
                tree.r.val = options.binops[op](tree.r.val, topconstant)
            end
        end
    end

    if tree.degree == 2 && options.binops[tree.op] == (-) && top_level_constant
        # Currently just simplifies subtraction. (can't assume both plus and sub are operators)
        # Not commutative, so use different op.
        if left(tree).constant
            if tree.r.degree == 2 && options.binops[tree.r.op] == (-)
                if left(tree.r).constant
                    #(const - (const - var)) => (var - const)
                    l = left(tree)
                    r = tree.r
                    simplified_const = -(l.val - left(r).val) #neg(sub(l.val, left(r).val))
                    set_left!(tree, tree.r.r)
                    set_right!(tree, l)
                    tree.r.val = simplified_const
                elseif tree.r.r.constant
                    #(const - (var - const)) => (const - var)
                    l = left(tree)
                    r = tree.r
                    simplified_const = l.val + r.r.val #plus(l.val, r.r.val)
                    set_right!(tree, left(tree.r))
                    tree.l.val = simplified_const
                end
            end
        else #tree.r.constant is true
            if left(tree).degree == 2 && options.binops[left(tree).op] == (-)
                if left(left(tree)).constant
                    #((const - var) - const) => (const - var)
                    l = left(tree)
                    r = tree.r
                    simplified_const = left(l).val - r.val#sub(left(l).val, r.val)
                    set_right!(tree, left(tree).r)
                    set_left!(tree, r)
                    left(tree).val = simplified_const
                elseif left(tree).r.constant
                    #((var - const) - const) => (var - const)
                    l = left(tree)
                    r = tree.r
                    simplified_const = r.val + l.r.val #plus(r.val, l.r.val)
                    set_left!(tree, left(left(tree)))
                    tree.r.val = simplified_const
                end
            end
        end
    end
    return tree
end

# Simplify tree
function simplify_tree(tree::Node{T}, options::Options)::Node{T} where {T<:Real}
    if tree.degree == 1
        set_left!(tree, simplify_tree(left(tree), options))
        l = left(tree).val
        if left(tree).degree == 0 && left(tree).constant && isgood(l)
            out = options.unaops[tree.op](l)
            if isbad(out)
                return tree
            end
            return Node(; val=convert(T, out))
        end
    elseif tree.degree == 2
        set_left!(tree, simplify_tree(left(tree), options))
        set_right!(tree, simplify_tree(tree.r, options))
        constantsBelow = (
            tree.l.degree == 0 && left(tree).constant && tree.r.degree == 0 && tree.r.constant
        )
        if constantsBelow
            # NaN checks:
            l = left(tree).val
            r = tree.r.val
            if isbad(l) || isbad(r)
                return tree
            end

            # Actually compute:
            out = options.binops[tree.op](l, r)
            if isbad(out)
                return tree
            end
            return Node(; val=convert(T, out))
        end
    end
    return tree
end

end
