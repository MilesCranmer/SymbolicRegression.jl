@testitem "JET static analysis" begin
    if VERSION < v"1.10.0" || VERSION >= v"1.12.0-DEV.0"
        @info "Skipping JET tests on unsupported Julia version" VERSION
        @test true
        return nothing
    end

    try
        SymbolicRegression.__dispatch_doctor_unsable_test()
    catch e
        @error "Dispatch doctor is still enabled" exception=(e, catch_backtrace())
        @test false
    end

    using SymbolicRegression
    using JET

    JET.test_package(SymbolicRegression; target_defined_modules=true)

    # JET throws on failure, so reaching here means success.
    @test true
end
