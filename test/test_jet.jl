using SymbolicRegression
using JET

if VERSION >= v"1.10"
    JET.test_package(SymbolicRegression; target_defined_modules=true)
end
