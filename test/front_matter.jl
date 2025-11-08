# Common imports and TEST_GROUP selection
using Test
using TestItems
using TestItemRunner
using Preferences: set_preferences!

ENV["SYMBOLIC_REGRESSION_IS_TESTING"] = "true"

# Allow TEST_GROUP via ENV or the first CLI arg, default to "unit/basic"
const TEST_GROUP = let g = get(ENV, "TEST_GROUP", nothing)
    g === nothing && length(ARGS) > 0 ? ARGS[1] : (g === nothing ? "unit/basic" : g)
end

ENV["SYMBOLIC_REGRESSION_TEST"] = "true"

if TEST_GROUP == "integration/jet"
    set_preferences!("SymbolicRegression", "dispatch_doctor_mode" => "disable"; force=true)
end
