# HACK
using Pkg, Distributed

"""Try to dynamically create workers, and import the package."""
function test(package_name)
    procs = addprocs(2)
    project_path = splitdir(Pkg.project().path)[1]
    @everywhere procs begin
        Base.MainInclude.eval(
            quote
                using Pkg
                Pkg.activate($$project_path)
                # Import package on workers:
                using $(Symbol($package_name)): $(Symbol($package_name))
            end,
        )
    end
    rmprocs(procs)
end

packages_to_test = [
    "Distributed",
    "JSON3",
    "LineSearches",
    "LinearAlgebra",
    "LossFunctions",
    "Optim",
    "Printf",
    "Random",
    "Reexport",
    "SpecialFunctions",
    "Zygote",
    "ReverseDiff",
    "SymbolicUtils",
    "PreallocationTools",
    "SymbolicRegression",
]
for package_name in packages_to_test
    println("Testing $(package_name)...")
    test(package_name)
    println("Success!")
end