@testitem "Custom AbstractPopMember implementation" tags = [:part1] begin
    using SymbolicRegression
    using DynamicExpressions
    using Test
    using DispatchDoctor: @unstable

    import SymbolicRegression.PopMemberModule: create_child
    import SymbolicRegression: strip_metadata

    # Define a custom PopMember that tracks generation count
    mutable struct CustomPopMember{T,L,N<:AbstractExpression{T}} <:
                   SymbolicRegression.AbstractPopMember{T,L,N}
        tree::N
        cost::L
        loss::L
        birth::Int
        complexity::Int
        ref::Int
        parent::Int
        generation::Int  # Custom field to track generation
    end

    # # Direct constructor that matches field order
    function CustomPopMember(
        tree::N,
        cost::L,
        loss::L,
        birth::Int,
        complexity::Int,
        ref::Int,
        parent::Int,
        generation::Int,
    ) where {T,L,N<:AbstractExpression{T}}
        return CustomPopMember{T,L,N}(
            tree, cost, loss, birth, complexity, ref, parent, generation
        )
    end

    function CustomPopMember(
        tree::N,
        cost::L,
        loss::L,
        options,
        complexity::Int;
        parent=-1,
        deterministic=nothing,
    ) where {T,L,N<:AbstractExpression{T}}
        return CustomPopMember(
            tree,
            cost,
            loss,
            SymbolicRegression.get_birth_order(; deterministic=deterministic),
            complexity,
            abs(rand(Int)),
            parent,
            0,  # Initial generation
        )
    end

    # Constructor for Population initialization (dataset, tree, options)
    function CustomPopMember(
        dataset::SymbolicRegression.Dataset, tree, options; parent=-1, deterministic=nothing
    )
        ex = SymbolicRegression.create_expression(tree, options, dataset)
        complexity = SymbolicRegression.compute_complexity(ex, options)
        cost, loss = SymbolicRegression.eval_cost(
            dataset, ex, options; complexity=complexity
        )

        return CustomPopMember(
            ex,
            cost,
            loss,
            SymbolicRegression.get_birth_order(; deterministic=deterministic),
            complexity,
            abs(rand(Int)),
            parent,
            0,  # Initial generation
        )
    end

    @unstable DynamicExpressions.constructorof(::Type{<:CustomPopMember}) = CustomPopMember

    # Define with_type_parameters for CustomPopMember
    @unstable function DynamicExpressions.with_type_parameters(
        ::Type{<:CustomPopMember}, ::Type{T}, ::Type{L}, ::Type{N}
    ) where {T,L,N}
        return CustomPopMember{T,L,N}
    end

    # Define copy for CustomPopMember
    function Base.copy(p::CustomPopMember)
        return CustomPopMember(
            copy(p.tree),
            copy(p.cost),
            copy(p.loss),
            copy(p.birth),
            copy(getfield(p, :complexity)),
            copy(p.ref),
            copy(p.parent),
            copy(p.generation),
        )
    end

    function create_child(
        parent::CustomPopMember{T,L},
        tree::AbstractExpression{T},
        cost::L,
        loss::L,
        options;
        complexity::Union{Int,Nothing}=nothing,
        mutation_choice::Union{Symbol,Nothing}=nothing,
        parent_ref,
    ) where {T,L}
        actual_complexity = @something complexity SymbolicRegression.compute_complexity(
            tree, options
        )
        return CustomPopMember(
            tree,
            cost,
            loss,
            SymbolicRegression.get_birth_order(; deterministic=options.deterministic),
            actual_complexity,
            abs(rand(Int)),
            parent_ref,
            parent.generation + 1,
        )
    end

    function create_child(
        parents::Tuple{<:CustomPopMember,<:CustomPopMember},
        tree::N,
        cost::L,
        loss::L,
        options;
        complexity::Union{Int,Nothing}=nothing,
        mutation_choice::Union{Symbol,Nothing}=nothing,
        parent_ref,
    ) where {T,L,N<:AbstractExpression{T}}
        actual_complexity = @something complexity SymbolicRegression.compute_complexity(
            tree, options
        )
        max_generation = max(parents[1].generation, parents[2].generation)
        return CustomPopMember(
            tree,
            cost,
            loss,
            SymbolicRegression.CoreModule.UtilsModule.get_birth_order(;
                deterministic=options.deterministic
            ),
            actual_complexity,
            abs(rand(Int)),
            parent_ref,
            max_generation + 1,
        )
    end

    function strip_metadata(
        member::CustomPopMember,
        options::SymbolicRegression.AbstractOptions,
        dataset::SymbolicRegression.Dataset{T,L},
    ) where {T,L}
        complexity = SymbolicRegression.compute_complexity(member.tree, options)
        return CustomPopMember(
            strip_metadata(member.tree, options, dataset),
            member.cost,
            member.loss,
            SymbolicRegression.get_birth_order(; deterministic=options.deterministic),
            complexity,
            member.ref,
            member.parent,
            member.generation,
        )
    end

    # Test that we can run equation_search with CustomPopMember
    X = randn(Float32, 2, 100)
    y = @. X[1, :]^2 - X[2, :]

    options = SymbolicRegression.Options(;
        binary_operators=[+, -],
        populations=2,
        population_size=20,
        maxsize=5,
        popmember_type=CustomPopMember,
        deterministic=true,
        seed=0,
    )

    # Test that options were created with correct type
    @test options.popmember_type == CustomPopMember

    hall_of_fame = equation_search(
        X, y; options=options, niterations=2, parallelism=:serial
    )

    # Verify that we got results
    @test sum(hall_of_fame.exists) > 0

    # Verify that the members are CustomPopMember
    for i in eachindex(hall_of_fame.members, hall_of_fame.exists)
        if hall_of_fame.exists[i]
            @test hall_of_fame.members[i] isa CustomPopMember
            # Check that generation field exists
            @test hall_of_fame.members[i].generation >= 0
        end
    end

    # Verify we can extract the best member
    best_idx = findlast(hall_of_fame.exists)
    @test !isnothing(best_idx)
    best_member = hall_of_fame.members[best_idx]
    @test best_member isa CustomPopMember

    # Test that guesses API returns CustomPopMember instances
    guess_X = randn(Float32, 2, 80)
    guess_y = @. guess_X[1, :] - guess_X[2, :]
    guess_dataset = SymbolicRegression.Dataset(guess_X, guess_y)

    guess_options = SymbolicRegression.Options(;
        binary_operators=[+, -],
        populations=1,
        population_size=5,
        tournament_selection_n=2,
        maxsize=4,
        popmember_type=CustomPopMember,
        deterministic=true,
        seed=1,
        verbosity=0,
        progress=false,
    )

    parsed = SymbolicRegression.parse_guesses(
        CustomPopMember{Float32,Float32}, ["x1 - x2"], [guess_dataset], guess_options
    )

    @test length(parsed) == 1
    @test length(parsed[1]) == 1
    parsed_member = parsed[1][1]
    @test parsed_member isa CustomPopMember{Float32,Float32}
    @test isapprox(parsed_member.loss, 0.0f0; atol=1.0f-6)

    # Confirm equation_search accepts guesses with CustomPopMember
    hof_from_guess = equation_search(
        guess_X,
        guess_y;
        options=guess_options,
        guesses=["x1 - x2"],
        niterations=0,
        parallelism=:serial,
    )

    @test sum(hof_from_guess.exists) > 0
    guess_best_idx = findlast(hof_from_guess.exists)
    @test !isnothing(guess_best_idx)
    @test hof_from_guess.members[guess_best_idx] isa CustomPopMember
end
