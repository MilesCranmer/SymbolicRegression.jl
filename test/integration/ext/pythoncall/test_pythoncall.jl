@testitem "PythonCall extension precompiles PySR-shaped searches" begin
    using SymbolicRegression
    using PythonCall

    @test Base.get_extension(SymbolicRegression, :SymbolicRegressionPythonCallExt) !==
        nothing

    # Coverage bypasses cached native code. Without coverage, PySR-shaped
    # versus control compile time was 0.83 vs 4.57 s on Julia 1.13.1 and
    # 1.16 vs 4.48 s on Julia 1.10.12.
    code = raw"""
    using SymbolicRegression, PythonCall
    @assert Base.JLOptions().code_coverage == 0
    ext = Base.get_extension(SymbolicRegression, :SymbolicRegressionPythonCallExt)
    # Julia 1.10's @timed omits compile_time; its compiler counter uses nanoseconds.
    Base.cumulative_compile_timing(true)
    before = first(Base.cumulative_compile_time_ns())
    pysr_timed = @timed ext.pysr_shaped_workload(Val(:compile))
    middle = first(Base.cumulative_compile_time_ns())
    control_timed = @timed ext.pysr_shaped_workload(
        Val(:compile), SymbolicRegression.OperatorEnum(((cos,), (+, *)))
    )
    after = first(Base.cumulative_compile_time_ns())
    Base.cumulative_compile_timing(false)
    compile_seconds(timed, start_ns, end_ns) = hasproperty(timed, :compile_time) ?
        timed.compile_time : (end_ns - start_ns) / 1e9
    pysr_compile_time = compile_seconds(pysr_timed, before, middle)
    control_compile_time = compile_seconds(control_timed, middle, after)
    println("PySR-shaped compile time: ", pysr_compile_time)
    println("Control compile time: ", control_compile_time)
    @assert pysr_compile_time < 0.45 * control_compile_time
    """
    project = dirname(Base.active_project())
    # CondaPkg scans each load-path environment, including stale global manifests.
    command = addenv(
        `$(Base.julia_cmd()) --project=$project --startup-file=no --code-coverage=none -e $code`,
        "JULIA_LOAD_PATH" => "@:@stdlib",
    )
    ok = success(command)
    @test ok
end
