#literate_begin file="src/examples/custom_types.md"
#=
# Working with Custom Input Types

Say that you have some custom input type you want to evolve an expression for.
It doesn't even need to be a numerical type. It could be anything --- even a string!

Let's actually try this. Let's evolve an _expression over strings_.

Let's first mock up a dataset. Say that we wish to find the expression
$$ y = interleave(concat(x_1, concat("def", x_2)), concat(concat(last_half(x_3), reverse(d)), "abc")) $$
=#

using SymbolicRegression
using DynamicExpressions: GenericOperatorEnum
using MLJBase: machine, fit!
using Random

function edit_distance(a::String, b::String)
    a, b = length(a) >= length(b) ? (a, b) : (b, a)  ## Want shorter string to be b
    a, b = collect(a), collect(b)  ## Convert to vectors for uniform indexing
    m, n = length(a), length(b)

    m == 0 && return n
    n == 0 && return m
    a == b && return 0

    ## Initialize the previous row (distances from empty string to b[1:j])
    prev = collect(0:n)
    curr = similar(prev)

    for i_a in 1:m
        curr[1] = i_a
        ai = a[i_a]
        for i_b in 1:n
            cost = ai == b[i_b] ? 0 : 1
            curr[i_b + 1] = min(prev[i_b + 1] + 1, curr[i_b] + 1, prev[i_b] + cost)
        end
        prev, curr = curr, prev
    end

    return prev[n + 1]
end

# Generate random string of given length
function random_string(rng, length::Int)
    return join(rand(rng, 'a':'z', length))
end

# String operations - unary operators
function first_half(s::String)
    if length(s) > 0
        return join(collect(s)[1:max(1, div(length(s), 2))])
    else
        return join(collect(s))
    end
end
function last_half(s::String)
    if length(s) > 0
        return join(collect(s)[max(1, div(length(s), 2) + 1):end])
    else
        return join(collect(s))
    end
end
function concat(a::String, b::String)
    return a * b
end

# Binary operators
function interleave(a::String, b::String)
    # Interleave characters from two strings
    total_length = length(a) + length(b)
    result = Vector{Char}(undef, total_length)

    i_a = firstindex(a)
    i_b = firstindex(b)
    i = firstindex(result)
    while i <= total_length
        if i_a <= lastindex(a)
            result[i] = a[i_a]
            i += 1
            i_a = nextind(a, i_a)
        end
        if i_b <= lastindex(b)
            result[i] = b[i_b]
            i += 1
            i_b = nextind(b, i_b)
        end
    end
    return join(result)
end

function single_instance(rng=Random.default_rng())
    lengths = rand(rng, 1:10, 4)
    strings = [random_string(rng, l) for l in lengths]
    a, b, c, d = strings

    # True formula:
    y = interleave(a * "def" * b, last_half(c) * reverse(d) * "abc")
    return (; X=(; a, b, c, d), y)
end

dataset = let rng = Random.MersenneTwister(0)
    [single_instance(rng) for _ in 1:128]
end

X = [d.X for d in dataset]
y = [d.y for d in dataset]

#=
First, there are some key functions we will need to overload
=#

using Random: AbstractRNG
using SymbolicRegression.UtilsModule: poisson_sample
using SymbolicRegression.CoreModule: AbstractOptions

import DynamicExpressions: count_scalar_constants
import SymbolicRegression: init_value, sample_value, mutate_value
import SymbolicRegression.ConstantOptimizationModule: can_optimize
import SymbolicRegression.InterfaceDynamicExpressionsModule: string_constant

function init_value(::Type{String})
    return ""
end

function sample_value(rng::AbstractRNG, ::Type{String}, options)
    len = rand(rng, 0:5)
    # Sample all ASCII characters:
    return join(sample_alphabet(rng, options) for _ in 1:len)
end

count_scalar_constants(::String) = 1

function string_constant(val::String, ::Val{precision}, _) where {precision}
    val = replace(val, "\"" => "\\\"", "\\" => "\\\\")
    return '"' * val * '"'
end

max_length(options::AbstractOptions) = 10
lambda_max(options::AbstractOptions) = 5.0
sample_alphabet(rng::AbstractRNG, options::AbstractOptions) = Char(rand(rng, 32:126))

"""
    mutate_value(rng, val::String, temperature, opt)

Multi-edit string mutation.
"""
function mutate_value(rng::AbstractRNG, val::String, T, options)
    λ = max(nextfloat(0.0), lambda_max(options) * clamp(float(T), 0, 1))
    n_edits = clamp(poisson_sample(rng, λ), 0, 10)
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
        if length(chars) > max_length(options)
            chars = chars[1:max_length(options)]
        end
    end
    return String(chars[1:min(end, max_length(options))])
end

can_optimize(::Type{String}, ::AbstractOptions) = false

model = SRRegressor(;
    binary_operators=(concat, interleave),
    unary_operators=(first_half, last_half, reverse),
    operator_enum_constructor=GenericOperatorEnum,
    loss_type=Float64,
    elementwise_loss=Float64 ∘ edit_distance,
    should_optimize_constants=false,
    maxsize=15,
    batching=true,
    batch_size=16,
)

mach = machine(model, X, y)
fit!(mach)

#literate_end

# fit!(mach)
# idx1 = lastindex(report(mach).equations)
# ypred1 = predict(mach, (data=X, idx=idx1))
# loss1 = sum(i -> abs2(ypred1[i] - y[i]), eachindex(y)) / length(y)

# # Should keep all parameters
# stop_at[] = loss1 * 0.999
# mach.model.niterations *= 2
# fit!(mach)
# idx2 = lastindex(report(mach).equations)
# ypred2 = predict(mach, (data=X, idx=idx2))
# loss2 = sum(i -> abs2(ypred2[i] - y[i]), eachindex(y)) / length(y)

# # Should get better:
# @test loss1 >= loss2
