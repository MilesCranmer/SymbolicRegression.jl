@testitem "Custom AbstractPopMember implementation" tags = [:part1] begin
    using SymbolicRegression
    using DynamicExpressions
    using Test

    import SymbolicRegression.PopMemberModule: create_child

    # Define a custom PopMember that tracks generation count
    mutable struct CustomPopMember{T,L,N} <: SymbolicRegression.AbstractPopMember{T,L,N}
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

    DynamicExpressions.constructorof(::Type{<:CustomPopMember}) = CustomPopMember

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
        parent_ref,
        kwargs...,
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
        parent_ref,
        kwargs...,
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

    # Test that we can run equation_search with CustomPopMember
    X = randn(Float32, 2, 100)
    y = @. X[1, :]^2 - X[2, :]

    options = SymbolicRegression.Options(;
        binary_operators=[+, -],
        populations=1,
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
end
