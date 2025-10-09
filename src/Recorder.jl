module RecorderModule

using ..CoreModule: RecordType

"Conditionally execute code based on options.use_recorder"
macro recorder(options, ex)
    return quote
        if $(esc(options)).use_recorder
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
