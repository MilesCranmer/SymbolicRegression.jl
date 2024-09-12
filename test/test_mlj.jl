@testitem "Generic interface tests" tags = [:part1] begin
    using LaSR
    using MLJTestInterface: MLJTestInterface as MTI
    include("test_params.jl")

    failures, summary = MTI.test(
        [LaSRRegressor], MTI.make_regression()...; mod=@__MODULE__, verbosity=0, throw=true
    )
    @test isempty(failures)

    X = randn(100, 3)
    Y = @. cos(X^2) * 3.2 - 0.5
    (X, Y) = MTI.table.((X, Y))
    w = ones(100)
    failures, summary = MTI.test(
        [MultitargetLaSRRegressor], X, Y, w; mod=@__MODULE__, verbosity=0, throw=true
    )
    @test isempty(failures)
end

@testitem "Variable names - single outputs" tags = [:part3] begin
    using LaSR
    using LaSR: Node
    using MLJBase
    using SymbolicUtils
    using Random: MersenneTwister

    include("test_params.jl")

    stop_kws = (; early_stop_condition=(loss, complexity) -> loss < 1e-5)

    rng = MersenneTwister(0)
    X = (a=rand(rng, 32), b=rand(rng, 32))
    y = X.a .^ 2.1
    # We also make sure the deprecated npop and npopulations still work:
    model = LaSRRegressor(; niterations=10, npop=1000, npopulations=15, stop_kws...)
    mach = machine(model, X, y)
    fit!(mach)
    rep = report(mach)
    @test occursin("a", rep.equation_strings[rep.best_idx])
    ypred_good = predict(mach, X)
    @test sum(abs2, predict(mach, X) .- y) / length(y) < 1e-5

    # Check that we can choose the equation
    ypred_same = predict(mach, (data=X, idx=rep.best_idx))
    @test ypred_good == ypred_same

    ypred_bad = predict(mach, (data=X, idx=1))
    @test ypred_good != ypred_bad

    # Smoke test SymbolicUtils
    eqn = node_to_symbolic(rep.equations[rep.best_idx], model)
    n = symbolic_to_node(eqn, model)
    eqn2 = convert(SymbolicUtils.Symbolic, n, model)
    n2 = convert(Node, eqn2, model)
end

@testitem "Variable names - multiple outputs" tags = [:part1] begin
    using LaSR
    using MLJBase
    using Random: MersenneTwister

    include("test_params.jl")

    stop_kws = (; early_stop_condition=(loss, complexity) -> loss < 1e-5)

    rng = MersenneTwister(0)
    X = (a=rand(rng, 32), b=rand(rng, 32))
    y = X.a .^ 2.1
    model = MultitargetLaSRRegressor(; niterations=10, stop_kws...)
    mach = machine(model, X, reduce(hcat, [reshape(y, :, 1) for i in 1:3]))
    fit!(mach)
    rep = report(mach)
    @test all(
        eq -> occursin("a", eq), [rep.equation_strings[i][rep.best_idx[i]] for i in 1:3]
    )
    ypred_good = predict(mach, X)

    # Test that we can choose the equation
    ypred_same = predict(mach, (data=X, idx=rep.best_idx))
    @test ypred_good == ypred_same

    ypred_bad = predict(mach, (data=X, idx=[1, 1, 1]))
    @test ypred_good != ypred_bad

    ypred_mixed = predict(mach, (data=X, idx=[rep.best_idx[1], 1, rep.best_idx[3]]))
    @test ypred_mixed == hcat(ypred_good[:, 1], ypred_bad[:, 2], ypred_good[:, 3])

    @test_throws AssertionError predict(mach, (data=X,))
    VERSION >= v"1.8" &&
        @test_throws "If specifying an equation index during" predict(mach, (data=X,))
    VERSION >= v"1.8" &&
        @test_throws "If specifying an equation index during" predict(mach, (X=X, idx=1))
end

