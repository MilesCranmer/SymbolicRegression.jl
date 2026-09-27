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
        )
    end
end

end
