using SymbolicRegression
using Random
using Test
include("test_params.jl")

# Test simple evaluations:
options = Options(;
    default_params..., binary_operators=(+, *, /, -), unary_operators=(cos, sin)
)

# Here, we unittest the fast function evaluation scheme
# We need to trigger all possible fused functions, with all their logic.
# These are as follows:

## We fuse (and compile) the following:
##  - op(op2(x, y)), where x, y, z are constants or variables.
##  - op(op2(x)), where x is a constant or variable.
##  - op(x), for any x.
## We fuse (and compile) the following:
##  - op(x, y), where x, y are constants or variables.
##  - op(x, y), where x is a constant or variable but y is not.
##  - op(x, y), where y is a constant or variable but x is not.
##  - op(x, y), for any x or y
for fnc in [
    # deg2_l0_r0_eval
    (x1, x2, x3) -> x1 * x2,
    (x1, x2, x3) -> x1 * 3.0f0,
    (x1, x2, x3) -> 3.0f0 * x2,
    (((x1, x2, x3) -> 3.0f0 * 6.0f0), ((x1, x2, x3) -> Node(; val=3.0f0) * 6.0f0)),
    # deg2_l0_eval
    (x1, x2, x3) -> x1 * sin(x2),
    (x1, x2, x3) -> 3.0f0 * sin(x2),

    # deg2_r0_eval
    (x1, x2, x3) -> sin(x1) * x2,
    (x1, x2, x3) -> sin(x1) * 3.0f0,

    # deg1_l2_ll0_lr0_eval
    (x1, x2, x3) -> cos(x1 * x2),
    (x1, x2, x3) -> cos(x1 * 3.0f0),
    (x1, x2, x3) -> cos(3.0f0 * x2),
    (
        ((x1, x2, x3) -> cos(3.0f0 * -0.5f0)),
        ((x1, x2, x3) -> cos(Node(; val=3.0f0) * -0.5f0)),
    ),

    # deg1_l1_ll0_eval
    (x1, x2, x3) -> cos(sin(x1)),
    (((x1, x2, x3) -> cos(sin(3.0f0))), ((x1, x2, x3) -> cos(sin(Node(; val=3.0f0))))),

    # everything else:
    (x1, x2, x3) -> (sin(cos(sin(cos(x1) * x3) * 3.0f0) * -0.5f0) + 2.0f0) * 5.0f0,
]

    # check if fnc is tuple
    if typeof(fnc) <: Tuple
        realfnc = fnc[1]
        nodefnc = fnc[2]
    else
        realfnc = fnc
        nodefnc = fnc
    end

    global tree = nodefnc(Node("x1"), Node("x2"), Node("x3"))

    N = 100
    nfeatures = 3
    X = randn(MersenneTwister(0), Float32, nfeatures, N)

    test_y = eval_tree_array(tree, X, options)[1]
    true_y = realfnc.(X[1, :], X[2, :], X[3, :])

    zero_tolerance = 1e-6
    @test all(abs.(test_y .- true_y) / N .< zero_tolerance)
end
