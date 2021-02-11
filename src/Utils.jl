using Printf: @printf

function debug(verbosity, string...)
    if verbosity > 0
        println(string...)
    end
end

function debug_inline(verbosity, string...)
    if verbosity > 0
        print(string...)
    end
end

function getTime()::Int
    return round(Int, 1e3*(time()-1.6e9))
end


function check_numeric(n)
    return tryparse(Float64, n) !== nothing
end

function is_anonymous_function(op)
	op_string = string(nameof(op))
	return length(op_string) > 1 && op_string[1] == '#' && check_numeric(op_string[2:2])
end
