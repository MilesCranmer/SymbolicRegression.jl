using Random: MersenneTwister

const TEST_TYPE = Float32

function test_operator(@nospecialize(op::Function), x::T, y=nothing) where {T}
    local output
    try
        output = y === nothing ? op(x) : op(x, y)
    catch e
        error(
            "The operator `$(op)` is not well-defined over the " *
            ((T <: Complex) ? "complex plane, " : "real line, ") *
            "as it threw the error `$(typeof(e))` when evaluating the " *
            (y === nothing ? "input $(x). " : "inputs $(x) and $(y). ") *
            "You can work around this by returning " *
            "NaN for invalid inputs. For example, " *
            "`safe_log(x::T) where {T} = x > 0 ? log(x) : T(NaN)`.",
        )
    end
    if !isa(output, T)
        error(
            "The operator `$(op)` returned an output of type `$(typeof(output))`, " *
            "when it was given " *
            (y === nothing ? "an input $(x) " : "inputs $(x) and $(y) ") *
            "of type `$(T)`. " *
            "Please ensure that your operators return the same type as their inputs.",
        )
    end
    return nothing
end
precompile(Tuple{typeof(test_operator),Function,Float64,Float64})
precompile(Tuple{typeof(test_operator),Function,Float32,Float32})
precompile(Tuple{typeof(test_operator),Function,Float64})
precompile(Tuple{typeof(test_operator),Function,Float32})

const TEST_INPUTS = collect(range(-100, 100; length=99))

function get_test_inputs(::Type{T}, ::AbstractOptions) where {T<:Number}
    return Base.Fix1(convert, T).(TEST_INPUTS)
end
function get_test_inputs(::Type{T}, ::AbstractOptions) where {T<:Complex}
    return Base.Fix1(convert, T).(TEST_INPUTS .+ TEST_INPUTS .* im)
end
function get_test_inputs(::Type{T}, options::AbstractOptions) where {T}
    rng = MersenneTwister(0)
    return [sample_value(rng, T, options) for _ in 1:100]
end

function assert_operators_well_defined(T, options::AbstractOptions)
    test_input = get_test_inputs(T, options)
    for x in test_input, y in test_input, op in options.operators.binops
        test_operator(op, x, y)
    end
    for x in test_input, op in options.operators.unaops
        test_operator(op, x)
    end
    return nothing
end

# Check for errors before they happen
function test_option_configuration(
    parallelism, datasets::Vector{D}, options::AbstractOptions, verbosity
) where {T,D<:Dataset{T}}
    if options.deterministic && parallelism != :serial
        error("Determinism is only guaranteed for serial mode.")
    end
    if parallelism == :multithreading && Threads.nthreads() == 1
        verbosity > 0 &&
            @warn "You are using multithreading mode, but only one thread is available. Try starting julia with `--threads=auto`."
    end
    if any(has_units, datasets) && options.dimensional_constraint_penalty === nothing
        verbosity > 0 &&
            @warn "You are using dimensional constraints, but `dimensional_constraint_penalty` was not set. The default penalty of `1000.0` will be used."
    end

    if any(is_anonymous_function, options.operators.binops) ||
        any(is_anonymous_function, options.operators.unaops)
        throw(
            AssertionError(
                "Anonymous functions can't be used as operators for SymbolicRegression.jl"
            ),
        )
    end

    assert_operators_well_defined(T, options)

    operator_intersection = intersect(options.operators.binops, options.operators.unaops)
    if length(operator_intersection) > 0
        throw(
            AssertionError(
                "Your configuration is invalid - $(operator_intersection) appear in both the binary operators and unary operators.",
            ),
        )
    end
    return nothing
end

