import SpecialFunctions: gamma, lgamma, erf, erfc, beta

# Implicitly defined:
#binary: mod
#unary: exp, abs, log1p, sin, cos, tan, sinh, cosh, tanh, asin, acos, atan, asinh, acosh, atanh, erf, erfc, gamma, relu, round, floor, ceil, round, sign.

# Use some fast operators from https://github.com/JuliaLang/julia/blob/81597635c4ad1e8c2e1c5753fda4ec0e7397543f/base/fastmath.jl
# Define allowed operators. Any julia operator can also be used.
function plus(x::T, y::T)::T where {T<:Real}
	x + y #Do not change the name of this operator.
end
plus(x, y) = x + y

function sub(x::T, y::T)::T where {T<:Real}
	x - y #Do not change the name of this operator.
end
sub(x, y) = x - y

function mult(x::T, y::T)::T where {T<:Real}
	x * y #Do not change the name of this operator.
end
mult(x, y) = x * y

function square(x::T)::T where {T}
	x * x
end

function cube(x::T)::T where {T}
	x ^ 3
end

function powm(x::T, y::T)::T where {T<:Real}
	pow(abs(x), y)
end
powm(x, y) = pow(abs(x), y)

function div(x::T, y::T)::T where {T<:Real}
	x / y
end
div(x, y) = x / y

function logm(x::T)::T where {T}
    log(abs(x) + convert(T, 1f-8))
end
function logm2(x::T)::T where {T}
    log2(abs(x) + convert(T, 1f-8))
end
function logm10(x::T)::T where {T}
    log10(abs(x) + convert(T, 1f-8))
end
function sqrtm(x::T)::T where {T}
	sqrt(abs(x))
end
function neg(x::T)::T where {T}
	- x
end

function greater(x::T, y::T)::T where {T}
    if x > y
        return convert(T, 1)
    end
    return convert(T, 0)
end

function relu(x::T)::T where {T}
    if x > convert(T, 0)
        return x
    end
    return convert(T, 0)
end

function logical_or(x::T, y::T)::T where {T}
    if x > convert(T, 0) || y > convert(T, 0)
        return convert(T, 1)
    end
    return convert(T, 0)
end

# (Just use multiplication normally)
function logical_and(x::T, y::T)::T where {T}
    if x > convert(T, 0) && y > convert(T, 0)
        return convert(T, 1)
    end
    return convert(T, 0)
end
