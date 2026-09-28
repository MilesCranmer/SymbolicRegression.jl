@testitem "PopMember serialization preserves disk format and worker transfers" begin
    using SymbolicRegression
    using Serialization
    using Distributed
    using Distributed: ClusterSerializer
    using Random
    using Test
    using DynamicExpressions: get_child

    function same_tree(a, b)
        @test typeof(a) === typeof(b)
        @test a.degree == b.degree
        if a.degree == 0
            @test a.constant == b.constant
            if a.constant
                @test bitstring(a.val) == bitstring(b.val)
            else
                @test a.feature == b.feature
            end
        else
            @test a.op == b.op
            for i in 1:a.degree
                same_tree(get_child(a, i), get_child(b, i))
            end
        end
    end

    function check_member(member, copied)
        @test typeof(copied) === typeof(member)
        for field in fieldnames(typeof(member))
            if field == :tree
                @test typeof(copied.tree) === typeof(member.tree)
                @test isequal(
                    getfield(copied.tree, :metadata), getfield(member.tree, :metadata)
                )
                same_tree(get_tree(member.tree), get_tree(copied.tree))
            else
                @test isequal(getfield(copied, field), getfield(member, field))
            end
        end
        return copied
    end

    function roundtrip(member)
        io = IOBuffer()
        serialize(io, member)
        seekstart(io)
        return check_member(member, deserialize(io))
    end

    proc = only(addprocs(1))
    try
        Distributed.remotecall_eval(Main, [proc], :(using SymbolicRegression))
        rng = MersenneTwister(714)
        for T in (Float32, Float64)
            operators = OperatorEnum(1 => (cos, exp), 2 => (+, -, *, /))
            options = Options(; binary_operators=[+, -, *, /], unary_operators=[cos, exp])
            nan = if T === Float32
                reinterpret(Float32, 0x7fc01234)
            else
                reinterpret(Float64, 0x7ff8000000001234)
            end
            trees = [
                Node(T; feature=1),
                Node(T; val=(-zero(T))),
                Node(T; val=nan),
                Node(T; val=T(Inf)),
                Node(T; val=T(-Inf)),
                Node(; op=1, children=(Node(T; val=T(1.25)),)),
                Node(; op=1, children=(Node(T; feature=2), Node(T; val=T(2.5)))),
            ]
            append!(
                trees,
                [
                    gen_random_tree_fixed_size(rand(rng, 1:25), options, 5, T, rng) for
                    _ in 1:25
                ],
            )
            members = PopMember[]
            for (i, tree) in enumerate(trees)
                member = PopMember(
                    Expression(tree; operators, variable_names=["x1", "x2"]),
                    T(i) / T(8),
                    T(i) / T(16),
                    nothing,
                    count_nodes(tree);
                    deterministic=false,
                    ref=100 + i,
                    parent=i - 1,
                )
                if i == 1
                    disk_serializer = Serializer(IOBuffer())
                    @test which(serialize, (typeof(disk_serializer), typeof(member))).module ===
                        Serialization
                    @test which(
                        deserialize, (typeof(disk_serializer), Type{typeof(member)})
                    ).module === Serialization
                end
                roundtrip(member)
                io = IOBuffer()
                serialize(ClusterSerializer(io), member)
                seekstart(io)
                check_member(member, deserialize(ClusterSerializer(io)))
                push!(members, member)
            end
            for member in (members[2], members[3], members[6], members[7])
                check_member(member, remotecall_fetch(identity, proc, member))
            end

            other = copy(members[2])
            original_tree = getfield(other, :tree)
            setfield!(
                other, :tree,
                typeof(original_tree)(
                    get_tree(original_tree), getfield(members[1].tree, :metadata)
                )
            )
            io = IOBuffer()
            serialize(ClusterSerializer(io), (members[1], other, members[1]))
            seekstart(io)
            first_copy, other_copy, again = deserialize(ClusterSerializer(io))
            @test first_copy === again
            @test getfield(first_copy.tree, :metadata) ===
                getfield(other_copy.tree, :metadata)
            check_member(members[1], first_copy)
            check_member(other, other_copy)

            shared = GraphNode(T; feature=1)
            graph = GraphNode(; op=1, children=(shared, shared))
            fallback = PopMember(
                Expression(graph; operators, variable_names=["x1", "x2"]),
                T(2),
                T(3),
                nothing,
                3;
                deterministic=false,
                ref=789,
                parent=123,
            )
            recovered = roundtrip(fallback)
            @test get_child(get_tree(recovered.tree), 1) ===
                get_child(get_tree(recovered.tree), 2)
            returned_graph = check_member(
                fallback, remotecall_fetch(identity, proc, fallback)
            )
            @test get_child(get_tree(returned_graph.tree), 1) ===
                get_child(get_tree(returned_graph.tree), 2)

            pair = (fallback, fallback)
            io = IOBuffer()
            serialize(ClusterSerializer(io), pair)
            seekstart(io)
            recovered_pair = deserialize(ClusterSerializer(io))
            @test recovered_pair[1] === recovered_pair[2]
            check_member(fallback, recovered_pair[1])
        end
    finally
        rmprocs(proc)
    end
end
