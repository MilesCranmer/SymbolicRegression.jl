module SymbolicRegressionPythonCallExt

using PythonCall: PythonCall
using SymbolicRegression: SymbolicRegression

redirect_stdout(devnull) do
    redirect_stderr(devnull) do
        SymbolicRegression.do_precompilation(Val(:precompile))
        return SymbolicRegression.do_precompilation(
            Val(:precompile);
            operator_kwargs=(;
                operators=SymbolicRegression.OperatorEnum(((), (+, -, /, *)))
            ),
            search_kwargs=(;
                external_stop=SymbolicRegression.ExternalStop(),
                variable_names=["x0", "x1", "x2"],
                display_variable_names=["x0", "x1", "x2"],
                y_variable_names=nothing,
                X_units=nothing,
                y_units=nothing,
                logger=nothing,
                run_id="precompile",
                progress=false,
                runtests=true,
            ),
            parallelism="multithreading",
            precompile_serialization=true,
        )
    end
end

end
