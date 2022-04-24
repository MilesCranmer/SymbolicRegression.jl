module OptionsStructModule

using LossFunctions

struct Options{A,B,dA,dB,C<:Union{SupervisedLoss,Function}}

    binops::A
    unaops::B
    diff_binops::dA
    diff_unaops::dB
    bin_constraints::Vector{Tuple{Int,Int}}
    una_constraints::Vector{Int}
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
    useFrequencyInTournament::Bool
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
    enable_autodiff::Bool
    nested_constraints::Union{Dict{Function, Dict{Function, Int64}},Nothing}

end

Base.print(io::IO, options::Options) = print(io, """Options(
# Operators:
    binops=$(options.binops), unaops=$(options.unaops),
# Loss:
    loss=$(options.loss),
# Complexity Management:
    maxsize=$(options.maxsize), maxdepth=$(options.maxdepth), bin_constraints=$(options.bin_constraints), una_constraints=$(options.una_constraints), useFrequency=$(options.useFrequency), useFrequencyInTournament=$(options.useFrequencyInTournament), parsimony=$(options.parsimony), warmupMaxsizeBy=$(options.warmupMaxsizeBy), 
# Search Size:
    npopulations=$(options.npopulations), ncyclesperiteration=$(options.ncyclesperiteration), npop=$(options.npop), 
# Migration:
    migration=$(options.migration), hofMigration=$(options.hofMigration), fractionReplaced=$(options.fractionReplaced), fractionReplacedHof=$(options.fractionReplacedHof),
# Tournaments:
    probPickFirst=$(options.probPickFirst), ns=$(options.ns), topn=$(options.topn), 
# Constant tuning:
    perturbationFactor=$(options.perturbationFactor), probNegate=$(options.probNegate), shouldOptimizeConstants=$(options.shouldOptimizeConstants), optimizer_algorithm=$(options.optimizer_algorithm), optimize_probability=$(options.optimize_probability), optimizer_nrestarts=$(options.optimizer_nrestarts), optimizer_iterations=$(options.optimizer_iterations),
# Mutations:
    mutationWeights=$(options.mutationWeights), crossoverProbability=$(options.crossoverProbability), skip_mutation_failures=$(options.skip_mutation_failures)
# Annealing:
    annealing=$(options.annealing), alpha=$(options.alpha), 
# Speed Tweaks:
    batching=$(options.batching), batchSize=$(options.batchSize), fast_cycle=$(options.fast_cycle), 
# Logistics:
    hofFile=$(options.hofFile), verbosity=$(options.verbosity), seed=$(options.seed), progress=$(options.progress), use_symbolic_utils=$(options.use_symbolic_utils),
# Early Exit:
    earlyStopCondition=$(options.earlyStopCondition), timeout_in_seconds=$(options.timeout_in_seconds),
)""")
Base.show(io::IO, options::Options) = Base.print(io, options)

end
