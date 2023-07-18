module RecorderModule

import ..CoreModule: RecordType, Options

is_recording(::Options{CT,use_recorder} where {CT}) where {use_recorder} = use_recorder

"Assumes that `options` holds the user options::Options"
macro recorder(ex)
    quote
        if is_recording($(esc(:options)))
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
