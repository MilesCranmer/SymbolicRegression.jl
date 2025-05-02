#! format: off

#literate_begin file="src/examples/custom_types.md"
#=
# Working with Custom Input Types

Say that you have some custom input type you want to evolve an expression for.
It doesn't even need to be a numerical type. It could be anything --- even a string!

Let's actually try this. Let's evolve an _expression over strings_.

First, we mock up a dataset. Say that we wish to find the expression

```math
y = \text{interleave}(
    \text{concat}(x_1, \text{concat}(\text{``abc''}, x_2)),
    \text{concat}(
        \text{concat}(\text{last\_half}(x_3), \text{reverse}(x_4)),
        \text{``xyz''}
    )
)
```

We will define some unary and binary operators on strings:
=#

using SymbolicRegression
using DynamicExpressions: GenericOperatorEnum
using MLJBase: machine, fit!, report, MLJBase
using Random

"""Returns the first half of the string."""
head(s::String) = length(s) == 0 ? "" : join(collect(s)[1:max(1, div(length(s), 2))])

"""Returns the second half of the string."""
tail(s::String) = length(s) == 0 ? "" : join(collect(s)[max(1, div(length(s), 2) + 1):end])

"""Concatenates two strings."""
concat(a::String, b::String) = a * b

"""Interleaves characters from two strings."""
function zip(a::String, b::String)
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

#=
Now, let's use these operators to create a dataset.
=#

function single_instance(rng=Random.default_rng())
    x_1 = join(rand(rng, 'a':'z', rand(rng, 1:10)))
    x_2 = join(rand(rng, 'a':'z', rand(rng, 1:10)))
    x_3 = join(rand(rng, 'a':'z', rand(rng, 1:10)))
    x_4 = join(rand(rng, 'a':'z', rand(rng, 1:10)))

    ## True formula:
    y = zip(x_1 * "abc" * x_2, tail(x_3) * reverse(x_4) * "xyz")
    return (; X=(; x_1, x_2, x_3, x_4), y)
end

dataset = let rng = Random.MersenneTwister(0)
    [single_instance(rng) for _ in 1:128]
end

#=
We'll get them in the right format for MLJ:
=#

X = [d.X for d in dataset]
y = [d.y for d in dataset];

#=
To actually get this working with SymbolicRegression,
there are some key functions we will need to overload.

First, we say that a single string is one "scalar" constant:
=#

import DynamicExpressions: count_scalar_constants
count_scalar_constants(::String) = 1

#=
Next, we define an initializer (which is normally 0.0 for numeric types).
=#

import SymbolicRegression: init_value
init_value(::Type{String}) = ""

#=
Next, we define a random sampler. This is only used for
generating initial random leafs; the `mutate_value` function
is used for mutating them and moving around in the search space.
=#

using Random: AbstractRNG
import SymbolicRegression: sample_value
sample_value(rng::AbstractRNG, ::Type{String}, _) = join(rand(rng, 'a':'z') for _ in 1:rand(rng, 0:5))

#=
We also define a pretty printer for strings,
so it is easier to tell apart variables and operators
from string constants.
=#

import SymbolicRegression.InterfaceDynamicExpressionsModule: string_constant
function string_constant(val::String, ::Val{precision}, _) where {precision}
    val = replace(val, "\"" => "\\\"", "\\" => "\\\\")
    return '"' * val * '"'
end

#=
We also disable constant optimization for strings,
since it is not really defined. If you have a type that you
do want to optimize, you should follow the `DynamicExpressions`
value interface and define the `get_scalar_constants` and `set_scalar_constants!`
functions.
=#

import SymbolicRegression.ConstantOptimizationModule: can_optimize
can_optimize(::Type{String}, _) = false

#=
Finally, the most complicated overload for `String` is `mutate_value`,
which we need to define so that any constant value can be iteratively mutated
into any other constant value.

We also typically want this to depend on the temperature --- lower temperatures
mean a smaller rate of change. You can use temperature as you see fit, or ignore it.
=#

using SymbolicRegression.UtilsModule: poisson_sample

import SymbolicRegression: mutate_value

sample_alphabet(rng::AbstractRNG) = rand(rng, 'a':'z')

function mutate_value(rng::AbstractRNG, val::String, T, options)
    max_length = 10
    lambda_max = 5.0
    λ = max(nextfloat(0.0), lambda_max * clamp(float(T), 0, 1))
    n_edits = clamp(poisson_sample(rng, λ), 0, 10)
    chars = collect(val)
    ops = rand(rng, (:insert, :delete, :replace, :swap), n_edits)
    for op in ops
        if op == :insert
            insert!(chars, rand(rng, 0:length(chars)) + 1, sample_alphabet(rng))
        elseif op == :delete && !isempty(chars)
            deleteat!(chars, rand(rng, eachindex(chars)))
        elseif op == :replace
            if isempty(chars)
                push!(chars, sample_alphabet(rng))
            else
                chars[rand(rng, eachindex(chars))] = sample_alphabet(rng)
            end
        elseif op == :swap && length(chars) >= 2
            i = rand(rng, 1:(length(chars) - 1))
            chars[i], chars[i + 1] = chars[i + 1], chars[i]
        end
        if length(chars) > max_length
            chars = chars[1:max_length]
        end
    end
    return String(chars[1:min(end, max_length)])
end

#=
This concludes the custom type interface. Now let's actually use it!

For the loss function, we will use Levenshtein edit distance.
This lets the evolutionary algorithm gradually change the strings
into the desired output.
=#

function edit_distance(a::String, b::String)::Float64
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

    return Float64(prev[n + 1])  ## Make sure to convert to your `loss_type`!
end

#=
Next, let's create our regressor object. We pass `binary_operators`
and `unary_operators` as normal, but now we also pass `GenericOperatorEnum`,
because we are dealing with non-numeric types.

We also need to manually define the `loss_type`, since it's not inferrable from
`loss_type`.
=#
binary_operators = (concat, zip)
unary_operators = (head, tail, reverse)
hparams = (;
    batching=true,
    batch_size=32,
    maxsize=20,
    parsimony=0.1,
    adaptive_parsimony_scaling=20.0,
    mutation_weights=MutationWeights(; mutate_constant=1.0),
    early_stop_condition=(l, c) -> l < 1.0 && c <= 15,  # src
)
model = SRRegressor(;
    binary_operators,
    unary_operators,
    operator_enum_constructor=GenericOperatorEnum,
    elementwise_loss=edit_distance,
    loss_type=Float64,
    hparams...,
);

mach = machine(model, X, y; scitype_check_level=0)

#=
At this point, you would run `fit!(mach)` as usual.
Ignore the MLJ warnings about `scitype`s.
```julia
fit!(mach)
```
=#

#literate_end

using Test

fit!(mach)

ŷ = report(mach).equations[end](MLJBase.matrix(X; transpose=true))
mean_loss = sum(map(edit_distance, y, ŷ)) / length(y)
@test mean_loss <= 8.0
#! format: on
