module PluginsModule

include("AdaptiveParsimony.jl")
include("AdaptiveMutationWeights.jl")
include("MutationBurst.jl")
include("SimulatedAnnealing.jl")

using .AdaptiveParsimonyModule: AdaptiveParsimonyPlugin
using .AdaptiveMutationWeightsModule: AdaptiveMutationWeightsPlugin
using .MutationBurstModule: MutationBurstPlugin
using .SimulatedAnnealingModule: SimulatedAnnealingPlugin

end
