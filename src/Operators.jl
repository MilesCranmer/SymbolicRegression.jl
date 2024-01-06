module OperatorsModule

using SpecialFunctions: SpecialFunctions
using DynamicQuantities: UnionAbstractQuantity
using SpecialFunctions: erf, erfc
using Base: @deprecate
using ..ProgramConstantsModule: DATA_TYPE
#TODO - actually add these operators to the module!

# TODO: Should this be limited to AbstractFloat instead?
function gamma(x::T)::T where {T<:DATA_TYPE}
    out = SpecialFunctions.gamma(x)
    return isinf(out) ? T(NaN) : out
end
gamma(x) = SpecialFunctions.gamma(x)

atanh_clip(x) = atanh(mod(x + oneunit(x), oneunit(x) + oneunit(x)) - oneunit(x)) * one(x)
# == atanh((x + 1) % 2 - 1)

# Implicitly defined:
#binary: mod
#unary: exp, abs, log1p, sin, cos, tan, sinh, cosh, tanh, asin, acos, atan, asinh, acosh, atanh, erf, erfc, gamma, relu, round, floor, ceil, round, sign.

# Use some fast operators from https://github.com/JuliaLang/julia/blob/81597635c4ad1e8c2e1c5753fda4ec0e7397543f/base/fastmath.jl
# Define allowed operators. Any julia operator can also be used.
# TODO: Add all of these operators to the precompilation.
# TODO: Since simplification is done in DynamicExpressions.jl, are these names correct anymore?
function safe_pow(x::T, y::T)::T where {T<:Union{AbstractFloat,UnionAbstractQuantity}}
    if isinteger(y)
        y < zero(y) && iszero(x) && return T(NaN)
    else
        y > zero(y) && x < zero(x) && return T(NaN)
        y < zero(y) && x <= zero(x) && return T(NaN)
    end
    return x^y
end
function safe_log(x::T)::T where {T<:AbstractFloat}
    x <= zero(x) && return T(NaN)
    return log(x)
end
function safe_log2(x::T)::T where {T<:AbstractFloat}
    x <= zero(x) && return T(NaN)
    return log2(x)
end
function safe_log10(x::T)::T where {T<:AbstractFloat}
    x <= zero(x) && return T(NaN)
    return log10(x)
end
function safe_log1p(x::T)::T where {T<:AbstractFloat}
    x <= -oneunit(x) && return T(NaN)
    return log1p(x)
end
function safe_acosh(x::T)::T where {T<:AbstractFloat}
    x < oneunit(x) && return T(NaN)
    return acosh(x)
end
function safe_sqrt(x::T)::T where {T<:AbstractFloat}
    x < zero(x) && return T(NaN)
    return sqrt(x)
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
safe_acosh(x) = acosh(x)
safe_sqrt(x) = sqrt(x)

function neg(x)
    return -x
end
function greater(x, y)
    return (x > y) * one(x)
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

# Deprecated operations:
@deprecate pow safe_pow
@deprecate pow_abs safe_pow

end
