@testitem "Custom crossover dispatch" begin
    using SymbolicRegression
    using SymbolicRegression: Dataset, CrossoverResult, crossover
    using SymbolicRegression.EvolutionModule.CrossoverModule: crossover_generation
    using Random: seed!

    struct CountingCrossover <: AbstractCrossover
        calls::Base.RefValue{Int}
    end

    function SymbolicRegression.crossover(
        member1, member2, c::CountingCrossover, options; kws...
    )
        c.calls[] += 1
        N = typeof(member1.tree)
        return CrossoverResult{N}(; child1=copy(member1.tree), child2=copy(member2.tree))
    end

    calls = Ref(0)
    options = Options(;
        binary_operators=(+, *),
        default_crossovers=(),
        crossovers=(CountingCrossover(calls) => 1.0,),
    )
    @test length(options.crossovers) == 1
    dataset = Dataset(randn(2, 16), randn(16))
    member1 = PopMember(dataset, Node(Float64; feature=1), options; deterministic=false)
    member2 = PopMember(dataset, Node(Float64; feature=2), options; deterministic=false)

    baby1, baby2, accepted, num_evals = crossover_generation(
        member1, member2, dataset, options.maxsize, options
    )
    @test calls[] == 1
    @test accepted
    @test num_evals == 2.0

    struct MissingCrossover <: AbstractCrossover end
    @test_throws ErrorException crossover(member1, member2, MissingCrossover(), options)
end

@testitem "Crossover retries and giving up" begin
    using SymbolicRegression
    using SymbolicRegression: Dataset, CrossoverResult, with_contents
    using SymbolicRegression.EvolutionModule.CrossoverModule: crossover_generation

    # A child exceeding curmaxsize always fails the constraint check:
    function oversized_child(member, options, curmaxsize)
        big = Node(Float64; feature=1)
        tree = with_contents(member.tree, big)
        while compute_complexity(tree, options) <= curmaxsize
            big = Node(; op=1, l=big, r=Node(Float64; feature=1))
            tree = with_contents(member.tree, big)
        end
        return tree
    end

    struct FailingCrossover <: AbstractCrossover
        attempts::Vector{Int}
    end

    function SymbolicRegression.crossover(
        member1, member2, c::FailingCrossover, options; attempt, curmaxsize, kws...
    )
        push!(c.attempts, attempt)
        big = oversized_child(member1, options, curmaxsize)
        N = typeof(big)
        return CrossoverResult{N}(; child1=copy(big), child2=copy(big))
    end

    struct GiveUpCrossover <: AbstractCrossover
        attempts::Vector{Int}
    end

    function SymbolicRegression.crossover(
        member1, member2, c::GiveUpCrossover, options; attempt, curmaxsize, kws...
    )
        push!(c.attempts, attempt)
        if attempt > 1
            # Expensive crossovers can stop retrying by returning the
            # parents' trees unchanged:
            N = typeof(member1.tree)
            return CrossoverResult{N}(;
                child1=copy(member1.tree), child2=copy(member2.tree)
            )
        end
        big = oversized_child(member1, options, curmaxsize)
        N = typeof(big)
        return CrossoverResult{N}(; child1=copy(big), child2=copy(big))
    end

    options = Options(;
        binary_operators=(+, *),
        default_crossovers=(),
        crossovers=(FailingCrossover(Int[]) => 1.0,),
    )
    dataset = Dataset(randn(2, 16), randn(16))
    member1 = PopMember(dataset, Node(Float64; feature=1), options; deterministic=false)
    member2 = PopMember(dataset, Node(Float64; feature=2), options; deterministic=false)

    op = only(options.crossovers).first
    baby1, baby2, accepted, num_evals = crossover_generation(
        member1, member2, dataset, 5, options
    )
    @test !accepted
    @test baby1 === member1 && baby2 === member2
    @test num_evals == 0.0
    @test op.attempts == collect(1:10)

    give_up = GiveUpCrossover(Int[])
    options2 = Options(;
        binary_operators=(+, *), default_crossovers=(), crossovers=(give_up => 1.0,)
    )
    baby1, baby2, accepted, _ = crossover_generation(member1, member2, dataset, 5, options2)
    @test accepted
    @test give_up.attempts == [1, 2]
    @test string(baby1.tree) == string(member1.tree)
    @test string(baby2.tree) == string(member2.tree)
