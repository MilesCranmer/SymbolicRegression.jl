@testitem "template expression parameter mutation" begin
    using SymbolicRegression
    using SymbolicRegression: condition_mutation_weights!
    using SymbolicRegression.EvolutionModule.MutationFunctionsModule: mutate_constant
    using Random: MersenneTwister
    using DynamicExpressions: get_metadata

    # Create a template structure with parameters
    struct_with_params = TemplateStructure{(:f, :g),(:p1, :p2)}(
        ((; f, g), (; p1, p2), (x1, x2, x3)) -> f(x1, x2) * p1[1] + g(x3) * p2[1];
        num_parameters=(; p1=2, p2=3),  # p1 has 2 params, p2 has 3 params
    )

    # Set up options with the template spec
    options = Options(;
        binary_operators=(+, *, /, -),
        unary_operators=(sin, cos),
        expression_spec=TemplateExpressionSpec(; structure=struct_with_params),
    )
    operators = options.operators
    variable_names = ["x1", "x2", "x3"]

    # Create base expressions
    x1 = ComposableExpression(Node{Float64}(; feature=1); operators, variable_names)
    x2 = ComposableExpression(Node{Float64}(; feature=2); operators, variable_names)

    # Create template expression with parameters
    expr = TemplateExpression(
        (; f=x1, g=x2);
        structure=struct_with_params,
        operators=operators,
        parameters=(; p1=[1.0, 2.0], p2=[3.0, 4.0, 5.0]),
    )

    # Test mutation
    rng = MersenneTwister(0)
    temperature = 1.0

    # Store original parameter values
    original_p1 = copy(get_metadata(expr).parameters.p1._data)
    original_p2 = copy(get_metadata(expr).parameters.p2._data)

    # Test multiple mutations to ensure both parameter vectors can be mutated
    param_changed = [false, false]
    for _ in 1:50  # Run enough times to ensure we hit both parameter vectors
        mutated_expr = mutate_constant(
            copy(expr), temperature, options, ConstantMutation(), rng
        )
        new_p1 = get_metadata(mutated_expr).parameters.p1._data
        new_p2 = get_metadata(mutated_expr).parameters.p2._data

        if !all(new_p1 .≈ original_p1)
            param_changed[1] = true
        end
        if !all(new_p2 .≈ original_p2)
            param_changed[2] = true
        end
        if all(param_changed)
            break
        end
    end

    # Verify both parameter vectors were mutated at some point
    @test all(param_changed)

    # Test single mutation to verify mutation behavior
    mutated_expr = mutate_constant(
        copy(expr), temperature, options, ConstantMutation(), rng
    )

    # Get the mutated parameters
    new_p1 = get_metadata(mutated_expr).parameters.p1._data
    new_p2 = get_metadata(mutated_expr).parameters.p2._data

    # Verify exactly one parameter was changed
    @test any(new_p1 .!= original_p1) ⊻ any(new_p2 .!= original_p2)

    configured_mutation = ConstantMutation(;
        perturbation_factor=10.0, probability_negate=1.0
    )
    configured_expr = mutate_constant(
        copy(expr), temperature, options, configured_mutation, MersenneTwister(1)
    )
    default_expr = mutate_constant(
        copy(expr), temperature, options, ConstantMutation(), MersenneTwister(1)
    )
    @test get_metadata(configured_expr).parameters != get_metadata(default_expr).parameters

    condition_options = Options(;
        binary_operators=(+, *, /, -),
        unary_operators=(sin, cos),
        expression_spec=TemplateExpressionSpec(; structure=struct_with_params),
        should_simplify=false,
    )
    dataset = Dataset(randn(3, 8), randn(8))
    member = PopMember(dataset, expr, condition_options; deterministic=true)
    weights = copy(condition_options.mutations)
    condition_mutation_weights!(weights, member, condition_options, 0, 1)
    @test only(weight for (mutation, weight) in weights if mutation isa FeatureMutation) ==
        0.0
    @test only(weight for (mutation, weight) in weights if mutation isa AddNodeMutation) ==
        0.0
    @test only(
        weight for (mutation, weight) in weights if mutation isa InsertNodeMutation
    ) == 0.0
    @test only(weight for (mutation, weight) in weights if mutation isa SimplifyMutation) ==
        0.0
end

