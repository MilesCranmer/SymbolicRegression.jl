@testitem "Test whether the precompilation script works." begin
    using SymbolicRegression

    SymbolicRegression.do_precompilation(Val(:compile))
end
