import SpecialFunctions: gamma, lgamma, erf, erfc, beta

# Implicitly defined:
#binary: mod
#unary: exp, abs, log1p, sin, cos, tan, sinh, cosh, tanh, asin, acos, atan, asinh, acosh, atanh, erf, erfc, gamma, relu, round, floor, ceil, round, sign.

# Use some fast operators from https://github.com/JuliaLang/julia/blob/81597635c4ad1e8c2e1c5753fda4ec0e7397543f/base/fastmath.jl
# Define allowed operators. Any julia operator can also be used.
function plus(x::T, y::T)::T where {T<:AbstractFloat}
	x + y #Do not change the name of this operator.
end
function sub(x::T, y::T)::T where {T<:AbstractFloat}
	x - y #Do not change the name of this operator.
end
function mult(x::T, y::T)::T where {T<:AbstractFloat}
	x * y #Do not change the name of this operator.
end
function square(x::T)::T where {T<:AbstractFloat}
	x * x
end
function cube(x::T)::T where {T<:AbstractFloat}
	x ^ 3
end
function pow(x::T, y::T)::T where {T<:AbstractFloat}
	pow(abs(x), y)
end
function div(x::T, y::T)::T where {T<:AbstractFloat}
	x / y
end
function logm(x::T)::T where {T<:AbstractFloat}
	log(abs(x) + 1f-8)
end
function logm2(x::T)::T where {T<:AbstractFloat}
	log2(abs(x) + 1f-8)
end
function logm10(x::T)::T where {T<:AbstractFloat}
	log10(abs(x) + 1f-8)
end
function sqrtm(x::T)::T where {T<:AbstractFloat}
	sqrt(abs(x))
end
function neg(x::T)::T where {T<:AbstractFloat}
	- x
end

function greater(x::T, y::T)::T where {T<:AbstractFloat}
    if x > y
        return 1f0
    end
    return 0f0
end

function relu(x::T, y::T)::T where {T<:AbstractFloat}
    if x > 0f0
        return x
    end
    return 0f0
end

function logical_or(x::T, y::T)::T where {T<:AbstractFloat}
    if x > 0f0 || y > 0f0
        return 1f0
    end
    return 0f0
end

# (Just use multiplication normally)
function logical_and(x::T, y::T)::T where {T<:AbstractFloat}
    if x > 0f0 && y > 0f0
        return 1f0
    end
    return 0f0
end
