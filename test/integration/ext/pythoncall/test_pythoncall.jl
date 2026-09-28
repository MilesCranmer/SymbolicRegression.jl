@testitem "PythonCall extension precompiles PySR-shaped searches" begin
    using SymbolicRegression
    using PythonCall

    @test Base.get_extension(SymbolicRegression, :SymbolicRegressionPythonCallExt) !==
        nothing

    # Coverage bypasses cached native code, and on Julia 1.10 `julia_cmd()` also
    # carries `--pkgimages=no` from a coverage run, so the child resets both.
    # PySR-shaped over control compile time measured 0.18 to 0.26 locally and
    # 0.56 on CI (Julia 1.10); without the extension workload it was 2.1.
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
    @assert pysr_compile_time < control_compile_time
    """
    project = dirname(Base.active_project())
    # CondaPkg scans each load-path environment, including stale global manifests.
    command = addenv(
        `$(Base.julia_cmd()) --project=$project --startup-file=no --code-coverage=none --pkgimages=yes -e $code`,
        "JULIA_LOAD_PATH" => "@:@stdlib",
    )
    output = IOBuffer()
    process = run(pipeline(ignorestatus(command); stdout=output, stderr=output))
    success(process) || println(String(take!(output)))
    @test success(process)
end
