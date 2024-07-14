module InverseFunctionsModule

using InverseFunctions: inverse as _inverse, NoInverse

#! format: off
using ..CoreModule:
    square, cube, safe_pow, safe_log, safe_log2,
    safe_log10, safe_log1p, safe_sqrt, safe_acosh, safe_acos,
    safe_asin, neg, greater, cond, relu, logical_or,
    logical_and, gamma, erf, erfc, atanh_clip
#! format: on

"""
    approx_inverse(f::Function)

Create a function that, for x ∈ [0, ϵ], for some ϵ > 0,
is the inverse of `f`. This means that, e.g., `abs` has
an `approx_inverse` of `abs`, since, for any `x>0`, `abs(abs(x)) = x`.

This is not to be treated as an exact mathematical inverse. It's purely
for utility in mutation operators that can use information about inverse
functions to improve the search space.

The default behavior for operators is to use InverseFunctions.jl.
"""
function approx_inverse(f::F) where {F<:Function}
    i_f = _inverse(f)
    if i_f isa NoInverse
        _no_inverse(f)
    end
    return i_f
end
function _no_inverse(f)
    return error("Inverse of $(f) not yet implemented. Please extend `$(approx_inverse)`.")
end

###########################################################################
## Unary operators ########################################################
###########################################################################
approx_inverse(::typeof(sin)) = safe_asin
approx_inverse(::typeof(safe_asin)) = sin

approx_inverse(::typeof(cos)) = safe_acos
approx_inverse(::typeof(safe_acos)) = cos

approx_inverse(::typeof(tan)) = atan
approx_inverse(::typeof(atan)) = tan

# sinh already implemented

approx_inverse(::typeof(cosh)) = safe_acosh
approx_inverse(::typeof(safe_acosh)) = cosh

approx_inverse(::typeof(tanh)) = atanh_clip
approx_inverse(::typeof(atanh_clip)) = tanh

approx_inverse(::typeof(square)) = safe_sqrt
approx_inverse(::typeof(safe_sqrt)) = square

approx_inverse(::typeof(cube)) = cbrt
approx_inverse(::typeof(cbrt)) = cube

approx_inverse(::typeof(exp)) = safe_log
approx_inverse(::typeof(safe_log)) = exp

approx_inverse(::typeof(safe_log2)) = exp2
approx_inverse(::typeof(exp2)) = safe_log2

approx_inverse(::typeof(safe_log10)) = exp10
approx_inverse(::typeof(exp10)) = safe_log10

exp1m(x) = exp(x) - one(x)
approx_inverse(::typeof(safe_log1p)) = exp1m
approx_inverse(::typeof(exp1m)) = safe_log1p

# `inv` already implemented
approx_inverse(::typeof(neg)) = neg
approx_inverse(::typeof(relu)) = relu
approx_inverse(::typeof(abs)) = abs
###########################################################################

###########################################################################
## Binary operators #######################################################
###########################################################################

# Note that Fix{N,<:Union{typeof(+),typeof(*),typeof(-),typeof(/)}}
# is already implemented.

# (f.x ^ _) => log(f.x, _)
approx_inverse(f::Base.Fix1{typeof(safe_pow)}) = Base.Fix1(safe_log, f.x)
# (_ ^ f.x) => _ ^ (1/f.x)
approx_inverse(f::Base.Fix2{typeof(safe_pow)}) = Base.Fix2(safe_pow, inv(f.x))

# log(f.x, _) => f.x ^ _
approx_inverse(f::Base.Fix1{typeof(safe_log)}) = Base.Fix1(safe_pow, f.x)
# log(_, f.x) => f.x ^ (1/_)
approx_inverse(f::Base.Fix2{typeof(safe_log)}) = Base.Fix1(safe_pow, f.x) ∘ inv
###########################################################################

end
