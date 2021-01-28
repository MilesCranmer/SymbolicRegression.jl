using SymbolicUtils
using SymbolicUtils: Chain, If, RestartedChain, IfElse, Postwalk, Fixpoint, @ordered_acrule, isnotflat, flatten_term, needs_sorting, sort_args, is_literal_number, hasrepeats, merge_repeats, _isone, _iszero, _isinteger, istree, symtype, is_operation, has_trig, <ₑ

mutable struct Node
    #Holds operators, variables, constants in a tree
    degree::Integer #0 for constant/variable, 1 for cos/sin, 2 for +/* etc.
    val::Union{Float32, Integer, Nothing} #Either const value, or enumerates variable
    constant::Bool #false if variable
    op::Integer #enumerates operator (separately for degree=1,2)
    l::Union{Node, Nothing}
    r::Union{Node, Nothing}

    Node(val::Float32) = new(0, val, true, 1, nothing, nothing)
    Node(val::Float64) = new(0, convert(Float32, val), true, 1, nothing, nothing)
    Node(val::Integer) = new(0, val, false, 1, nothing, nothing)
    Node(val::String) = Node(parse(Int, val[2:end])) #e.g., "x0"
    Node(op::Integer, l::Node) = new(1, nothing, false, op, l, nothing)
    Node(op::Integer, l::Union{Float32, Integer}) = new(1, nothing, false, op, Node(l), nothing)
    Node(op::Integer, l::Node, r::Node) = new(2, nothing, false, op, l, r)

    Node(op::Integer, l::Union{Float32, Integer}, r::Node) = new(2, nothing, false, op, Node(l), r)
    Node(op::Integer, l::Node, r::Union{Float32, Integer}) = new(2, nothing, false, op, l, Node(r))
    Node(op::Integer, l::Union{Float32, Integer}, r::Union{Float32, Integer}) = new(2, nothing, false, op, Node(l), Node(r))
end


countNodes(tree::Nothing) = 0
countNodes(tree::Node) = 1 + countNodes(tree.l) + countNodes(tree.r)

#User-defined operations
binops = (+, *, /, -)
unaops = (cos, exp)


function stringOp(op::F, tree::Node;
                  bracketed::Bool=false,
                  varMap::Union{Array{String, 1}, Nothing}=nothing)::String where {F}
    if op in [+, -, *, /, ^]
        l = stringTree(tree.l,  bracketed=false, varMap=varMap)
        r = stringTree(tree.r,  bracketed=false, varMap=varMap)
        if bracketed
            return "$l $(string(op)) $r"
        else
            return "($l $(string(op)) $r)"
        end
    else
        l = stringTree(tree.l,  bracketed=true, varMap=varMap)
        r = stringTree(tree.r,  bracketed=true, varMap=varMap)
        return "$(string(op))($l, $r)"
    end
end

# Convert an equation to a string
function stringTree(tree::Node;
                    bracketed::Bool=false,
                    varMap::Union{Array{String, 1}, Nothing}=nothing)::String
    if tree.degree == 0
        if tree.constant
            return string(tree.val)
        else
            if varMap == nothing
                return "x$(tree.val)"
            else
                return varMap[tree.val]
            end
        end
    elseif tree.degree == 1
        return "$(unaops[tree.op])($(stringTree(tree.l, bracketed=true, varMap=varMap)))"
    else
        return stringOp(binops[tree.op], tree, bracketed=bracketed, varMap=varMap)
    end
end

# Print an equation
function printTree(tree::Node; varMap::Union{Array{String, 1}, Nothing}=nothing)
    println(stringTree(tree, varMap=varMap))
end

SymbolicUtils.istree(x::Node)::Bool = (x.degree > 0)
SymbolicUtils.operation(x::Node)::Function = x.degree == 1 ? unaops[x.op] : binops[x.op]
SymbolicUtils.arguments(x::Node)::Array{Node} = x.degree == 1 ? [x.l] : [x.l, x.r]
SymbolicUtils.similarterm(x::Node, f, args) = begin
    nargs = length(args)
    if nargs == 1
        f(args[1])
    elseif nargs == 2
        f(args[1], args[2])
    else
        f(args[1], SymbolicUtils.similarterm(x, f, args[2:end]))
    end
