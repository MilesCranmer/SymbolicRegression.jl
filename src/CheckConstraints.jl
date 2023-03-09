module CheckConstraintsModule

using Unitful: Unitful
import DynamicExpressions: Node, count_depth
import ..UtilsModule: vals
import ..CoreModule: Options, Dataset
import ..ComplexityModule: compute_complexity

# Check if any binary operator are overly complex
function flag_bin_operator_complexity(
    tree::Node, ::Val{op}, options::Options
)::Bool where {op}
    if tree.degree == 0
        return false
    elseif tree.degree == 1
        return flag_bin_operator_complexity(tree.l, vals[op], options)
    else
        if tree.op == op
            overly_complex::Bool = (
                (
                    (options.bin_constraints[op][1]::Int > -1) && (
                        compute_complexity(tree.l, options) >
                        options.bin_constraints[op][1]::Int
                    )
                ) || (
                    (options.bin_constraints[op][2]::Int > -1) && (
                        compute_complexity(tree.r, options) >
                        options.bin_constraints[op][2]::Int
                    )
                )
            )
            if overly_complex
                return true
            end
        end
        return (
            flag_bin_operator_complexity(tree.l, vals[op], options) ||
            flag_bin_operator_complexity(tree.r, vals[op], options)
        )
    end
end

# Check if any unary operators are overly complex
function flag_una_operator_complexity(
    tree::Node, ::Val{op}, options::Options
)::Bool where {op}
    if tree.degree == 0
        return false
    elseif tree.degree == 1
        if tree.op == op
            overly_complex::Bool = (
                (options.una_constraints[op]::Int > -1) &&
                (compute_complexity(tree.l, options) > options.una_constraints[op]::Int)
            )
            if overly_complex
                return true
            end
        end
        return flag_una_operator_complexity(tree.l, vals[op], options)
    else
        return (
            flag_una_operator_complexity(tree.l, vals[op], options) ||
            flag_una_operator_complexity(tree.r, vals[op], options)
        )
    end
end

"""Count the max number of times an operator of a given degree is nested"""
function count_max_nestedness(tree::Node, degree::Int, op::Int, options::Options)::Int
    if tree.degree == 0
        return 0
    elseif tree.degree == 1
        count = (degree == 1 && tree.op == op) ? 1 : 0
        return count + count_max_nestedness(tree.l, degree, op, options)
    else  # tree.degree == 2
        count = (degree == 2 && tree.op == op) ? 1 : 0
        return count + max(
            count_max_nestedness(tree.l, degree, op, options),
            count_max_nestedness(tree.r, degree, op, options),
        )
    end
end

# function fast_max_nestedness(tree::Node, degree::Int, op_idx::Int, nested_degree::Int, nested_op_idx::Int, options::Options)::Int
function fast_max_nestedness(
    tree::Node,
    degree::Int,
    op_idx::Int,
    nested_degree::Int,
    nested_op_idx::Int,
    options::Options,
)::Int
    # Don't need to branch - once you find operator, run
    # count_max once, then return. Don't need to go deeper!
    if tree.degree == 0
        return 0
    elseif tree.degree == 1
        if degree != tree.degree || tree.op != op_idx
            return fast_max_nestedness(
                tree.l, degree, op_idx, nested_degree, nested_op_idx, options
            )
        end
        return count_max_nestedness(tree.l, nested_degree, nested_op_idx, options)
    else
        if degree != tree.degree || tree.op != op_idx
            return max(
                fast_max_nestedness(
                    tree.l, degree, op_idx, nested_degree, nested_op_idx, options
                ),
                fast_max_nestedness(
                    tree.r, degree, op_idx, nested_degree, nested_op_idx, options
                ),
            )
        end
        return max(
            count_max_nestedness(tree.l, nested_degree, nested_op_idx, options),
            count_max_nestedness(tree.r, nested_degree, nested_op_idx, options),
        )
    end
end

