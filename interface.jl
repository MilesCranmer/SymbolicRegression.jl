using SymbolicUtils
using Random
include("src/SymbolicRegression.jl")
using .SymbolicRegression: Node, Options, Population, printTree

Random.seed!(0)

options = Options(
    binary_operators=(+, *, /, -),
    unary_operators=(cos, exp),
    npopulations=4,
)

SymbolicUtils.istree(x::Tuple{Node,Options})::Bool = (x[1].degree > 0)

SymbolicUtils.operation(x::Tuple{Node,Options})::Function = begin
    if x[1].degree == 1
        return x[2].unaops[x[1].op]
    else #if x.degree == 2
        return x[2].binops[x[1].op]
    end
end

SymbolicUtils.arguments(x::Tuple{Node,Options})::Array{Tuple{Node,Options}} = begin
    if x[1].degree == 1
        return [(x[1].l, x[2])]
    else #if x.degree == 2
        return [(x[1].l, x[2]), (x[1].r, x[2])]
    end
end

for f ∈ [:+, :-, :*, :/, :^] #Note, this is type piracy!
    @eval begin
        Base.$f(x::Union{Expr, Symbol}, y::Number) = Expr(:call, $f, x, y)
        Base.$f(x::Number, y::Union{Expr, Symbol}) = Expr(:call, $f, x, y)
        Base.$f(x::Union{Expr, Symbol}, y::Union{Expr, Symbol}) = (Expr(:call, $f, x, y))
    end
end


X = randn(Float32, 100, 5)
y = 2 * cos.(X[:, 4]) + X[:, 1] .^ 2 .- 2

pop = Population(X, y, 1f0, npop=10, nlength=3, options=options, nfeatures=5)
t = pop.members[1].tree
printTree(t, options)

println(SymbolicUtils.arguments((t, options)))





