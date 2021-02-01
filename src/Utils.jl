using Printf: @printf

function id(x::T)::T where {T<:Real}
    x
end

function debug(verbosity, string...)
    if verbosity > 0
        println(string...)
    end
end

function getTime()::Int
    return round(Int, 1e3*(time()-1.6e9))
end


# Check for errors before they happen
function testOptionConfiguration(options::Options)
    test_input = LinRange(-100f0, 100f0, 99)

    try
        for left in test_input
            for right in test_input
                for binop in options.binops
                    test_output = binop.(left, right)
                end
            end
            for unaop in options.unaops
                test_output = unaop.(left)
            end
        end
    catch error
        @printf("\n\nYour configuration is invalid - one of your operators is not well-defined over the real line.\n\n\n")
        throw(error)
    end

    for binop in options.binops
        if binop in options.unaops
            @printf("\n\nYour configuration is invalid - one operator appears in both the binary operators and unary operators.\n\n\n")
        end
    end
end

# Check for errors before they happen
function testDatasetConfiguration(dataset::Dataset{T}, options::Options) where {T<:Real}
    n = dataset.n
    if n != size(dataset.X)[2] || n != size(dataset.y)[1]
        throw(error("Dataset dimensions are invalid. Make sure X is of shape [features, rows], y is of shape [rows] and if there are weights, they are of shape [rows]."))
    end

    if size(dataset.X)[2] > 10000
        if !options.batching
            println("Note: you are running with more than 10,000 datapoints. You should consider turning on batching (`options.batching`), and also if you need that many datapoints. Unless you have a large amount of noise (in which case you should smooth your dataset first), generally < 10,000 datapoints is enough to find a functional form.")
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
                    println("Copying definition of $op to workers.")
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
            test_function_on_workers(T, degree, op, procs)
        end
    end
end

function test_function_on_workers(T, degree, op, procs)
    # Test configuration again! To avoid future errors.
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

function activate_env_on_workers(procs, project_path)
    println("Activating environment on workers.")
    @everywhere procs begin
        Main.eval(quote
            using Pkg
            Pkg.activate($$project_path)
        end)
    end
end

function import_module_on_workers(procs, filename::String)
    included_local = !("SymbolicRegression" in [k.name for (k, v) in Base.loaded_modules])
    if included_local
        println("Importing local module ($filename) on workers.")
        @everywhere procs begin
            # Parse functions on every worker node
            Main.eval(quote
                include($$filename)
                using .SymbolicRegression
            end)
        end
    else
        println("Importing installed module on workers.")
        @everywhere procs begin
            Main.eval(using SymbolicRegression)
        end
    end
end

function test_module_on_workers(procs, options::Options)
    println("Testing module on workers")
    futures = []
    for proc in procs
        push!(futures,
              @spawnat proc genRandomTree(3, options, 5))
    end
    for future in futures
        fetch(future)
    end
end
