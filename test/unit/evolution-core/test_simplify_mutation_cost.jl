@testitem "Simplify mutation updates cost with complexity" begin
    using SymbolicRegression
    using SymbolicRegression: Dataset, RecordType, MutationWeights
    using SymbolicRegression.LossFunctionsModule: loss_to_cost
    using SymbolicRegression.MutateModule: mutate!
    using Random: MersenneTwister

    options = Options(;
        binary_operators=(+, -, *), unary_operators=(), parsimony=0.5, should_simplify=true
    )
    @extend_operators options

    rng = MersenneTwister(0)
    X = randn(rng, 1, 64)
    y = vec(X[1, :])
    dataset = Dataset(X, y)

    x1 = Node{Float64}(; feature=1)
    tree = (x1 + 1.0) + 2.0
    member = PopMember(dataset, tree, options; deterministic=false)

    original_complexity = compute_complexity(member.tree, options)

    result = mutate!(
        copy(member.tree),
        member,
        Val(:simplify),
        MutationWeights(),
        options;
        recorder=RecordType(),
        dataset=dataset,
        parent_ref=1,
    )

    @test result.return_immediately
    @test result.member !== nothing
    simplified_member = result.member

    simplified_tree = simplified_member.tree
    simplified_complexity = compute_complexity(simplified_tree, options)
    @test simplified_complexity < original_complexity

    expected_original_cost = loss_to_cost(
        member.loss,
        dataset.use_baseline,
        dataset.baseline_loss,
        member.tree,
        options,
        original_complexity,
    )
    expected_simplified_cost = loss_to_cost(
        member.loss,
        dataset.use_baseline,
        dataset.baseline_loss,
        simplified_tree,
        options,
        simplified_complexity,
    )

    @test member.cost ≈ expected_original_cost
    @test simplified_member.cost ≈ expected_simplified_cost
    @test member.cost - simplified_member.cost ≈
        (original_complexity - simplified_complexity) * options.parsimony
end