end
SymbolicUtils.symtype(x::Node) = Real
SymbolicUtils.promote_symtype(f, arg_symtypes...) = Real

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


## How SymbolicUtils orders:

arglength(a::Node) = a.degree

SymbolicUtils.:(<ₑ)(a::Node,    b::Number) = false
SymbolicUtils.:(<ₑ)(a::Number,  b::Node) = true
SymbolicUtils.:(<ₑ)(a::Node,    b::Node) = begin
    if !SymbolicUtils.istree(a) && !SymbolicUtils.istree(b)
        if a.constant && b.constant
            return a.val <ₑ b.val
        elseif a.constant
            return true
        elseif b.constant
            return false
        else
            return SymbolicUtils.:(<ₑ)(a.val, b.val)
        end
    elseif istree(b) && !istree(a)
        return true
    elseif istree(a) && istree(b)
        return cmp_term_term(a,b)
    else
        return !(SymbolicUtils.:(<ₑ)(b, a))
    end
end

SymbolicUtils.is_literal_number(x::Node) = x.constant

function cmp_term_term(a, b)
    la = arglength(a)
    lb = arglength(b)

    if la == 0 && lb == 0
        return nameof(SymbolicUtils.operation(a)) <ₑ nameof(SymbolicUtils.operation(b))
    elseif la === 0
        return SymbolicUtils.:(<ₑ)(SymbolicUtils.operation(a), b)
    elseif lb === 0
        return SymbolicUtils.:(<ₑ)(a, SymbolicUtils.operation(b))
    end

	aa, ab = SymbolicUtils.arguments(a), SymbolicUtils.arguments(b)
	if length(aa) !== length(ab)
		return length(aa) < length(ab)
	else
		terms = zip(Iterators.filter(!SymbolicUtils.is_literal_number, aa), Iterators.filter(!SymbolicUtils.is_literal_number, ab))

		for (x,y) in terms
			if SymbolicUtils.:(<ₑ)(x, y)
				return true
			elseif SymbolicUtils.:(<ₑ)(y, x)
				return false
			end
		end

		# compare the numbers
		nums = zip(Iterators.filter(SymbolicUtils.is_literal_number, aa),
				   Iterators.filter(SymbolicUtils.is_literal_number, ab))

		for (x,y) in nums
			if SymbolicUtils.:(<ₑ)(x, y)
				return true
			elseif SymbolicUtils.:(<ₑ)(y, x)
				return false
			end
		end
	end
    na = nameof(SymbolicUtils.operation(a))
    nb = nameof(SymbolicUtils.operation(b))
	return SymbolicUtils.:(<ₑ)(na, nb) # all args are equal, compare the name
end

Base.isless(a::Node, b::Node) = SymbolicUtils.:(<ₑ)(a, b)

for (op, f) in enumerate(map(Symbol, binops))
    @eval begin
        Base.$f(l::Node, r::Node) = (l.constant && r.constant) ?  Node($f(l.val, r.val)) : Node($op, l, r)
        Base.$f(l::Node, r::Real) = l.constant ?  Node($f(l.val, r)) : Node($op, l, convert(Float32, r))
        Base.$f(l::Real, r::Node) = r.constant ?  Node($f(l, r.val)) : Node($op, convert(Float32, l), r)
    end
end

for (op, f) in enumerate(map(Symbol, unaops))
    @eval begin
        Base.$f(l::Node) = l.constant ? Node($f(l.val)) : Node($op, l)
        Base.$f(l::Real) = Node($f(l))
    end
end

PLUS_RULES = [
    @rule(~x::isnotflat(+) => flatten_term(+, ~x))
    @rule(~x::needs_sorting(+) => sort_args(+, ~x))
    @ordered_acrule(~a::is_literal_number + ~b::is_literal_number => ~a + ~b)

    @acrule(*(~~x) + *(~β, ~~x) => *(1 + ~β, (~~x)...))
    @acrule(*(~α, ~~x) + *(~β, ~~x) => *(~α + ~β, (~~x)...))
    @acrule(*(~~x, ~α) + *(~~x, ~β) => *(~α + ~β, (~~x)...))

    @acrule(~x + *(~β, ~x) => *(1 + ~β, ~x))
    @acrule(*(~α::is_literal_number, ~x) + ~x => *(~α + 1, ~x))
    @rule(+(~~x::hasrepeats) => +(merge_repeats(*, ~~x)...))

    @ordered_acrule((~z::_iszero + ~x) => ~x)
    @rule(+(~x) => ~x)
]

