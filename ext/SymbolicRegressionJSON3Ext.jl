module LaSRJSON3Ext

using JSON3: JSON3
import LibraryAugmentedSymbolicRegression.UtilsModule: json3_write

function json3_write(record, recorder_file)
    open(recorder_file, "w") do io
        JSON3.write(io, record; allow_inf=true)
    end
end

end
