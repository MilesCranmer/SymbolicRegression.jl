using LaSR: LLMOptions, Options

# test that we can partially specify LLMOptions
op1 = LLMOptions(active=false)
@test op1.active == false

# test that we can fully specify LLMOptions
op2 =  LLMOptions(
    active=true,
    weights=LLMWeights(llm_mutate=0.5, llm_crossover=0.3, llm_gen_random=0.2),
    num_pareto_context=5,
    prompt_evol=true,
    prompt_concepts=true,
    api_key="vllm_api.key",
    model="modelx",
    api_kwargs=Dict("url" => "http://localhost:11440/v1"),
    http_kwargs=Dict("retries" => 3, "readtimeout" => 3600),
    llm_recorder_dir="test/",
    llm_context="test",
    var_order=nothing,
    idea_threshold=30
)
@test op2.active == true

# test that we can pass LLMOptions to Options
llm_opt = LLMOptions(active=false)
op = Options(; optimizer_options=(iterations=16, f_calls_limit=100, x_tol=1e-16), llm_options=llm_opt)
@test isa(op.llm_options, LLMOptions)
println("Passed.")
