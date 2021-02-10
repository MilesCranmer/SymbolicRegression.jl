import SpecialFunctions: gamma, lgamma, erf, erfc, beta
#TODO - actually add these operators to the module!

# Implicitly defined:
#binary: mod
#unary: exp, abs, log1p, sin, cos, tan, sinh, cosh, tanh, asin, acos, atan, asinh, acosh, atanh, erf, erfc, gamma, relu, round, floor, ceil, round, sign.

# Use some fast operators from https://github.com/JuliaLang/julia/blob/81597635c4ad1e8c2e1c5753fda4ec0e7397543f/base/fastmath.jl
# Define allowed operators. Any julia operator can also be used.
function plus(x::T, y::T)::T where {T<:Real}
	x + y #Do not change the name of this operator.
end
function sub(x::T, y::T)::T where {T<:Real}
	x - y #Do not change the name of this operator.
end
function mult(x::T, y::T)::T where {T<:Real}
	x * y #Do not change the name of this operator.
end
function square(x::T)::T where {T<:Real}
	x * x
end
function cube(x::T)::T where {T<:Real}
	x ^ 3
end
function pow(x::T, y::T)::T where {T<:Real}
	abs(x)^y
end
function div(x::T, y::T)::T where {T<:Real}
	x / y
end
function log_abs(x::T)::T where {T<:Real}
    log(abs(x) + convert(T, 1//100000000))
end
function log2_abs(x::T)::T where {T<:Real}
    log2(abs(x) + convert(T, 1//100000000))
end
function log10_abs(x::T)::T where {T<:Real}
    log10(abs(x) + convert(T, 1//100000000))
end

# Generics:
square(x) = x * x
cube(x) = x * x * x
plus(x, y) = x + y
sub(x, y) = x - y
mult(x, y) = x * y
pow(x, y) = abs(x)^y
div(x, y) = x / y
log_abs(x) = log(abs(x) + 1//100000000)
log2_abs(x) = log2(abs(x) + 1//100000000)
log10_abs(x) = log10(abs(x) + 1//100000000)

function sqrt_abs(x::T)::T where {T}
	sqrt(abs(x))
end
function neg(x::T)::T where {T}
	- x
end

function greater(x::T, y::T)::T where {T}
    return convert(T, (x > y))
end
function greater(x, y)
    return (x > y)
end
function relu(x::T)::T where {T}
    return convert(T, (x > 0)) * x
end

function logical_or(x::T, y::T)::T where {T}
    return convert(T, (x > convert(T, 0) || y > convert(T, 0)))
end

# (Just use multiplication normally)
function logical_and(x::T, y::T)::T where {T}
    return convert(T, (x > convert(T, 0) && y > convert(T, 0)))
end