end

@testitem "Crossover weighted sampling and Options merge" begin
    using SymbolicRegression
    using SymbolicRegression: Dataset, CrossoverResult
    using SymbolicRegression.EvolutionModule.CrossoverModule: crossover_generation

    struct TracingCrossover <: AbstractCrossover
        calls::Base.RefValue{Int}
    end

    function SymbolicRegression.crossover(
        member1, member2, c::TracingCrossover, options; kws...
    )
        c.calls[] += 1
        N = typeof(member1.tree)
        return CrossoverResult{N}(; child1=copy(member1.tree), child2=copy(member2.tree))
    end

    # Zero-weight entries are never sampled:
    active = Ref(0)
    inactive = Ref(0)
    options = Options(;
        binary_operators=(+, *),
        default_crossovers=(),
        crossovers=(TracingCrossover(active) => 1.0, TracingCrossover(inactive) => 0.0),
    )
    dataset = Dataset(randn(2, 16), randn(16))
    member1 = PopMember(dataset, Node(Float64; feature=1), options; deterministic=false)
    member2 = PopMember(dataset, Node(Float64; feature=2), options; deterministic=false)
    for _ in 1:10
        crossover_generation(member1, member2, dataset, options.maxsize, options)
    end
    @test active[] == 10
    @test inactive[] == 0

    # Default is a single SubtreeCrossover:
    default_options = Options(; binary_operators=(+, *))
    @test length(default_options.crossovers) == 1
    @test only(default_options.crossovers) == (SubtreeCrossover() => 1.0)

    # An explicit entry replaces the default of the same type:
    merged = Options(; binary_operators=(+, *), crossovers=(SubtreeCrossover() => 0.5,))
    @test only(merged.crossovers) == (SubtreeCrossover() => 0.5)

    # A new type is added alongside the defaults:
    extended = Options(;
        binary_operators=(+, *), crossovers=(TracingCrossover(Ref(0)) => 0.5,)
    )
    @test length(extended.crossovers) == 2
    @test any(pair -> pair.first isa SubtreeCrossover, extended.crossovers)
end

@testitem "Default crossover matches crossover_trees" begin
    using SymbolicRegression
    using SymbolicRegression: Dataset, crossover_trees
    using SymbolicRegression.EvolutionModule.CrossoverModule: crossover_generation
    using Random: seed!

    options = Options(; binary_operators=(+, *), unary_operators=(cos,))
    dataset = Dataset(randn(2, 16), randn(16))
    tree1 = cos(Node(Float64; feature=1)) + Node(Float64; feature=2)
    tree2 = Node(Float64; feature=1) * Node(Float64; feature=2)
    ex1 = Expression(tree1; operators=options.operators, variable_names=["x1", "x2"])
    ex2 = Expression(tree2; operators=options.operators, variable_names=["x1", "x2"])
    member1 = PopMember(dataset, ex1, options; deterministic=false)
    member2 = PopMember(dataset, ex2, options; deterministic=false)

    # The single-operator default consumes no extra RNG draws relative to
    # calling crossover_trees directly:
    seed!(17)
    baby1, baby2, accepted, _ = crossover_generation(
        member1, member2, dataset, options.maxsize, options
    )
    @test accepted
    seed!(17)
    child1, child2 = crossover_trees(member1.tree, member2.tree)
    @test string(baby1.tree) == string(child1)
    @test string(baby2.tree) == string(child2)
end
