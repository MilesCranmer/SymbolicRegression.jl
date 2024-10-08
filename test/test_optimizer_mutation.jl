using SymbolicRegression
using SymbolicRegression: SymbolicRegression
using SymbolicRegression: Dataset, RunningSearchStatistics, RecordType
using Optim: Optim
using SymbolicRegression.MutateModule: next_generation
using DynamicExpressions: get_scalar_constants

mutation_weights = (; optimize=1e30)  # We also test whether a named tuple works.
options = Options(;
    binary_operators=(+, -, *),
    unary_operators=(sin,),
    mutation_weights=mutation_weights,
    optimizer_options=Optim.Options(),
)

X = randn(5, 100)
y = sin.(X[1, :] .* 2.1 .+ 0.8) .+ X[2, :] .^ 2
dataset = Dataset(X, y)

x1 = Node(Float64; feature=1)
x2 = Node(Float64; feature=2)
tree = sin(x1 * 1.9 + 0.2) + x2 * x2

member = PopMember(dataset, tree, options; deterministic=false)
temperature = 1.0
maxsize = 20

new_member, _, _ = next_generation(
    dataset,
    member,
    temperature,
    maxsize,
    RunningSearchStatistics(; options=options),
    options;
    tmp_recorder=RecordType(),
)

resultant_constants, refs = get_scalar_constants(new_member.tree)
for k in [0.0, 0.2, 0.5, 1.0]
    @test sin(resultant_constants[1] * k + resultant_constants[2]) ≈ sin(2.1 * k + 0.8) atol =
        1e-3
end