@testitem "Variable names - named outputs" tags = [:part1] begin
    using LaSR
    using MLJBase
    using Random: MersenneTwister

    include("test_params.jl")

    stop_kws = (; early_stop_condition=(loss, complexity) -> loss < 1e-5)

    rng = MersenneTwister(0)
    X = (b1=randn(rng, 32), b2=randn(rng, 32))
    Y = (c1=X.b1 .* X.b2, c2=X.b1 .+ X.b2)
    w = ones(32)
    model = MultitargetLaSRRegressor(; niterations=10, stop_kws...)
    mach = machine(model, X, Y, w)
    fit!(mach)
    test_outs = predict(mach, X)
    @test isempty(setdiff((:c1, :c2), keys(test_outs)))
    @test_throws AssertionError predict(mach, (a1=randn(32), b2=randn(32)))
    VERSION >= v"1.8" && @test_throws "Variable names do not match fitted" predict(
        mach, (b1=randn(32), a2=randn(32))
    )
end

@testitem "Good predictions" tags = [:part1] begin
    using LaSR
    using MLJBase
    using Random: MersenneTwister

    include("test_params.jl")

    stop_kws = (; early_stop_condition=(loss, complexity) -> loss < 1e-5)

    rng = MersenneTwister(0)
    X = randn(rng, 100, 3)
    Y = X
    model = MultitargetLaSRRegressor(; niterations=10, stop_kws...)
    mach = machine(model, X, Y)
    fit!(mach)
    @test sum(abs2, predict(mach, X) .- Y) / length(X) < 1e-6
end

@testitem "Helpful errors" tags = [:part3] begin
    using LaSR
    using MLJBase
    using Random: MersenneTwister

    include("test_params.jl")

    model = MultitargetLaSRRegressor()
    rng = MersenneTwister(0)
    mach = machine(model, randn(rng, 32, 3), randn(rng, 32); scitype_check_level=0)
    @test_throws AssertionError @quiet(fit!(mach))
    VERSION >= v"1.8" &&
        @test_throws "For single-output regression, please" @quiet(fit!(mach))

    model = LaSRRegressor()
    rng = MersenneTwister(0)
    mach = machine(model, randn(rng, 32, 3), randn(rng, 32, 2); scitype_check_level=0)
    @test_throws AssertionError @quiet(fit!(mach))
    VERSION >= v"1.8" &&
        @test_throws "For multi-output regression, please" @quiet(fit!(mach))

    model = LaSRRegressor(; verbosity=0)
    rng = MersenneTwister(0)
    mach = machine(model, randn(rng, 32, 3), randn(rng, 32))
    @test_throws ErrorException @quiet(fit!(mach; verbosity=0))
end

@testitem "Unfinished search" tags = [:part3] begin
    using LaSR
    using MLJBase
    using Suppressor
    using Random: MersenneTwister

    model = LaSRRegressor(; timeout_in_seconds=1e-10)
    rng = MersenneTwister(0)
    mach = machine(model, randn(rng, 32, 3), randn(rng, 32))
    fit!(mach)
    # Ensure that the hall of fame is empty:
    _, hof = mach.fitresult.state
    hof.exists .= false
    # Recompute the report:
    mach.report[:fit] = LaSR.MLJInterfaceModule.full_report(
        model, mach.fitresult
    )
    @test report(mach).best_idx == 0
    @test predict(mach, randn(32, 3)) == zeros(32)
    msg = @capture_err begin
        predict(mach, randn(32, 3))
    end
    @test occursin("Evaluation failed either due to", msg)

    model = MultitargetLaSRRegressor(; timeout_in_seconds=1e-10)
    rng = MersenneTwister(0)
    mach = machine(model, randn(rng, 32, 3), randn(rng, 32, 3))
    fit!(mach)
    # Ensure that the hall of fame is empty:
    _, hofs = mach.fitresult.state
    foreach(hofs) do hof
        hof.exists .= false
    end
    mach.report[:fit] = LaSR.MLJInterfaceModule.full_report(
        model, mach.fitresult
    )
    @test report(mach).best_idx == [0, 0, 0]
    @test predict(mach, randn(32, 3)) == zeros(32, 3)
    msg = @capture_err begin
        predict(mach, randn(32, 3))
    end
    @test occursin("Evaluation failed either due to", msg)
end
