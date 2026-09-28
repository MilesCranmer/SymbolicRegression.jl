@testitem "Worker smoke checks preserve remote errors" begin
    using Distributed: Distributed
    using SymbolicRegression: SymbolicRegression
    using Test: Test
    @gensym procs futures err options
    expr = quote
        $procs = $Distributed.addprocs(2)
        try
            $options = $SymbolicRegression.Options(;
                binary_operators=(+,), unary_operators=(cos,)
            )
            $err = try
                $SymbolicRegression.test_module_on_workers($procs, $options, 0)
                nothing
            catch e
                e
            end
            $Test.@test $err isa $Distributed.RemoteException
            $Test.@test $err.captured.ex isa KeyError

            $Distributed.@everywhere $procs using SymbolicRegression
            $futures = [
                $Distributed.@spawnat($procs[1], error("first worker failure")),
                $Distributed.@spawnat($procs[2], error("second worker failure")),
            ]
            $err = try
                $SymbolicRegression.fetch_all($futures)
                nothing
            catch e
                e
            end
            $Test.@test $err isa $Distributed.RemoteException
            $Test.@test $err.captured.ex isa ErrorException
            $Test.@test $err.captured.ex.msg == "first worker failure"

            $err = try
                $SymbolicRegression.test_function_on_workers((-1.0,), sqrt, $procs)
                nothing
            catch e
                e
            end
            $Test.@test $err isa $Distributed.RemoteException
            $Test.@test $err.captured.ex isa DomainError
            $Test.@test_nowarn $SymbolicRegression.test_function_on_workers(
                (4.0,), sqrt, $procs
            )
        finally
            $Distributed.rmprocs($procs)
        end
    end
    Core.eval(Core.Main, expr)
end
