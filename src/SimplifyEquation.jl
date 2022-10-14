module SimplifyEquationModule

import ..CoreModule: Node, copy_node, Options
import ..CheckConstraintsModule: check_constraints
import ..UtilsModule: isbad, isgood

# Simplify tree
function combine_operators(
    tree::Node{T},
    options::Options,
    id_map::IdDict{Node{T},Node{T}}=IdDict{Node{T},Node{T}}(),
)::Node{T} where {T}
    # NOTE: (const (+*-) const) already accounted for. Call simplify_tree before.
    # ((const + var) + const) => (const + var)
    # ((const * var) * const) => (const * var)
    # ((const - var) - const) => (const - var)
    # (want to add anything commutative!)
    # TODO - need to combine plus/sub if they are both there.
    get!(id_map, tree) do
        if tree.degree == 0
            return tree
        elseif tree.degree == 1
            tree.l = combine_operators(tree.l, options, id_map)
        elseif tree.degree == 2
            tree.l = combine_operators(tree.l, options, id_map)
            tree.r = combine_operators(tree.r, options, id_map)
        end

        top_level_constant = tree.degree == 2 && (tree.l.constant || tree.r.constant)
        if tree.degree == 2 &&
            (options.binops[tree.op] == (*) || options.binops[tree.op] == (+)) &&
            top_level_constant
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
end

# Simplify tree
function simplify_tree(
    tree::Node{T},
    options::Options,
    id_map::IdDict{Node{T},Node{T}}=IdDict{Node{T},Node{T}}(),
)::Node{T} where {T<:Real}
    get!(id_map, tree) do
        if tree.degree == 1
            tree.l = simplify_tree(tree.l, options, id_map)
            l = tree.l.val
            if tree.l.degree == 0 && tree.l.constant && isgood(l)
                out = options.unaops[tree.op](l)
                if isbad(out)
                    return tree
                end
                return Node(; val=convert(T, out))
            end
        elseif tree.degree == 2
            tree.l = simplify_tree(tree.l, options, id_map)
            tree.r = simplify_tree(tree.r, options, id_map)
            constantsBelow = (
                tree.l.degree == 0 &&
                tree.l.constant &&
                tree.r.degree == 0 &&
                tree.r.constant
            )
            if constantsBelow
                # NaN checks:
                l = tree.l.val
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

end
