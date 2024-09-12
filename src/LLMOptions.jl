module LLMOptionsModule

using StatsBase: StatsBase
using Base: isvalid

"""
    LLMWeights(;kws...)

Defines the probability of different LLM-based mutation operations. Follows the same
pattern as MutationWeights. These weights will be normalized to sum to 1.0 after initialization.
# Arguments
- `llm_mutate::Float64`: Probability of calling LLM version of mutation.
   The LLM operations are significantly slower than their symbolic counterparts,
   so higher probabilities will result in slower operations.
- `llm_crossover::Float64`: Probability of calling LLM version of crossover.
    Same limitation as llm_mutate.
- `llm_gen_random::Float64`: Probability of calling LLM version of gen_random.
    Same limitation as llm_mutate.
"""
Base.@kwdef mutable struct LLMWeights
    llm_mutate::Float64 = 0.0
    llm_crossover::Float64 = 0.0
    llm_gen_random::Float64 = 0.0
end

"""
    LLMOptions(;kws...)

This defines how to call the LLM inference functions. LLM inference is managed by PromptingTools.jl but
this module serves as the entry point to define new options for the LLM inference.
# Arguments
- `active::Bool`: Whether to use LLM inference or not.
- `weights::LLMWeights`: Weights for different LLM operations.
- `num_pareto_context::Int64`: Number of equations to sample from pareto frontier.
- `prompt_concepts::Bool`: Use natural language concepts in the LLM prompts. 
- `prompt_evol::Bool`: Evolve natural language concepts through succesive LLM
    calls.
- api_key::String: OpenAI API key. Required.
- model::String: OpenAI model to use. Required.
- api_kwargs::Dict: Additional keyword arguments to pass to the OpenAI API.
    - url::String: URL to send the request to. Required.
    - max_tokens::Int: Maximum number of tokens to generate. (default: 1000)
- http_kwargs::Dict: Additional keyword arguments for the HTTP request.
    - retries::Int: Number of retries to attempt. (default: 3)
    - readtimeout::Int: Read timeout for the HTTP request (in seconds; default is 1 hour).
- `llm_recorder_dir::String`: File to save LLM logs to. Useful for debugging.
- `llm_context::AbstractString`: Context string for LLM.
- `var_order::Union{Dict,Nothing}`: Variable order for LLM. (default: nothing)
"""
Base.@kwdef mutable struct LLMOptions
    active::Bool = false
    weights::LLMWeights = LLMWeights()
    num_pareto_context::Int64 = 0
    prompt_concepts::Bool = false
    prompt_evol::Bool = false
    api_key::String = ""
    model::String = ""
    api_kwargs::Dict = Dict(
        "max_tokens" => 1000
    )
    http_kwargs::Dict = Dict("retries" => 3, "readtimeout" => 3600)
    llm_recorder_dir::String = "lasr_runs/"
    prompts_dir::String = "prompts/"
    llm_context::AbstractString = ""
    var_order::Union{Dict,Nothing} = nothing
    idea_threshold::UInt32 = 30
    is_parametric::Bool = false
end

const llm_mutations = fieldnames(LLMWeights)
const v_llm_mutations = Symbol[llm_mutations...]

# Validate some options are set correctly.
"""Validate some options are set correctly.
Specifically, need to check
- If `active` is true, then `api_key` and `model` must be set.
- If `active` is true, then `api_kwargs` must have a `url` key and it must be a valid URL.
- If `active` is true, then `llm_recorder_dir` must be a valid directory.
"""
function validate_llm_options(options::LLMOptions)
    if options.active
        if options.api_key == ""
            throw(ArgumentError("api_key must be set if LLM is active."))
        end
        if options.model == ""
            throw(ArgumentError("model must be set if LLM is active."))
        end
        if !haskey(options.api_kwargs, "url")
            throw(ArgumentError("api_kwargs must have a 'url' key."))
        end
        if !isdir(options.prompts_dir)
            throw(ArgumentError("prompts_dir must be a valid directory."))
        end
    end
end



# """Sample LLM mutation, given the weightings."""
# function sample_llm_mutation(w::LLMWeights)
#     weights = convert(Vector, w)
#     return StatsBase.sample(v_llm, StatsBase.Weights(weights))
# end

end # module



# sample invocation following:
# python -m experiments.main --use_llm --use_prompt_evol --model "meta-llama/Meta-Llama-3-8B-Instruct" --api_key "vllm_api.key" --model_url "http://localhost:11440/v1" --exp_idx 0 --dataset_path FeynmanEquations.csv  --start_idx 0
# options = LLMOptions(
#     active=true,
#     weights=LLMWeights(llm_mutate=0.5, llm_crossover=0.3, llm_gen_random=0.2),
#     num_pareto_context=5,
#     prompt_evol=true,
#     prompt_concepts=true,
#     api_key="vllm_api.key",
#     model="meta-llama/Meta-Llama-3-8B-Instruct",
#     api_kwargs=Dict("url" => "http://localhost:11440/v1"),
#     http_kwargs=Dict("retries" => 3, "readtimeout" => 3600),
#     llm_recorder_dir="lasr_runs/",
#     llm_context="",
#     var_order=nothing,
#     idea_threshold=30
# )