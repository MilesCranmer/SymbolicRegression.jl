import SpecialFunctions: gamma, lgamma, erf, erfc, beta

# Implicitly defined:
#binary: mod
#unary: exp, abs, log1p, sin, cos, tan, sinh, cosh, tanh, asin, acos, atan, asinh, acosh, atanh, erf, erfc, gamma, relu, round, floor, ceil, round, sign.

# Use some fast operators from https://github.com/JuliaLang/julia/blob/81597635c4ad1e8c2e1c5753fda4ec0e7397543f/base/fastmath.jl
# Define allowed operators. Any julia operator can also be used.
plus(x, y) = x + y #Do not change the name of this operator.
sub(x, y) = x - y #Do not change the name of this operator.
mult(x, y) = x * y #Do not change the name of this operator.
square(x) = x * x
cube(x) = x ^ 3
pow(x, y) = pow(abs(x), y)
div(x, y) = x / y
logm(x) = log(abs(x) + 1f-8)
logm2(x) = log2(abs(x) + 1f-8)
logm10(x) = log10(abs(x) + 1f-8)
sqrtm(x) = sqrt(abs(x))
neg(x) = - x

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
