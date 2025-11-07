include("front_matter.jl")

ENV["SYMBOLIC_REGRESSION_TEST"] = "true"

@testset "SymbolicRegression.jl" begin
    # Validate TEST_GROUP format
    if !occursin(r"^(unit|integration)/", TEST_GROUP)
        error("TEST_GROUP must start with 'unit/' or 'integration/', got: $(TEST_GROUP)")
    end

    # Check if this is an integration test
    if startswith(TEST_GROUP, "integration/")
        # Extract integration name (e.g., "integration/ad" -> "ad")
        integration_name = replace(TEST_GROUP, "integration/" => "")
        integration_dir = joinpath(@__DIR__, "integration", integration_name)

        # Validate directory exists
        if !isdir(integration_dir)
            error("Integration directory does not exist: $(integration_dir)")
        end

        # Activate the integration environment
        # Note: Pkg.test() automatically develops the package being tested,
        # so we don't need to manually call Pkg.develop here
        using Pkg
        Pkg.activate(integration_dir)

        # Special case: MLJ integration runs examples
        if integration_name == "ext/mlj"
            ENV["SYMBOLIC_REGRESSION_IS_TESTING"] = "true"
            include(joinpath(@__DIR__, "..", "example.jl"))
            include(joinpath(@__DIR__, "..", "examples", "parameterized_function.jl"))
            include(joinpath(@__DIR__, "..", "examples", "custom_types.jl"))
        end

        # Run all test items in the integration directory
        @run_package_tests(
            filter = ti -> startswith(ti.filename, integration_dir), verbose = true
        )
    else
        # Unit tests
        test_dir = joinpath(@__DIR__, TEST_GROUP)

        # Validate directory exists
        if !isdir(test_dir)
            error("Test directory does not exist: $(test_dir)")
        end

        # Run all test items in the directory specified by TEST_GROUP
        @run_package_tests(filter = ti -> startswith(ti.filename, test_dir), verbose = true)
    end
end
