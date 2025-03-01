module OperatorsModule

using DynamicExpressions: DynamicExpressions as DE
using SpecialFunctions: SpecialFunctions
using DynamicQuantities: UnionAbstractQuantity
using SpecialFunctions: erf, erfc
using Base: @deprecate
using DynamicDiff: ForwardDiff
using ..ProgramConstantsModule: DATA_TYPE
using ...UtilsModule: @ignore
#TODO - actually add these operators to the module!

# TODO: Should this be limited to AbstractFloat instead?
function gamma(x::T)::T where {T<:DATA_TYPE}
    out = SpecialFunctions.gamma(x)
    return isinf(out) ? T(NaN) : out
end
gamma(x) = SpecialFunctions.gamma(x)

atanh_clip(x) = atanh(mod(x + oneunit(x), oneunit(x) + oneunit(x)) - oneunit(x)) * one(x)
# == atanh((x + 1) % 2 - 1)

const Dual = ForwardDiff.Dual

# Implicitly defined:
#binary: mod
#unary: exp, abs, log1p, sin, cos, tan, sinh, cosh, tanh, asin, acos, atan, asinh, acosh, atanh, erf, erfc, gamma, relu, round, floor, ceil, round, sign.

const FloatOrDual = Union{AbstractFloat,Dual}
# Note that a complex dual is Complex{<:Dual}, so we are safe to use this signature.

# Use some fast operators from https://github.com/JuliaLang/julia/blob/81597635c4ad1e8c2e1c5753fda4ec0e7397543f/base/fastmath.jl
# Define allowed operators. Any julia operator can also be used.
# TODO: Add all of these operators to the precompilation.
# TODO: Since simplification is done in DynamicExpressions.jl, are these names correct anymore?
function safe_pow(
    x::T1, y::T2
) where {
    T1<:Union{FloatOrDual,UnionAbstractQuantity},
    T2<:Union{FloatOrDual,UnionAbstractQuantity},
}
    T = promote_type(T1, T2)
    if isinteger(y)
        y < zero(y) && iszero(x) && return T(NaN)
    else
        y > zero(y) && x < zero(x) && return T(NaN)
        y < zero(y) && x <= zero(x) && return T(NaN)
    end
    return x^y
end
function safe_log(x::T)::T where {T<:FloatOrDual}
    return x > zero(x) ? log(x) : T(NaN)
end
function safe_log2(x::T)::T where {T<:FloatOrDual}
    return x > zero(x) ? log2(x) : T(NaN)
end
function safe_log10(x::T)::T where {T<:FloatOrDual}
    return x > zero(x) ? log10(x) : T(NaN)
end
function safe_log1p(x::T)::T where {T<:FloatOrDual}
    return x > -oneunit(x) ? log1p(x) : T(NaN)
end
function safe_asin(x::T)::T where {T<:FloatOrDual}
    return -oneunit(x) <= x <= oneunit(x) ? asin(x) : T(NaN)
end
function safe_acos(x::T)::T where {T<:FloatOrDual}
    return -oneunit(x) <= x <= oneunit(x) ? acos(x) : T(NaN)
end
function safe_acosh(x::T)::T where {T<:FloatOrDual}
    return x >= oneunit(x) ? acosh(x) : T(NaN)
end
function safe_atanh(x::T)::T where {T<:FloatOrDual}
    return -oneunit(x) <= x <= oneunit(x) ? atanh(x) : T(NaN)
end
function safe_sqrt(x::T)::T where {T<:FloatOrDual}
    return x >= zero(x) ? sqrt(x) : T(NaN)
end
# TODO: Should the above be made more generic, for, e.g., compatibility with units?

# Do not change the names of these operators, as
# they have special use in simplifications and printing.
square(x) = x * x
cube(x) = x * x * x
plus(x, y) = x + y
sub(x, y) = x - y
mult(x, y) = x * y
# Generics (for SIMD)
safe_pow(x, y) = x^y
safe_log(x) = log(x)
safe_log2(x) = log2(x)
safe_log10(x) = log10(x)
safe_log1p(x) = log1p(x)
safe_asin(x) = asin(x)
safe_acos(x) = acos(x)
safe_atanh(x) = atanh(x)
safe_acosh(x) = acosh(x)
safe_sqrt(x) = sqrt(x)

