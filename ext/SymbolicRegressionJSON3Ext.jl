module SymbolicRegressionSymbolicUtilsExt

if isdefined(Base, :get_extension)
    using JSON3: JSON3
    import SymbolicRegression.UtilsModule: json3_write
else
    using ..JSON3: JSON3
    import ..SymbolicRegression.UtilsModule: json3_write
end

function json3_write(record, recorder_file)
    open(recorder_file, "w") do io
        JSON3.write(io, record; allow_inf=true)
    end
end

end
