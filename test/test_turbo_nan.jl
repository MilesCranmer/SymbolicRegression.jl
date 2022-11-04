using SymbolicRegression
using Test

bad_op(x::T) where {T} = (x >= 0) ? x : T(0)

options = Options(;
    unary_operators=(sin, exp, sqrt, bad_op),
    binary_operators=(+, *),
    turbo=true,
    nested_constraints=[sin => [sin => 0], exp => [exp => 0]],
    maxsize=30,
    npopulations=40,
    parsimony=0.01,
)

tree = Node(3, Node(1, Node(; val=-π / 2)))

# Should still be safe against domain errors:
try
    tree([0.0]')
    @test true
catch e
    @test false
end

tree = Node(3, Node(1, Node(; feature=1)))

try
    tree([-π / 2]')
    @test true
catch e
    @test false
end
