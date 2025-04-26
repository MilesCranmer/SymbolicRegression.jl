module RecorderModule

using ..CoreModule: RecordType
using BorrowChecker: BorrowChecker

"Assumes that `options` holds the user options::AbstractOptions"
macro recorder(ex)
    quote
        if $(BorrowChecker).@take($(esc(:options)).use_recorder)
            $(esc(ex))
        end
    end
end

function find_iteration_from_record(key::String, record::RecordType)
    iteration = 0
    while haskey(record[key], "iteration$(iteration)")
        iteration += 1
    end
    return iteration - 1
end

end
