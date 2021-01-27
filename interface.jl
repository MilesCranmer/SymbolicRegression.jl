using SymbolicUtils
# using Random
# include("src/SymbolicRegression.jl")
# using .SymbolicRegression: Node, Options, Population, printTree

# Random.seed!(0)
# options = Options(
    # binary_operators=(+, *, /, -),
    # unary_operators=(cos, exp),
    # npopulations=4,
# )

mutable struct Node
    #Holds operators, variables, constants in a tree
    degree::Integer #0 for constant/variable, 1 for cos/sin, 2 for +/* etc.
    val::Union{Float32, Integer} #Either const value, or enumerates variable
    constant::Bool #false if variable
    op::Integer #enumerates operator (separately for degree=1,2)
    l::Union{Node, Nothing}
    r::Union{Node, Nothing}

    Node(val::Float32) = new(0, val, true, 1, nothing, nothing)
    Node(val::Integer) = new(0, val, false, 1, nothing, nothing)
    Node(op::Integer, l::Node) = new(1, convert(Float32, 0), false, op, l, nothing)
    Node(op::Integer, l::Union{Float32, Integer}) = new(1, convert(Float32, 0), false, op, Node(l), nothing)
    Node(op::Integer, l::Node, r::Node) = new(2, convert(Float32, 0), false, op, l, r)
end

#User-defined operations
binops = (+, *, /, -)
unaops = (cos, exp)


SymbolicUtils.istree(x::Node)::Bool = (x.degree > 0)
SymbolicUtils.operation(x::Node)::Function = x.degree == 1 ? unaops[x.op] : binops[x.op]
# SymbolicUtils.operation(x::Node)::Function = x.degree == 1 ? options.unaops[x.op] : options.binops[x.op]
SymbolicUtils.arguments(x::Node)::Array{Node} = x.degree == 1 ? [x.l] : [x.l, x.r]
SymbolicUtils.similarterm(x::Node, f, args) = begin
    nargs = length(args)
    if nargs == 1
        f(args[1])
    elseif nargs == 2
        f(args[1], args[2])
    else
        f(args[1], similarterm(x, f, args[2:end]))
    end
end

Base.hash(x::Node) = begin
    if x.degree == 0
        hash(hash(x.constant), hash(x.val))
    elseif x.degree == 1
        hash(hash(x.op), Base.hash(x.l))
    else
        hash(hash(x.op), hash(Base.hash(x.l), Base.hash(x.r)))
    end
end
Base.isequal(x::Node, y::Node)::Bool = begin
    if x.degree != y.degree
        false
    elseif x.degree == 0
        (x.constant == y.constant) && (x.val == y.val)
    elseif x.degree == 1
        (x.op == y.op) && Base.isequal(x.l, y.l)
    else
        (x.op == y.op) && Base.isequal(x.l, y.l) && Base.isequal(x.r, y.r) 
    end
end


# for (op, f) in enumerate(map(Symbol, options.binops))
for (op, f) in enumerate(map(Symbol, binops))
    @eval begin
        Base.$f(l::Node, r::Node) = (l.constant && r.constant) ?  Node($f(l.val, r.val)) : Node($op, l, r)
    end
end

# for (op, f) in enumerate(map(Symbol, options.unaops))
for (op, f) in enumerate(map(Symbol, unaops))
    @eval begin
        Base.$f(l::Node) = l.constant ?  Node($f(l.val)) : Node($op, l)
    end
end


t = Node(1f0) + Node(1) + Node(1f0)

t = SymbolicUtils.simplify(t)

println(isequal(Node(1f0), Node(1f0)))
println(t)










# X = randn(Float32, 100, 5)
# y = 2 * cos.(X[:, 4]) + X[:, 1] .^ 2 .- 2
# pop = Population(X, y, 1f0, npop=10, nlength=3, options=options, nfeatures=5)
# t = pop.members[1].tree
# printTree(t, options)
# println(SymbolicUtils.arguments((t, options)))