TIMES_RULES = [
    @rule(~x::isnotflat(*) => flatten_term(*, ~x))
    @rule(~x::needs_sorting(*) => sort_args(*, ~x))

    @ordered_acrule(~a::is_literal_number * ~b::is_literal_number => ~a * ~b)
    @rule(*(~~x::hasrepeats) => *(merge_repeats(^, ~~x)...))

    @acrule((~y)^(~n) * ~y => (~y)^(~n+1))
    @ordered_acrule((~x)^(~n) * (~x)^(~m) => (~x)^(~n + ~m))

    @ordered_acrule((~z::_isone  * ~x) => ~x)
    @ordered_acrule((~z::_iszero *  ~x) => ~z)
    @rule(*(~x) => ~x)
]


POW_RULES = [
    @rule(^(*(~~x), ~y::_isinteger) => *(map(a->pow(a, ~y), ~~x)...))
    @rule((((~x)^(~p::_isinteger))^(~q::_isinteger)) => (~x)^((~p)*(~q)))
    @rule(^(~x, ~z::_iszero) => 1)
    @rule(^(~x, ~z::_isone) => ~x)
    @rule(inv(~x) => ~x ^ -1)
]

ASSORTED_RULES = [
    @rule(identity(~x) => ~x)
    @rule(-(~x) => -1*~x)
    @rule(-(~x, ~y) => ~x + -1(~y))
    @rule(~x::_isone \ ~y => ~y)
    @rule(~x \ ~y => ~y / (~x))
    @rule(~x / ~y => ~x * pow(~y, -1))
    @rule(one(~x) => one(symtype(~x)))
    @rule(zero(~x) => zero(symtype(~x)))
    @rule(cond(~x::is_literal_number, ~y, ~z) => ~x ? ~y : ~z)
]

TRIG_RULES = [
    @acrule(sin(~x)^2 + cos(~x)^2 => one(~x))
    @acrule(sin(~x)^2 + -1        => cos(~x)^2)
    @acrule(cos(~x)^2 + -1        => sin(~x)^2)

    @acrule(tan(~x)^2 + -1*sec(~x)^2 => one(~x))
    @acrule(tan(~x)^2 +  1 => sec(~x)^2)
    @acrule(sec(~x)^2 + -1 => tan(~x)^2)

    @acrule(cot(~x)^2 + -1*csc(~x)^2 => one(~x))
    @acrule(cot(~x)^2 +  1 => csc(~x)^2)
    @acrule(csc(~x)^2 + -1 => cot(~x)^2)
]

TRIG_RULES = [
	@acrule(sin(~x)^2 + cos(~x)^2 => one(~x))
	@acrule(sin(~x)^2 + -1        => cos(~x)^2)
	@acrule(cos(~x)^2 + -1        => sin(~x)^2)

	@acrule(tan(~x)^2 + -1*sec(~x)^2 => one(~x))
	@acrule(tan(~x)^2 +  1 => sec(~x)^2)
	@acrule(sec(~x)^2 + -1 => tan(~x)^2)

	@acrule(cot(~x)^2 + -1*csc(~x)^2 => one(~x))
	@acrule(cot(~x)^2 +  1 => csc(~x)^2)
	@acrule(csc(~x)^2 + -1 => cot(~x)^2)
]

function number_simplifier()
    rule_tree = [If(istree, Chain(ASSORTED_RULES)),
                 If(is_operation(+),
                    Chain(PLUS_RULES)),
                 If(is_operation(*),
                    Chain(TIMES_RULES)),
                 If(is_operation(^),
                    Chain(POW_RULES))] |> RestartedChain

    rule_tree
end

trig_simplifier(;kw...) = Chain(TRIG_RULES)

function default_simplifier(; kw...)
	IfElse(has_trig,
		   Postwalk(Chain((number_simplifier(),
						   trig_simplifier())),
					; kw...),
		   Postwalk(number_simplifier())
					; kw...)
end

# reduce overhead of simplify by defining these as constant
serial_simplifier = If(istree, Fixpoint(default_simplifier()))