# Check for errors before they happen
function test_dataset_configuration(
    dataset::Dataset{T}, options::AbstractOptions, verbosity
) where {T<:DATA_TYPE}
    n = dataset.n
    if n != size(dataset.X, 2) ||
        (dataset.y !== nothing && n != size(dataset.y::AbstractArray, 1))
        throw(
            AssertionError(
                "Dataset dimensions are invalid. Make sure X is of shape [features, rows], y is of shape [rows] and if there are weights, they are of shape [rows].",
            ),
        )
    end

    if size(dataset.X, 2) > 10000 && !options.batching && verbosity > 0
        @info "Note: you are running with more than 10,000 datapoints. You should consider turning on batching (`options.batching`), and also if you need that many datapoints. Unless you have a large amount of noise (in which case you should smooth your dataset first), generally < 10,000 datapoints is enough to find a functional form."
    end

    if !(typeof(options.elementwise_loss) <: SupervisedLoss) &&
        is_weighted(dataset) &&
        !(3 in [m.nargs - 1 for m in methods(options.elementwise_loss)])
        throw(
            AssertionError(
                "When you create a custom loss function, and are using weights, you need to define your loss function with three scalar arguments: f(prediction, target, weight).",
            ),
        )
    end
end

""" Move custom operators and loss functions to workers, if undefined """
function move_functions_to_workers(
    procs, options::AbstractOptions, dataset::Dataset{T}, verbosity
) where {T}
    # All the types of functions we need to move to workers:
    function_sets = (
        :unaops,
        :binops,
        :elementwise_loss,
        :early_stop_condition,
        :expression_type,
        :loss_function,
        :loss_function_expression,
        :complexity_mapping,
    )

    for function_set in function_sets
        if function_set == :unaops
            ops = options.operators.unaops
            example_inputs = (init_value(T),)
        elseif function_set == :binops
            ops = options.operators.binops
            example_inputs = (init_value(T), init_value(T))
        elseif function_set == :elementwise_loss
            if typeof(options.elementwise_loss) <: SupervisedLoss
                continue
            end
            ops = (options.elementwise_loss,)
            example_inputs = if is_weighted(dataset)
                (init_value(T), init_value(T), init_value(T))
            else
                (init_value(T), init_value(T))
            end
        elseif function_set == :early_stop_condition
            if !(typeof(options.early_stop_condition) <: Function)
                continue
            end
            ops = (options.early_stop_condition,)
            example_inputs = (zero(T), 0)
        elseif function_set == :expression_type
            # Needs to run _before_ using TemplateExpression anywhere, such
            # as in `loss_function_expression`!
            if isnothing(options.expression_type)
                continue
            end
            if !require_copy_to_workers(options.expression_type)
                continue
            end
            (; ops, example_inputs) = make_example_inputs(
                options.expression_type, T, options, dataset
            )
        elseif function_set == :loss_function
            if isnothing(options.loss_function)
                continue
            end
            ops = (options.loss_function,)
            example_inputs = ((options.node_type)(T; val=init_value(T)), dataset, options)
        elseif function_set == :loss_function_expression
            if isnothing(options.loss_function_expression)
                continue
            end
            ops = (options.loss_function_expression,)
            ex = create_expression(init_value(T), options, dataset)
            example_inputs = (ex, dataset, options)
        elseif function_set == :complexity_mapping
            if !(options.complexity_mapping isa Function)
                continue
            end
            ops = (options.complexity_mapping,)
            example_inputs = (create_expression(init_value(T), options, dataset),)
        else
            error("Invalid function set: $function_set")
        end
        for op in ops
            try
                test_function_on_workers(example_inputs, op, procs)
            catch e
                undefined_on_workers = isa(e.captured.ex, UndefVarError)
                if undefined_on_workers
                    copy_definition_to_workers(op, procs, options, verbosity)
                else
                    throw(e)
                end
            end
            test_function_on_workers(example_inputs, op, procs)
        end
    end
end

function copy_definition_to_workers(
    @nospecialize(op), procs, @nospecialize(options::AbstractOptions), verbosity
)
    name = nameof(op)
    verbosity > 0 && @info "Copying definition of $op to workers..."
    src_ms = methods(op).ms
    # Thanks https://discourse.julialang.org/t/easy-way-to-send-custom-function-to-distributed-workers/22118/2
    @everywhere procs @eval function $name end
    for m in src_ms
        @everywhere procs @eval $m
    end
    verbosity > 0 && @info "Finished!"
    return nothing
end

function test_function_on_workers(example_inputs, op, procs)
    futures = []
    for proc in procs
        push!(futures, @spawnat proc op(example_inputs...))
    end
    for future in futures
        fetch(future)
    end
end

