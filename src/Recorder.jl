module RecorderModule

import ..CoreModule: RecordType

"Assumes that `options` holds the user options::Options"
macro recorder(ex)
    quote
        if $(esc(:options)).recorder
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
