@testitem "JET static analysis" begin
    if VERSION < v"1.10.0" || VERSION >= v"1.12.0-DEV.0"
        @info "Skipping JET tests on unsupported Julia version" VERSION
        @test true
        return
    end

    using SymbolicRegression
    using JET

    JET.test_package(SymbolicRegression; target_defined_modules=true)

    # JET throws on failure, so reaching here means success.
    @test true
end
