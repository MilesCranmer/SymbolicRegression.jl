@testitem "Plain multiprocessing transfers preserve populations and results" begin
    using Test
    using SymbolicRegression
    using SymbolicRegression.MPTransferModule:
        pack_population,
        unpack_population,
        pack_hall_of_fame,
        unpack_hall_of_fame,
        pack_worker_output,
        unpack_worker_output
    using DynamicExpressions:
        Expression, GraphNode, Node, get_child, get_metadata, get_tree, with_contents

    function check_tree(original, rebuilt)
        @test typeof(rebuilt) === typeof(original)
        @test rebuilt.degree == original.degree
        if original.degree == 0
            @test rebuilt.constant == original.constant
            if original.constant
                @test bitstring(rebuilt.val) == bitstring(original.val)
            else
                @test rebuilt.feature == original.feature
            end
        else
            @test rebuilt.op == original.op
            for i in 1:original.degree
                check_tree(get_child(original, i), get_child(rebuilt, i))
            end
        end
    end

    function check_members(original, rebuilt)
        @test length(rebuilt) == length(original)
        for (a, b) in zip(original, rebuilt)
            @test typeof(b) === typeof(a)
            @test b !== a
            @test get_metadata(b.tree) === get_metadata(a.tree)
            check_tree(get_tree(a.tree), get_tree(b.tree))
            @test bitstring(b.cost) == bitstring(a.cost)
            @test bitstring(b.loss) == bitstring(a.loss)
            @test b.birth == a.birth
            @test getfield(b, :complexity) == getfield(a, :complexity)
            @test b.ref == a.ref
            @test b.parent == a.parent
        end
    end

    for T in (Float32, Float64)
        nan = if T === Float32
            reinterpret(Float32, 0x7fc01234)
        else
            reinterpret(Float64, 0x7ff8000000001234)
        end
        leaf = Node(T; feature=2)
        deep = Node(;
            op=1,
            children=(
                Node(; op=2, children=(Node(T; val=(-zero(T))), leaf)),
                Node(; op=1, children=(Node(T; val=nan),)),
            ),
        )
        trees = [leaf, Node(T; val=(-zero(T))), Node(T; val=nan), deep]
        prototype = Expression(
            first(trees);
            operators=OperatorEnum(1 => (cos,), 2 => (+, *)),
            variable_names=["x1"],
        )
        members = [
            PopMember(
                with_contents(prototype, tree),
                T(i) / T(8),
                T(i) / T(16),
                nothing,
                10 + i;
                deterministic=true,
                ref=100 + i,
                parent=i - 1,
            ) for (i, tree) in enumerate(trees)
        ]
        for (i, member) in enumerate(members)
            member.birth = -10 - i
        end
        pop = Population(members)
        packed_pop = pack_population(pop)
        @test packed_pop !== pop
        rebuilt_pop = unpack_population(packed_pop)
        @test typeof(rebuilt_pop) === typeof(pop)
        @test rebuilt_pop.n == pop.n
        check_members(pop.members, rebuilt_pop.members)

        hof = HallOfFame(copy(members), [true, false, true, true])
        packed_hof = pack_hall_of_fame(hof)
        @test packed_hof !== hof
        rebuilt_hof = unpack_hall_of_fame(packed_hof)
        @test typeof(rebuilt_hof) === typeof(hof)
        @test rebuilt_hof.exists == hof.exists
        check_members(hof.members, rebuilt_hof.members)

        output = (pop, hof, nothing, 5.0, ())
        packed_output = pack_worker_output(output, Val(true))
        @test packed_output !== output
        new_pop, new_hof, new_trace, new_evals, new_states = unpack_worker_output(
            packed_output
        )
        check_members(pop.members, new_pop.members)
        check_members(hof.members, new_hof.members)
        @test new_hof.exists == hof.exists
        @test new_trace === nothing
        @test new_evals == 5.0
        @test new_states == ()
        @test pack_worker_output(output, Val(false)) === output

        other_metadata = Expression(
            leaf; operators=OperatorEnum(1 => (cos,), 2 => (+, *)), variable_names=["other"]
        )
        @test get_metadata(other_metadata) !== get_metadata(prototype)
        mixed_member = PopMember(
            other_metadata, T(2), T(3), nothing, 2; deterministic=true, ref=876, parent=123
        )
        mixed_pop = Population([members[1], mixed_member])
        @test pack_population(mixed_pop) === mixed_pop
        @test unpack_population(mixed_pop) === mixed_pop
        mixed_hof = HallOfFame(mixed_pop.members, [true, false])
        @test pack_hall_of_fame(mixed_hof) === mixed_hof

        shared = GraphNode(T; feature=1)
        graph = GraphNode(; op=1, children=(shared, shared))
        graph_member = PopMember(
            Expression(graph; operators=OperatorEnum(1 => (cos,), 2 => (+, *))),
            T(1),
            T(2),
            nothing,
            3;
            deterministic=true,
            ref=789,
            parent=123,
        )
        graph_pop = Population([graph_member])
        @test get_child(get_tree(graph_member.tree), 1) ===
            get_child(get_tree(graph_member.tree), 2)
        @test pack_population(graph_pop) === graph_pop
        @test unpack_population(graph_pop) === graph_pop
    end
    X = rand(Float32, 2, 32)
    y = vec(X[1, :] .+ X[2, :])
    options = Options(;
        binary_operators=[+, *],
        populations=2,
        population_size=8,
        tournament_selection_n=4,
        ncycles_per_iteration=3,
        maxsize=10,
        save_to_file=false,
    )
    pops, hof = equation_search(
        X,
        y;
        options,
        parallelism=:multiprocessing,
        numprocs=2,
        niterations=2,
        return_state=true,
        progress=false,
        verbosity=0,
    )
    @test length(pops) == 1
    @test length(only(pops)) == 2
    @test all(pop -> pop isa Population && pop.n == 8, only(pops))
    @test hof isa HallOfFame
    @test any(hof.exists)
    @test all(member -> isfinite(member.loss), hof.members[hof.exists])
end
