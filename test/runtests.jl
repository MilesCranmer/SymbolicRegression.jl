# HACK
using Pkg, Distributed
import ReverseDiff

"""Try to dynamically create workers, and import the package."""
function test(package_name)
    procs = addprocs(4)
    project_path = splitdir(Pkg.project().path)[1]
    # Import package on worker:
    @everywhere procs begin
        Base.MainInclude.eval(
            quote
                using Pkg
                Pkg.activate($$project_path)
                import $(Symbol($package_name))
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
]
for package_name in packages_to_test
    println("Testing $(package_name)...")
    test(package_name)
    println("Success!")
end