include("front_matter.jl")

if !occursin(r"^(unit|integration)/", TEST_GROUP)
    error("TEST_GROUP must start with 'unit/' or 'integration/', got: $(TEST_GROUP)")
end

if startswith(TEST_GROUP, "integration/")
    integration_name = replace(TEST_GROUP, "integration/" => "")
    integration_dir = joinpath(@__DIR__, "integration", integration_name)

    if !isdir(integration_dir)
        error("Integration directory does not exist: $(integration_dir)")
    end

    using Pkg
    Pkg.activate(integration_dir)
    Pkg.instantiate()

    if startswith(integration_name, "ext/mlj") && integration_name == "ext/mlj/templates"
        include(joinpath(@__DIR__, "..", "example.jl"))
        include(joinpath(@__DIR__, "..", "examples", "parameterized_function.jl"))
        include(joinpath(@__DIR__, "..", "examples", "custom_types.jl"))
    end

    @run_package_tests(
        filter = ti -> startswith(ti.filename, integration_dir), verbose = true
    )
else
    @testset "SymbolicRegression.jl" begin
        test_dir = joinpath(@__DIR__, TEST_GROUP)

        if !isdir(test_dir)
            error("Test directory does not exist: $(test_dir)")
        end

        @run_package_tests(filter = ti -> startswith(ti.filename, test_dir), verbose = true)
    end
end
