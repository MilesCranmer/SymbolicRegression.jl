@testitem "pretty print member" begin
    using SymbolicRegression

    options = Options(; binary_operators=[+, ^])

    ex = @parse_expression(x^2.0 + 1.5, binary_operators = [+, ^], variable_names = [:x])
    shower(x) = sprint((io, e) -> show(io, MIME"text/plain"(), e), x)
    s = shower(ex)
    @test s == "(x ^ 2.0) + 1.5"

    X = [1.0 2.0 3.0]
    y = [2.0, 3.0, 4.0]
    dataset = Dataset(X, y)
    member = PopMember(dataset, ex, options; deterministic=false)
    member.score = 1.0
    @test member isa PopMember{Float64,Float64,<:Expression{Float64,Node{Float64}}}
    s_member = shower(member)
    @test s_member ==
        "PopMember(\n    tree = (x ^ 2.0) + 1.5\n    loss = 16.25\n    score = 1.0\n)\n"
end

@testitem "pretty print hall of fame" begin
    using SymbolicRegression
    using SymbolicRegression.CoreModule: safe_pow

    options = Options(; binary_operators=[+, safe_pow], maxsize=7)

    ex = @parse_expression(
        $safe_pow(x, 2.0) + 1.5, binary_operators = [+, safe_pow], variable_names = [:x]
    )
    shower(x) = sprint((io, e) -> show(io, MIME"text/plain"(), e), x)
    s = shower(ex)
    @test s == "(x ^ 2.0) + 1.5"

    X = [1.0 2.0 3.0]
    y = [2.0, 3.0, 4.0]
    dataset = Dataset(X, y)
    member = PopMember(dataset, ex, options; deterministic=false)
    member.score = 1.0
    @test member isa PopMember{Float64,Float64,<:Expression{Float64,Node{Float64}}}

    hof = HallOfFame(options, dataset)
    hof.members[5] = member
    hof.exists[5] = true
    s_hof = strip(shower(hof))
    true_s = "HallOfFame{...}:
    .exists[1] = false
    .members[1] = undef
    .exists[2] = false
    .members[2] = undef
    .exists[3] = false
    .members[3] = undef
    .exists[4] = false
    .members[4] = undef
    .exists[5] = true
    .members[5] =
        PopMember(
            tree = (x ^ 2.0) + 1.5
            loss = 16.25
            score = 1.0
        )
    .exists[6] = false
    .members[6] = undef
    .exists[7] = false
    .members[7] = undef
    .exists[8] = false
    .members[8] = undef
    .exists[9] = false
    .members[9] = undef"

    @test s_hof == true_s
end
