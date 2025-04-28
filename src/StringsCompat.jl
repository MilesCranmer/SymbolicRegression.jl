"""
    StringsCompatModule

Module for compatibility with strings. This doubles as an
example of how to implement custom types as features.
"""
module StringsCompatModule

using Random: AbstractRNG
using ..UtilsModule: poisson_sample
using ..CoreModule: AbstractOptions

import DynamicExpressions: count_scalar_constants
import ..CoreModule: init_value, sample_value, mutate_value

function init_value(::Type{String})
    return ""
end

function sample_value(rng::AbstractRNG, ::Type{String}, options)
    len = rand(rng, 0:5)
    # Sample all ASCII characters:
    return join(sample_alphabet(rng, options) for _ in 1:len)
end

lambda_max(options::AbstractOptions) = 5.0
sample_alphabet(rng::AbstractRNG, options::AbstractOptions) = Char(rand(rng, 32:126))

"""
    mutate_value(rng, val::String, temperature, opt)

Multi-edit string mutation.
"""
function mutate_value(rng::AbstractRNG, val::String, T, options)
    λ = max(nextfloat(0.0), lambda_max(options) * clamp(float(T), 0, 1))
    n_edits = poisson_sample(rng, λ)
    chars = collect(val)
    ops = rand(rng, (:insert, :delete, :replace, :swap), n_edits)
    for op in ops
        if op == :insert
            insert!(chars, rand(rng, 0:length(chars)) + 1, sample_alphabet(rng, options))
        elseif op == :delete && !isempty(chars)
            deleteat!(chars, rand(rng, eachindex(chars)))
        elseif op == :replace
            if isempty(chars)
                push!(chars, sample_alphabet(rng, options))
            else
                chars[rand(rng, eachindex(chars))] = sample_alphabet(rng, options)
            end
        elseif op == :swap && length(chars) >= 2
            i = rand(rng, 1:(length(chars) - 1))
            chars[i], chars[i + 1] = chars[i + 1], chars[i]
        end
    end
    return String(chars)
end

end
