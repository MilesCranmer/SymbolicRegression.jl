using SymbolicRegression: L2DistLoss, MutationWeights
using DynamicExpressions.OperatorEnumConstructionModule: empty_all_globals!
using Optim: Optim
using LineSearches: LineSearches
using Test: Test

ENV["SYMBOLIC_REGRESSION_IS_TESTING"] = "true"

empty_all_globals!()

const maximum_residual = 2e-2

if !@isdefined(custom_cos) || !hasmethod(custom_cos, (String,))
    @eval custom_cos(x) = cos(x)
end

const default_params = (
    binary_operators=(/, +, *),
    unary_operators=(exp, custom_cos),
    constraints=nothing,
    elementwise_loss=L2DistLoss(),
    tournament_selection_n=10,
    topn=10,
    parsimony=0.000100f0,
    alpha=0.100000f0,
    maxsize=20,
    maxdepth=nothing,
    fast_cycle=false,
    migration=true,
    hof_migration=true,
    fraction_replaced_hof=0.1f0,
    should_optimize_constants=true,
    perturbation_factor=1.000000f0,
    annealing=true,
    batching=false,
    batch_size=50,
    mutation_weights=MutationWeights(;
        mutate_constant=10.000000,
        mutate_operator=1.000000,
        add_node=1.000000,
        insert_node=3.000000,
        delete_node=3.000000,
        simplify=0.010000,
        randomize=1.000000,
        do_nothing=1.000000,
    ),
    crossover_probability=0.0f0,
    warmup_maxsize_by=0.0f0,
    use_frequency=false,
    population_size=1000,
    ncycles_per_iteration=300,
    fraction_replaced=0.1f0,
    verbosity=convert(Int, 1e9),
    probability_negate_constant=0.01f0,
    seed=nothing,
    bin_constraints=nothing,
    una_constraints=nothing,
    progress=false,
    terminal_width=nothing,
    optimizer_algorithm=Optim.NelderMead(; linesearch=LineSearches.BackTracking()),
    optimizer_nrestarts=3,
    optimizer_probability=0.1f0,
    optimizer_iterations=100,
    use_recorder=false,
    recorder_file="pysr_recorder.json",
    tournament_selection_p=1.0,
    early_stop_condition=nothing,
    timeout_in_seconds=nothing,
    skip_mutation_failures=false,
)

test_info(_, x) = error("Test failed: $x")
test_info(_, ::Test.Pass) = nothing
test_info(f::F, ::Test.Fail) where {F} = f()

macro quiet(ex)
    return quote
        redirect_stderr(devnull) do
            $ex
        end
    end |> esc
end
