println("Testing whether tournament_selection_p works.")
using SymbolicRegression
using DynamicExpressions: with_type_parameters, @parse_expression
using Test
include("test_params.jl")

n = 10

options = Options(;
    default_params...,
    binary_operators=(+, -, *, /),
    unary_operators=(cos, sin),
    tournament_selection_p=0.999,
    tournament_selection_n=n,
)

for reverse in [false, true]
    T = Float32

    # Generate members with scores from 0 to 1:
    members = [
        let
            ex = @parse_expression(
                x1 * 3.2, operators = options.operators, variable_names = [:x1],
            )
            cost = Float32(i - 1) / (n - 1)
            if reverse
                cost = 1 - cost
            end
            test_loss = 1.0f0  # (arbitrary for this test)
            PopMember(ex, cost, test_loss, options; deterministic=false)
        end for i in 1:n
    ]

    pop = Population(members)

    dummy_running_stats = SymbolicRegression.AdaptiveParsimonyModule.RunningSearchStatistics(;
        options=options
    )
    best_pop_member = [
        SymbolicRegression.best_of_sample(pop, dummy_running_stats, options).cost for
        j in 1:100
    ]

    mean_value = sum(best_pop_member) / length(best_pop_member)

    # Make sure average cost is small
    @test mean_value < 0.1
end

println("Passed.")