function neg(x)
    return -x
end
function greater(x, y)
    return (x > y) * one(x)
end
function less(x, y)
    return (x < y) * one(x)
end
function greater_equal(x, y)
    return (x >= y) * one(x)
end
function less_equal(x, y)
    return (x <= y) * one(x)
end
function cond(x, y)
    return (x > zero(x)) * y
end
function relu(x)
    return (x > zero(x)) * x
end
function logical_or(x, y)
    return ((x > zero(x)) | (y > zero(y))) * one(x)
end
function logical_and(x, y)
    return ((x > zero(x)) & (y > zero(y))) * one(x)
end

# COV_EXCL_START
# Strings
DE.get_op_name(::typeof(safe_pow)) = "^"
DE.get_op_name(::typeof(safe_log)) = "log"
DE.get_op_name(::typeof(safe_log2)) = "log2"
DE.get_op_name(::typeof(safe_log10)) = "log10"
DE.get_op_name(::typeof(safe_log1p)) = "log1p"
DE.get_op_name(::typeof(safe_asin)) = "asin"
DE.get_op_name(::typeof(safe_acos)) = "acos"
DE.get_op_name(::typeof(safe_acosh)) = "acosh"
DE.get_op_name(::typeof(safe_atanh)) = "atanh"
DE.get_op_name(::typeof(safe_sqrt)) = "sqrt"

# Strings that only get printed for pretty printing,
# but not when saving to the file
DE.get_pretty_op_name(::typeof(greater)) = ">"
DE.get_pretty_op_name(::typeof(less)) = "<"
DE.get_pretty_op_name(::typeof(greater_equal)) = ">="
DE.get_pretty_op_name(::typeof(less_equal)) = "<="

# Expression algebra
DE.declare_operator_alias(::typeof(safe_pow), ::Val{2}) = ^
DE.declare_operator_alias(::typeof(greater), ::Val{2}) = >
DE.declare_operator_alias(::typeof(less), ::Val{2}) = <
DE.declare_operator_alias(::typeof(greater_equal), ::Val{2}) = >=
DE.declare_operator_alias(::typeof(less_equal), ::Val{2}) = <=
DE.declare_operator_alias(::typeof(safe_log), ::Val{1}) = log
DE.declare_operator_alias(::typeof(safe_log2), ::Val{1}) = log2
DE.declare_operator_alias(::typeof(safe_log10), ::Val{1}) = log10
DE.declare_operator_alias(::typeof(safe_log1p), ::Val{1}) = log1p
DE.declare_operator_alias(::typeof(safe_asin), ::Val{1}) = asin
DE.declare_operator_alias(::typeof(safe_acos), ::Val{1}) = acos
DE.declare_operator_alias(::typeof(safe_acosh), ::Val{1}) = acosh
DE.declare_operator_alias(::typeof(safe_atanh), ::Val{1}) = atanh
DE.declare_operator_alias(::typeof(safe_sqrt), ::Val{1}) = sqrt

# Deprecated operations:
@deprecate pow(x, y) safe_pow(x, y)
@deprecate pow_abs(x, y) safe_pow(x, y)

# For static analysis tools:
@ignore pow(x, y) = safe_pow(x, y)
@ignore pow_abs(x, y) = safe_pow(x, y)

# Actual mappings used for evaluation
get_safe_op(op::F) where {F<:Function} = op
get_safe_op(::typeof(^)) = safe_pow
get_safe_op(::typeof(log)) = safe_log
get_safe_op(::typeof(log2)) = safe_log2
get_safe_op(::typeof(log10)) = safe_log10
get_safe_op(::typeof(log1p)) = safe_log1p
get_safe_op(::typeof(asin)) = safe_asin
get_safe_op(::typeof(acos)) = safe_acos
get_safe_op(::typeof(sqrt)) = safe_sqrt
get_safe_op(::typeof(acosh)) = safe_acosh
get_safe_op(::typeof(atanh)) = safe_atanh
get_safe_op(::typeof(>)) = greater
get_safe_op(::typeof(<)) = less
get_safe_op(::typeof(>=)) = greater_equal
get_safe_op(::typeof(<=)) = less_equal
# COV_EXCL_STOP

end
