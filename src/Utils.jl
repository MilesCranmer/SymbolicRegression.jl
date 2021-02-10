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

# Check for errors before they happen
function testOptionConfiguration(T, options::Options)
    
    for op in (options.binops..., options.unaops...)
		if is_anonymous_function(op)
			throw(AssertionError("Anonymous functions can't be used as operators for SymbolicRegression.jl"))
        end
    end

	test_input = map(x->convert(T, x), LinRange(-100, 100, 99))
	cur_op = nothing
    try
        for left in test_input
            for right in test_input
                for binop in options.binops
					cur_op = binop
                    test_output = binop.(left, right)
                end
            end
            for unaop in options.unaops
				cur_op = unaop
                test_output = unaop.(left)
            end
        end
    catch error
        throw(AssertionError("Your configuration is invalid - one of your operators ($cur_op) is not well-defined over the real line."))
    end

    for binop in options.binops
        if binop in options.unaops
            throw(AssertionError("Your configuration is invalid - one operator ($binop) appears in both the binary operators and unary operators."))
        end
    end
end

# Check for errors before they happen
function testDatasetConfiguration(dataset::Dataset{T}, options::Options) where {T<:Real}
    n = dataset.n
    if n != size(dataset.X, 2) || n != size(dataset.y, 1)
        throw(AssertionError("Dataset dimensions are invalid. Make sure X is of shape [features, rows], y is of shape [rows] and if there are weights, they are of shape [rows]."))
    end

    if size(dataset.X, 2) > 10000
        if !options.batching
            debug(options.verbosity, "Note: you are running with more than 10,000 datapoints. You should consider turning on batching (`options.batching`), and also if you need that many datapoints. Unless you have a large amount of noise (in which case you should smooth your dataset first), generally < 10,000 datapoints is enough to find a functional form.")
        end
    end
end

# Re-define user created functions on workers
function move_functions_to_workers(T, procs, options::Options)
    for degree=1:2
        ops = degree == 1 ? options.unaops : options.binops
        for op in ops
            try
                test_function_on_workers(T, degree, op, procs)
            catch e
                undefined_on_workers = isa(e.captured.ex, UndefVarError)
                if undefined_on_workers
                    name = nameof(op)
                    debug(options.verbosity, "Copying definition of $op to workers.")
                    src_ms = methods(op).ms
                    # Thanks https://discourse.julialang.org/t/easy-way-to-send-custom-function-to-distributed-workers/22118/2
                    @everywhere procs @eval function $name end
                    for m in src_ms
                        @everywhere procs @eval $m
                    end
                else
                    throw(e)
                end
            end
            # Test configuration again to make sure it worked.
            test_function_on_workers(T, degree, op, procs)
        end
    end
end

function test_function_on_workers(T, degree, op, procs)
    futures = []
    for proc in procs
        if degree == 1
            push!(futures,
                  @spawnat proc op(convert(T, 0)))
        else
            push!(futures,
                  @spawnat proc op(convert(T, 0), convert(T, 0)))
        end
    end
    for future in futures
        fetch(future)
    end
end

function activate_env_on_workers(procs, project_path::String, options::Options)
    debug(options.verbosity, "Activating environment on workers.")
    @everywhere procs begin
        Base.MainInclude.eval(quote
            using Pkg
            Pkg.activate($$project_path)
        end)
    end
end

function import_module_on_workers(procs, filename::String, options::Options)
    included_local = !("SymbolicRegression" in [k.name for (k, v) in Base.loaded_modules])
    if included_local
        debug_inline(options.verbosity, "Importing local module ($filename) on workers...")
        @everywhere procs begin
            # Parse functions on every worker node
            Base.MainInclude.eval(quote
                include($$filename)
                using .SymbolicRegression
            end)
        end
        debug(options.verbosity, "Finished!")
    else
        debug_inline(options.verbosity, "Importing installed module on workers...")
        @everywhere procs begin
            Base.MainInclude.eval(using SymbolicRegression)
        end
        debug(options.verbosity, "Finished!")
    end
end

function test_module_on_workers(procs, options::Options)
    debug_inline(options.verbosity, "Testing module on workers...")
    futures = []
    for proc in procs
        push!(futures,
              @spawnat proc SymbolicRegression.genRandomTree(3, options, 5))
    end
    for future in futures
        fetch(future)
    end
    debug(options.verbosity, "Finished!")
end

function test_entire_pipeline(procs, dataset::Dataset{T}, options::Options) where {T<:Real}
    futures = []
    debug_inline(options.verbosity, "Testing entire pipeline on workers...")
    for proc in procs
        push!(futures, @spawnat proc begin
            tmp_pop = Population(dataset, convert(T, 1), npop=20, nlength=3, options=options, nfeatures=dataset.nfeatures)
            SRCycle(dataset, convert(T, 1), tmp_pop, 5, 5, ones(T, dataset.n), verbosity=options.verbosity, options=options)
        end)
    end
    for future in futures
        fetch(future)
    end
    debug(options.verbosity, "Finished!")
end
