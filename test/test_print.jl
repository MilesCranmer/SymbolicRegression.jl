using Test
using SymbolicRegression
using SymbolicRegression.UtilsModule: split_string

include("test_params.jl")

## Test Base.print
options = Options(;
    default_params..., binary_operators=(+, *, /, -), unary_operators=(cos, sin)
)

f = (x1, x2, x3) -> (sin(cos(sin(cos(x1) * x3) * 3.0) * -0.5) + 2.0) * 5.0

tree = f(Node("x1"), Node("x2"), Node("x3"))

s = repr(tree)
true_s = "((sin(cos(sin(cos(x1) * x3) * 3.0) * -0.5) + 2.0) * 5.0)"

@test s == true_s

equation_search(
    randn(Float32, 3, 10),
    randn(Float32, 10);
    options=options,
    variable_names=["v1", "v2", "v3"],
    niterations=0,
    parallelism=:multithreading,
)

s = repr(tree)
true_s = "((sin(cos(sin(cos(v1) * v3) * 3.0) * -0.5) + 2.0) * 5.0)"
@test s == true_s

for unaop in [safe_log, safe_log2, safe_log10, safe_log1p, safe_sqrt, safe_acosh]
    opts = Options(;
        default_params..., binary_operators=(+, *, /, -), unary_operators=(unaop,)
    )
    minitree = Node(1, Node("x1"))
    @test string_tree(minitree, opts) == replace(string(unaop), "safe_" => "") * "(x1)"
end

for binop in [safe_pow, ^]
    opts = Options(;
        default_params..., binary_operators=(+, *, /, -, binop), unary_operators=(cos,)
    )
    minitree = Node(5, Node("x1"), Node("x2"))
    @test string_tree(minitree, opts) == "(x1 ^ x2)"
end

@testset "Test splitting of strings" begin
    split_string("abcdefgh", 3) == ["abc", "def", "gh"]
    split_string("abcdefgh", 100) == ["abcdefgh"]
    split_string("⋅", 1) == ["⋅"]
    split_string("⋅⋅", 1) == ["⋅", "⋅"]
    split_string("⋅⋅⋅⋅", 2) == ["⋅⋅", "⋅⋅"]
    split_string("ραβγ", 2) == ["ρα", "βγ"]
end
