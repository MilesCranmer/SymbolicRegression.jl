module SymbolicRegressionPythonCallExt

using PythonCall: PythonCall
using SymbolicRegression: SymbolicRegression

precompile(Tuple{Type{PythonCall.PyArray},PythonCall.Py})
for T in (
    SymbolicRegression.Options,
    SymbolicRegression.OperatorEnum,
    SymbolicRegression.ExpressionSpec,
    SymbolicRegression.ExternalStop,
    IOBuffer,
    Symbol,
)
    precompile(
        Tuple{typeof(PythonCall.JlWrap.pyjlany_call),Type{T},PythonCall.Py,PythonCall.Py}
    )
end
let mapping_rule = PythonCall.Convert.pyconvert_fix(
        Dict{Symbol,Any}, PythonCall.Convert.pyconvert_rule_mapping
    )
    precompile(Tuple{typeof(mapping_rule),PythonCall.Py})
end
for T in (Vector{PythonCall.Py}, Vector{Any}, Vector, Tuple, NamedTuple)
    rule = PythonCall.Convert.pyconvert_fix(T, PythonCall.Convert.pyconvert_rule_iterable)
    precompile(Tuple{typeof(rule),PythonCall.Py})
end
precompile(Tuple{typeof(PythonCall.pyconvert),Type{Array},PythonCall.Py})
precompile(
    Tuple{
        typeof(PythonCall.Convert._pyconvert_rule_iterable),
        Vector{String},
        PythonCall.Py,
        Type{Any},
    },
)
for N in (1, 2)
    precompile(Tuple{typeof(copy),PythonCall.PyArray{Float32,N,true,true,Float32}})
end

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
                progress=true,
                runtests=true,
            ),
            parallelism="multithreading",
            search_verbosity=1,
            precompile_serialization=true,
        )
    end
end

end
