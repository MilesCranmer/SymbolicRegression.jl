using TestItems: @testitem
using TestItemRunner: @run_package_tests

ENV["SYMBOLIC_REGRESSION_TEST"] = "true"
tags_to_run = let t = get(ENV, "SYMBOLIC_REGRESSION_TEST_SUITE", "unit,integration")
    t = split(t, ",")
    t = map(Symbol, t)
    t
end

include("unittest.jl")
include("full.jl")

@testitem "Aqua tests" tags = [:integration] begin
    include("test_aqua.jl")
end
@testitem "JET tests" tags = [:integration] begin
    include("test_jet.jl")
end

@eval @run_package_tests filter = ti -> !isdisjoint(ti.tags, $tags_to_run)