"""Check if there are any illegal combinations of operators"""
function flag_illegal_nests(tree::Node, options::Options)::Bool
    # We search from the top first, then from child nodes at end.
    nested_constraints = options.nested_constraints
    if nested_constraints === nothing
        return false
    end
    for (degree, op_idx, op_constraint) in nested_constraints
        for (nested_degree, nested_op_idx, max_nestedness) in op_constraint
            nestedness = fast_max_nestedness(
                tree, degree, op_idx, nested_degree, nested_op_idx, options
            )
            if nestedness > max_nestedness
                return true
            end
        end
    end
    return false
end

extract_units(::Unitful.Quantity{T,D,F}) where {T,D,F} = F()

# TODO: dimensionless also true if the units contain a wildcard!
is_dimensionless(::Unitful.FreeUnits{A,B,C}) where {A,B,C} = B == Unitful.NoDims

function _get_units_deg1(
    l::Unitful.FreeUnits, op::F, ::Type{T}
)::Tuple{Unitful.FreeUnits,Bool} where {F,T}
    try
        out = op(one(T) * l)
        return extract_units(out), true
    catch e
        # Check if methoderror:
        if isa(e, MethodError) || isa(e, Unitful.DimensionError)
            return l, false
        else
            throw(e)
        end
    end
end

# TODO: This could potentially blow up multiple dispatch,
# if there is a new type for every power....
function _get_units_deg2(
    l::Unitful.FreeUnits, r::Unitful.FreeUnits, op::F, ::Type{T}
)::Tuple{Unitful.FreeUnits,Bool} where {F,T}
    try
        out = op(one(T) * l, one(T) * r)
        return extract_units(out), true
    catch e
        # Check if methoderror:
        if isa(e, MethodError) || isa(e, Unitful.DimensionError)
            return l, false
        else
            throw(e)
        end
    end
end

function get_units(
    tree::Node, dataset::Dataset{T}, options::Options
)::Tuple{Unitful.FreeUnits,Bool} where {T}
    if tree.degree == 0
        if tree.constant
            x = Unitful.@u_str "kg"
            # TODO: Here is where we give the wildcard unit.
            return (x / x), true
        else
            return dataset.units[tree.feature], true
        end
    elseif tree.degree == 1
        left, completion = get_units(tree.l, dataset, options)
        !completion && return (left, false)
        op = options.operators.unaops[tree.op]
        return _get_units_deg1(left, op, T)  # TODO: This is a hack.
    else
        left, completion = get_units(tree.l, dataset, options)
        !completion && return (left, false)
        right, completion = get_units(tree.r, dataset, options)
        !completion && return (right, false)
        op = options.operators.binops[tree.op]
        if op == (^) && !(is_dimensionless(left) && is_dimensionless(right))
            # Otherwise, will blow up multiple dispatch!
            return (left, false)
        end
        return _get_units_deg2(left, right, op, T)
    end
end

"""Check if user-passed units are violated or not"""
function check_units(tree::Node, dataset::Dataset, options::Options)
    output_unit, completion = get_units(tree, dataset, options)
    !completion && return false
    return is_dimensionless(output_unit)
end

"""Check if user-passed constraints are violated or not"""
function check_constraints(
    tree::Node, options::Options, maxsize::Int; dataset::D=nothing
)::Bool where {D<:Union{Dataset,Nothing}}
    compute_complexity(tree, options) > maxsize && return false
    count_depth(tree) > options.maxdepth && return false
    for i in 1:(options.nbin)
        if options.bin_constraints[i] == (-1, -1)
            continue
        elseif flag_bin_operator_complexity(tree, Val(i), options)
            return false
        end
    end
    for i in 1:(options.nuna)
        if options.una_constraints[i] == -1
            continue
        elseif flag_una_operator_complexity(tree, Val(i), options)
            return false
        end
    end
    if flag_illegal_nests(tree, options)
        return false
    end
    # if D !== Nothing && dataset.has_units && !check_units(tree, dataset, options)
    #     return false
    # end

    return true
end

function check_constraints(tree::Node, options::Options)::Bool
    return check_constraints(tree, options, options.maxsize)
end

end
