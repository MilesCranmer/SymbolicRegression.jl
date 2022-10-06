using SymbolicRegression, Test

options = Options(; binary_operators=(+, *, /, -), unary_operators=(cos, exp))

for i in 1:100
    tree = SymbolicRegression.MutationFunctionsModule.gen_random_tree(
        rand(1:15), options, 5, Float32
    )
    # Make some connections:
    for j in 1:rand(0:5)
        SymbolicRegression.MutationFunctionsModule.connect_random_nodes!(tree)
    end
    init_s = string_tree(tree, options)

    constants = SymbolicRegression.EquationUtilsModule.get_constants(tree)
    SymbolicRegression.EquationUtilsModule.set_constants(tree, constants)
    final_s = string_tree(tree, options)
    @test init_s == final_s
end
