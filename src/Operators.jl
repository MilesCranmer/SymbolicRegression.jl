module OperatorsModule

using SpecialFunctions: SpecialFunctions
import SpecialFunctions: erf, erfc
#TODO - actually add these operators to the module!

function gamma(x::T)::T where {T<:Real}
    if x <= T(0) && abs(x % 1) < T(1e-6)
        T(1//100000000)
    else
        SpecialFunctions.gamma(x)
    end
end
gamma(x) = SpecialFunctions.gamma(x)

atanh_clip(x) = atanh(mod(x + 1, 2) - 1)

# Implicitly defined:
#binary: mod
#unary: exp, abs, log1p, sin, cos, tan, sinh, cosh, tanh, asin, acos, atan, asinh, acosh, atanh, erf, erfc, gamma, relu, round, floor, ceil, round, sign.

# Use some fast operators from https://github.com/JuliaLang/julia/blob/81597635c4ad1e8c2e1c5753fda4ec0e7397543f/base/fastmath.jl
# Define allowed operators. Any julia operator can also be used.
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
function pow(x::T, y::T)::T where {T<:Real}
    return abs(x)^y
end
function div(x::T, y::T)::T where {T<:Real}
    return x / y
end
function log_abs(x::T)::T where {T<:Real}
    return log(abs(x) + convert(T, 1//100000000))
end
function log2_abs(x::T)::T where {T<:Real}
    return log2(abs(x) + convert(T, 1//100000000))
end
function log10_abs(x::T)::T where {T<:Real}
    return log10(abs(x) + convert(T, 1//100000000))
end
function log1p_abs(x::T)::T where {T<:Real}
    return log(abs(x) + convert(T, 1))
end
function acosh_abs(x::T)::T where {T<:Real}
    return acosh(abs(x) + convert(T, 1))
end
function sqrt_abs(x::T)::T where {T<:Real}
    return sqrt(abs(x))
end
function neg(x::T)::T where {T<:Real}
    return -x
end
function greater(x::T, y::T)::T where {T<:Real}
    return convert(T, (x > y))
end
function relu(x::T)::T where {T<:Real}
    return convert(T, (x > 0)) * x
end
function logical_or(x::T, y::T)::T where {T<:Real}
    return convert(T, (x > convert(T, 0) || y > convert(T, 0)))
end
# (Just use multiplication normally)
function logical_and(x::T, y::T)::T where {T<:Real}
    return convert(T, (x > convert(T, 0) && y > convert(T, 0)))
end

end
