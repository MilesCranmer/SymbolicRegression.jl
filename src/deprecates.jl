using Base: @deprecate

@deprecate(
    calculate_pareto_frontier(X, y, hallOfFame, options; weights=nothing, varMap=nothing),
    calculate_pareto_frontier(hallOfFame)
)
@deprecate(
    calculate_pareto_frontier(dataset, hallOfFame, options),
    calculate_pareto_frontier(hallOfFame)
)

@deprecate(
    EquationSearch(X::AbstractMatrix{T1}, y::AbstractMatrix{T2}; kw...) where {T1,T2},
    equation_search(X, y; kw...)
)

@deprecate(
    EquationSearch(X::AbstractMatrix{T1}, y::AbstractVector{T2}; kw...) where {T1,T2},
    equation_search(X, y; kw...)
)

@deprecate(EquationSearch(dataset::Dataset; kws...), equation_search(dataset; kws...),)

@deprecate(
    EquationSearch(
        X::AbstractMatrix{T},
        y::AbstractMatrix{T};
        niterations::Int=10,
        weights::Union{AbstractMatrix{T},AbstractVector{T},Nothing}=nothing,
        variable_names::Union{Vector{String},Nothing}=nothing,
        options::Options=Options(),
        parallelism=:multithreading,
        numprocs::Union{Int,Nothing}=nothing,
        procs::Union{Vector{Int},Nothing}=nothing,
        addprocs_function::Union{Function,Nothing}=nothing,
        runtests::Bool=true,
        saved_state=nothing,
        loss_type::Type=Nothing,
        # Deprecated:
        multithreaded=nothing,
        varMap=nothing,
    ) where {T<:DATA_TYPE},
    equation_search(
        X,
        y;
        niterations,
        weights,
        variable_names,
        options,
        parallelism,
        numprocs,
        procs,
        addprocs_function,
        runtests,
        saved_state,
        loss_type,
        multithreaded,
        varMap,
    )
)

@deprecate(
    EquationSearch(
        datasets::Vector{D};
        niterations::Int=10,
        options::Options=Options(),
        parallelism=:multithreading,
        numprocs::Union{Int,Nothing}=nothing,
        procs::Union{Vector{Int},Nothing}=nothing,
        addprocs_function::Union{Function,Nothing}=nothing,
        runtests::Bool=true,
        saved_state=nothing,
    ) where {T<:DATA_TYPE,L<:LOSS_TYPE,D<:Dataset{T,L}},
    equation_search(
        datasets;
        niterations,
        options,
        parallelism,
        numprocs,
        procs,
        addprocs_function,
        runtests,
        saved_state,
    )
)
