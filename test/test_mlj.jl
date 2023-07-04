import SymbolicRegression: SRRegressor, MultitargetSRRegressor
import MLJTestInterface as MTI
import MLJBase: machine, fit!, report, predict
using Test

macro quiet(ex)
    return quote
        redirect_stderr(devnull) do
            $ex
        end
    end |> esc
end

@testset "Generic interface tests" begin
    failures, summary = MTI.test(
        [SRRegressor], MTI.make_regression()...; mod=@__MODULE__, verbosity=0, throw=true
    )
    @test isempty(failures)

    X = randn(100, 3)
    Y = @. cos(X^2) * 3.2 - 0.5
    (X, Y) = MTI.table.((X, Y))
    failures, summary = MTI.test(
        [MultitargetSRRegressor], X, Y; mod=@__MODULE__, verbosity=0, throw=true
    )
    @test isempty(failures)
end

@testset "Variable names" begin
    @testset "Single outputs" begin
        X = (a=rand(32), b=rand(32))
        y = X.a .^ 2.1
        model = SRRegressor(; niterations=10)
        mach = machine(model, X, y)
        fit!(mach)
        rep = report(mach)
        @test occursin("a", rep.equation_strings[rep.best_idx])
    end

    @testset "Multiple outputs" begin
        X = (a=rand(32), b=rand(32))
        y = X.a .^ 2.1
        model = MultitargetSRRegressor(; niterations=10)
        mach = machine(model, X, reduce(hcat, [reshape(y, :, 1) for i in 1:3]))
        fit!(mach)
        rep = report(mach)
        @test all(
            eq -> occursin("a", eq), [rep.equation_strings[i][rep.best_idx[i]] for i in 1:3]
        )
    end

    # @testset "Named outputs" begin
    #     X = (b1=randn(32), b2=randn(32))
    #     Y = (c1=X.b1 .* X.b2, c2=X.b1 .+ X.b2)
    #     model = MultitargetSRRegressor(; niterations=10)
    #     mach = machine(model, X, Y)
    #     fit!(mach)
    #     test_outs = predict(mach, X)
    #     @test isempty(setdiff((:c1, :c2), keys(test_outs)))
    #     @test_throws AssertionError predict(mach, (a1=randn(32), b2=randn(32)))
    #     VERSION >= v"1.8" &&
    #         @test_throws "Variable names do not match fitted" predict(mach, (b1=randn(32), a2=randn(32)))
    # end
end

@testset "Good predictions" begin
    X = randn(100, 3)
    Y = X
    model = MultitargetSRRegressor(; niterations=10)
    mach = machine(model, X, Y)
    fit!(mach)
    @test sum(abs2, predict(mach, X) .- Y) < 1e-6
end

@testset "Helpful errors" begin
    model = MultitargetSRRegressor()
    mach = machine(model, randn(32, 3), randn(32); scitype_check_level=0)
    @test_throws AssertionError @quiet(fit!(mach))
    VERSION >= v"1.8" &&
        @test_throws "For single-output regression, please" @quiet(fit!(mach))

    model = SRRegressor()
    mach = machine(model, randn(32, 3), randn(32, 2); scitype_check_level=0)
    @test_throws AssertionError @quiet(fit!(mach))
    VERSION >= v"1.8" &&
        @test_throws "For multi-output regression, please" @quiet(fit!(mach))
end
