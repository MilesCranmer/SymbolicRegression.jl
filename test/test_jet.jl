if !(VERSION >= v"1.10.0" && VERSION < v"1.11.0-DEV.0")
    exit(0)
end
# TODO: Check why is breaking on 1.11.0

dir = mktempdir()

@info "Starting test_jet.jl" dir

using Pkg
@info "Creating environment..."
Pkg.activate(dir; io=devnull)
Pkg.develop(; path=dirname(@__DIR__), io=devnull)
Pkg.add(["JET", "Preferences"]; io=devnull)
@info "Done!"

using Preferences
cd(dir)
Preferences.set_preferences!("SymbolicRegression", "instability_check" => "disable")

using SymbolicRegression
using JET

@info "Running tests..."
JET.test_package(SymbolicRegression; target_defined_modules=true)
@info "Done!"

@info "test_jet.jl finished"
