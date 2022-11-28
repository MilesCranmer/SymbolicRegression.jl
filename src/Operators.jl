module OperatorsModule

using SpecialFunctions: SpecialFunctions
import SpecialFunctions: erf, erfc
import Base: @deprecate
#TODO - actually add these operators to the module!

function gamma(x::T)::T where {T<:Real}
    out = SpecialFunctions.gamma(x)
    return isinf(out) ? T(NaN) : out
end
gamma(x) = SpecialFunctions.gamma(x)

atanh_clip(x) = atanh(mod(x + 1, 2) - 1)

# Implicitly defined:
#binary: mod
#unary: exp, abs, log1p, sin, cos, tan, sinh, cosh, tanh, asin, acos, atan, asinh, acosh, atanh, erf, erfc, gamma, relu, round, floor, ceil, round, sign.

# Use some fast operators from https://github.com/JuliaLang/julia/blob/81597635c4ad1e8c2e1c5753fda4ec0e7397543f/base/fastmath.jl
# Define allowed operators. Any julia operator can also be used.
# TODO: Add all of these operators to the precompilation.
function plus(x::T, y::T)::T where {T<:Real}
    return x + y #Do not change the name of this operator.
end
function sub(x::T, y::T)::T where {T<:Real}
    return x - y #Do not change the name of this operator.
end
function mult(x::T, y::T)::T where {T<:Real}
    return x * y #Do not change the name of this operator.
end
function square(x::T)::T where {T<:Real}
    return x * x
end
function cube(x::T)::T where {T<:Real}
    return x^3
end
function safe_pow(x::T, y::T)::T where {T<:AbstractFloat}
    if isinteger(y)
        y < T(0) && x == T(0) && return T(NaN)
    else
        y > T(0) && x < T(0) && return T(NaN)
        y < T(0) && x <= T(0) && return T(NaN)
    end
    return x^y
end
function div(x::T, y::T)::T where {T<:AbstractFloat}
    return x / y
end
function safe_log(x::T)::T where {T<:AbstractFloat}
    x <= T(0) && return T(NaN)
    return log(x)
end
function safe_log2(x::T)::T where {T<:AbstractFloat}
    x <= T(0) && return T(NaN)
    return log2(x)
end
function safe_log10(x::T)::T where {T<:AbstractFloat}
    x <= T(0) && return T(NaN)
    return log10(x)
end
function safe_log1p(x::T)::T where {T<:AbstractFloat}
    x <= T(-1) && return T(NaN)
    return log1p(x)
end
function safe_acosh(x::T)::T where {T<:AbstractFloat}
    x < T(1) && return T(NaN)
    return acosh(x)
end
function safe_sqrt(x::T)::T where {T<:AbstractFloat}
    x < T(0) && return T(NaN)
    return sqrt(x)
end

# Generics (and SIMD)
square(x) = x * x
cube(x) = x * x * x
plus(x, y) = x + y
sub(x, y) = x - y
mult(x, y) = x * y
safe_pow(x, y) = x^y
div(x, y) = x / y
safe_log(x) = log(x)
safe_log2(x) = log2(x)
safe_log10(x) = log10(x)
safe_log1p(x) = log1p(x)
safe_acosh(x) = acosh(x)
safe_sqrt(x) = sqrt(x)

function neg(x::T)::T where {T}
    return -x
end

function greater(x::T, y::T)::T where {T}
    return convert(T, (x > y))
end
function greater(x, y)
    return (x > y)
end
function relu(x::T)::T where {T}
    return (x + abs(x)) / T(2)
end

function logical_or(x::T, y::T)::T where {T}
    return convert(T, (x > convert(T, 0) || y > convert(T, 0)))
end

# (Just use multiplication normally)
function logical_and(x::T, y::T)::T where {T}
    return convert(T, (x > convert(T, 0) && y > convert(T, 0)))
end

# Deprecated operations:
@deprecate pow safe_pow
@deprecate pow_abs safe_pow

end