function activate_env_on_workers(
    procs, project_path::String, @nospecialize(options::AbstractOptions), verbosity
)
    verbosity > 0 && @info "Activating environment on workers."
    @everywhere procs begin
        Base.MainInclude.eval(
            quote
                using Pkg
                Pkg.activate($$project_path)
            end,
        )
    end
end

function import_module_on_workers(
    procs,
    filename::String,
    @nospecialize(worker_imports::Union{Vector{Symbol},Nothing}),
    verbosity,
)
    loaded_modules_head_worker = [k.name for (k, _) in Base.loaded_modules]

    included_as_local = "SymbolicRegression" ∉ loaded_modules_head_worker
    expr = if included_as_local
        quote
            include($filename)
            using .SymbolicRegression
        end
    else
        quote
            using SymbolicRegression
        end
    end

    # Need to import any extension code, if loaded on head node
    relevant_extensions = [
        :Bumper,
        :CUDA,
        :ClusterManagers,
        :Enzyme,
        :LoopVectorization,
        :Mooncake,
        :SymbolicUtils,
        :TensorBoardLogger,
        :Zygote,
    ]
    filter!(m -> String(m) ∈ loaded_modules_head_worker, relevant_extensions)
    # HACK TODO – this workaround is very fragile. Likely need to submit a bug report
    #             to JuliaLang.

    all_extensions = vcat(relevant_extensions, @something(worker_imports, Symbol[]))

    for ext in all_extensions
        push!(
            expr.args,
            quote
                using $ext: $ext
            end,
        )
    end

    verbosity > 0 && if isempty(relevant_extensions)
        @info "Importing SymbolicRegression on workers."
    else
        @info "Importing SymbolicRegression on workers as well as extensions $(join(relevant_extensions, ',' * ' '))."
    end
    @everywhere procs Core.eval(Core.Main, $expr)
    verbosity > 0 && @info "Finished!"
    return nothing
end

function test_module_on_workers(procs, options::AbstractOptions, verbosity)
    verbosity > 0 && @info "Testing module on workers..."
    futures = []
    for proc in procs
        push!(
            futures,
            @spawnat proc SymbolicRegression.gen_random_tree(3, options, 5, TEST_TYPE)
        )
    end
    for future in futures
        fetch(future)
    end
    verbosity > 0 && @info "Finished!"
    return nothing
end

function test_entire_pipeline(
    procs, dataset::Dataset{T}, options::AbstractOptions, verbosity
) where {T<:DATA_TYPE}
    futures = []
    verbosity > 0 && @info "Testing entire pipeline on workers..."
    for proc in procs
        push!(
            futures,
            @spawnat proc begin
                tmp_pop = Population(
                    dataset;
                    population_size=20,
                    nlength=3,
                    options=options,
                    nfeatures=max_features(dataset, options),
                )
                tmp_pop = s_r_cycle(
                    dataset,
                    tmp_pop,
                    5,
                    5,
                    RunningSearchStatistics(; options=options);
                    verbosity=verbosity,
                    options=options,
                    record=RecordType(),
                )[1]
                tmp_pop = optimize_and_simplify_population(
                    dataset, tmp_pop, options, options.maxsize, RecordType()
                )
            end
        )
    end
    for future in futures
        fetch(future)
    end
    verbosity > 0 && @info "Finished!"
    return nothing
end

function configure_workers(;
    procs::Union{Vector{Int},Nothing},
    numprocs::Int,
    addprocs_function::Function,
    worker_timeout::Float64,
    options::AbstractOptions,
    @nospecialize(worker_imports::Union{Vector{Symbol},Nothing}),
    project_path,
    file,
    exeflags::Cmd,
    verbosity,
    example_dataset::Dataset,
    runtests::Bool,
)
    (procs, we_created_procs) = if procs === nothing
        withenv("JULIA_WORKER_TIMEOUT" => string(worker_timeout)) do
            (addprocs_function(numprocs; lazy=false, exeflags), true)
        end
    else
        (procs, false)
    end

    if we_created_procs
        import_module_on_workers(procs, file, worker_imports, verbosity)
    end

    move_functions_to_workers(procs, options, example_dataset, verbosity)

    if runtests
        test_module_on_workers(procs, options, verbosity)
        test_entire_pipeline(procs, example_dataset, options, verbosity)
    end

    return (procs, we_created_procs)
end
