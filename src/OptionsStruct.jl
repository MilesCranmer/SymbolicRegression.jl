using LossFunctions

struct Options{A,B,C<:Union{SupervisedLoss,Function}}

    binops::A
    unaops::B
    bin_constraints::Array{Tuple{Int,Int}, 1}
    una_constraints::Array{Int, 1}
    ns::Int
    parsimony::Float32
    alpha::Float32
    maxsize::Int
    maxdepth::Int
    fast_cycle::Bool
    migration::Bool
    hofMigration::Bool
    fractionReplacedHof::Float32
    shouldOptimizeConstants::Bool
    hofFile::String
    npopulations::Int
    perturbationFactor::Float32
    annealing::Bool
    batching::Bool
    batchSize::Int
    mutationWeights::Array{Float64, 1}
    crossoverProbability::Float32
    warmupMaxsizeBy::Float32
    useFrequency::Bool
    npop::Int
    ncyclesperiteration::Int
    fractionReplaced::Float32
    topn::Int
    verbosity::Int
    probNegate::Float32
    nuna::Int
    nbin::Int
    seed::Union{Int, Nothing}
    loss::C
    progress::Bool
    terminal_width::Union{Int, Nothing}
    optimizer_algorithm::String
    optimize_probability::Float32
    optimizer_nrestarts::Int
    optimizer_iterations::Int
    recorder::Bool
    recorder_file::String
    probPickFirst::Float32
    earlyStopCondition::Union{Function, Nothing}
    stateReturn::Bool
    use_symbolic_utils::Bool
    timeout_in_seconds::Union{Float64, Nothing}
    skip_mutation_failures::Bool

end