@testitem "template crossover isolates shared graph nodes" begin
    using DynamicExpressions: get_child, get_contents
    using Random: MersenneTwister
    using SymbolicRegression
    using SymbolicRegression.EvolutionModule: crossover_trees
    using SymbolicRegression.EvolutionModule.MutationFunctionsModule:
        get_contents_for_mutation

    options = Options(; binary_operators=(+, *), node_type=GraphNode)
    operators = options.operators
    variable_names = ["x1", "x2"]
    structure = TemplateStructure{(:f, :g)}(
        ((; f, g), (x1, x2)) -> f(x1, x2) + g(x1, x2); num_features=(; f=2, g=2)
    )

    function make_parent(value, feature)
        function make_inner(offset)
            shared = GraphNode{Float64}(;
                op=1,
                children=(
                    GraphNode{Float64}(; val=value + offset),
                    GraphNode{Float64}(; feature=feature),
                ),
            )
            tree = GraphNode{Float64}(; op=2, children=(shared, shared))
            return ComposableExpression(tree; operators, variable_names)
        end
        return TemplateExpression(
            (; f=make_inner(0.0), g=make_inner(10.0)); structure, operators, variable_names
        )
    end

    function inner_nodes(ex)
        nodes = Any[]
        for inner in values(get_contents(ex))
            foreach(node -> push!(nodes, node), get_contents(inner))
        end
        return nodes
    end

    parent1 = make_parent(1.0, 1)
    parent2 = make_parent(2.0, 2)
    for parent in (parent1, parent2), inner in values(get_contents(parent))
        tree = get_contents(inner)
        @test get_child(tree, 1) === get_child(tree, 2)
    end

    parent_nodes = (inner_nodes(parent1), inner_nodes(parent2))
    for seed in 0:25
        context_rng = MersenneTwister(seed)
        _, context1 = get_contents_for_mutation(parent1, context_rng)
        _, context2 = get_contents_for_mutation(parent2, context_rng)
        child1, child2 = crossover_trees(parent1, parent2, MersenneTwister(seed))
        child_nodes = (inner_nodes(child1), inner_nodes(child2))
        @test all(
            child_node !== parent_node for nodes in child_nodes for
            original_nodes in parent_nodes for child_node in nodes for
            parent_node in original_nodes
        )
        @test all(a !== b for a in child_nodes[1] for b in child_nodes[2])
        for (child, selected_context) in zip((child1, child2), (context1, context2))
            for key in keys(get_contents(child))
                if key != selected_context
                    tree = get_contents(get_contents(child)[key])
                    @test get_child(tree, 1) === get_child(tree, 2)
                end
            end
        end
    end
end

@testitem "template crossover isolates recipient candidate state" begin
    using DynamicExpressions: get_contents, get_metadata
    using Random: MersenneTwister
    using SymbolicRegression
    using SymbolicRegression.EvolutionModule.CrossoverModule: crossover_generation
    using SymbolicRegression.EvolutionModule: crossover_trees

    structure = TemplateStructure{(:f, :g),(:p,)}(
        ((; f, g), (; p), (x,)) -> f(x) + g(x) * p[1]; num_parameters=(; p=2)
    )
    options = Options(;
        binary_operators=(+, *), expression_spec=TemplateExpressionSpec(; structure)
    )
    operators = options.operators
    variable_names = ["x"]

    function make_parent(f_value, g_value, parameters)
        function make_inner(value)
            return ComposableExpression(
                Node{Float64}(;
                    op=1, l=Node{Float64}(; val=value), r=Node{Float64}(; feature=1)
                );
                operators,
                variable_names,
            )
        end
        return TemplateExpression(
            (; f=make_inner(f_value), g=make_inner(g_value));
            structure,
            operators,
            variable_names,
            parameters=(; p=parameters),
        )
    end

    function inner_nodes(ex)
        nodes = Any[]
        for inner in values(get_contents(ex))
            foreach(node -> push!(nodes, node), get_contents(inner))
        end
        return nodes
    end

    parent1 = make_parent(1.0, 2.0, [3.0, 4.0])
    parent2 = make_parent(5.0, 6.0, [7.0, 8.0])
    copied_parent1 = copy(parent1)
    @test typeof(copied_parent1) === typeof(parent1)
    parent1_values = copy(
        first(SymbolicRegression.get_optimizable_parameters(parent1, options))
    )
    parent2_values = copy(
        first(SymbolicRegression.get_optimizable_parameters(parent2, options))
    )

    child1, child2 = crossover_trees(parent1, parent2, MersenneTwister(3))

    @test typeof(child1) === typeof(parent1)
    @test typeof(child2) === typeof(parent2)
    @test get_metadata(child1).parameters == get_metadata(parent1).parameters
    @test get_metadata(child2).parameters == get_metadata(parent2).parameters
    @test get_metadata(child1).parameters.p._data !==
        get_metadata(parent1).parameters.p._data
    @test get_metadata(child2).parameters.p._data !==
        get_metadata(parent2).parameters.p._data
    @test get_metadata(child1).parameters.p._data !==
        get_metadata(child2).parameters.p._data

    parent_nodes = (inner_nodes(parent1), inner_nodes(parent2))
    child_nodes = (inner_nodes(child1), inner_nodes(child2))
    for nodes in child_nodes, original_nodes in parent_nodes
        for node in nodes, original_node in original_nodes
            @test node !== original_node
        end
    end
    for node1 in child_nodes[1], node2 in child_nodes[2]
        @test node1 !== node2
    end

    for (child, offset) in zip((child1, child2), (10.0, 20.0))
        child_values, child_refs = SymbolicRegression.get_optimizable_parameters(
            child, options
        )
        SymbolicRegression.set_optimizable_parameters!(
            child, child_values .+ offset, child_refs
        )

        @test first(SymbolicRegression.get_optimizable_parameters(child, options)) ==
            child_values .+ offset
        @test first(SymbolicRegression.get_optimizable_parameters(parent1, options)) ==
            parent1_values
        @test first(SymbolicRegression.get_optimizable_parameters(parent2, options)) ==
            parent2_values
    end

    dataset = Dataset(zeros(Float64, 1, 4), zeros(Float64, 4))
    complexity1 = compute_complexity(parent1, options)
    complexity2 = compute_complexity(parent2, options)
    member1 = PopMember(
        parent1, 0.0, 0.0, options, complexity1; deterministic=options.deterministic
    )
    member2 = PopMember(
        parent2, 0.0, 0.0, options, complexity2; deterministic=options.deterministic
    )
    baby1, baby2, accepted, _ = crossover_generation(
        member1, member2, dataset, 100, options
    )
    @test accepted
    @test typeof(baby1) === typeof(member1)
    @test typeof(baby2) === typeof(member2)
end
