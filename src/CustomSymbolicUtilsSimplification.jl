using FromFile
using SymbolicUtils
using SymbolicUtils: Chain, If, RestartedChain, IfElse, Postwalk, Fixpoint, @ordered_acrule, isnotflat, flatten_term, needs_sorting, sort_args, is_literal_number, hasrepeats, merge_repeats, _isone, _iszero, _isinteger, istree, symtype, is_operation, has_trig, polynormalize
@from "Core.jl" import Options
@from "InterfaceSymbolicUtils.jl" import SYMBOLIC_UTILS_TYPES
@from "EvaluateEquation.jl" import @return_on_false
 
function isgood(x::T)::Bool where {T<:Number}
    !(isnan(x) || !isfinite(x))
end

function isgood(x)::Bool
    true
end

function multiply_powers(eqn::T)::Tuple{SYMBOLIC_UTILS_TYPES,Bool} where {T<:Union{<:Number,SymbolicUtils.Sym{<:Number}}}
	return eqn, true
end

function multiply_powers(eqn::T, op::F)::Tuple{SYMBOLIC_UTILS_TYPES,Bool} where {F,T<:SymbolicUtils.Term{<:Number}}
	args = SymbolicUtils.arguments(eqn)
	nargs = length(args)
	if nargs == 1
        l, complete = multiply_powers(args[1])
        @return_on_false complete eqn
        @return_on_false isgood(l) eqn
		return op(l), true
	elseif op == ^
		l, complete = multiply_powers(args[1])
        @return_on_false complete eqn
        @return_on_false isgood(l) eqn
		n::Int = args[2]
		if n == 1
			return l, true
		elseif n == -1
			return 1.0 / l, true
		elseif n > 1
			return reduce(*, [l for i=1:n]), true
		elseif n < -1
			return reduce(/, vcat([1], [l for i=1:abs(n)])), true
		else
			return 1.0, true
		end
	elseif nargs == 2
        l, complete = multiply_powers(args[1])
        @return_on_false complete eqn
        @return_on_false isgood(l) eqn
        r, complete2 = multiply_powers(args[2])
        @return_on_false complete2 eqn
        @return_on_false isgood(r) eqn
		return op(l, r), true
	else
		# return mapreduce(multiply_powers, op, args)
        # ## reduce(op, map(multiply_powers, args))
        out = map(multiply_powers, args) #vector of tuples
        @return_on_false isgood(out[1][2]) eqn
        cumulator = out[1][1]
        for i=2:size(out, 1)
            @return_on_false isgood(out[i][2]) eqn
            cumulator = op(cumulator, out[i][1])
            @return_on_false isgood(cumulator) eqn
        end
        return cumulator, true
	end
end

function multiply_powers(eqn::T)::Tuple{SYMBOLIC_UTILS_TYPES,Bool} where {T<:SymbolicUtils.Term{<:Number}}
	op = SymbolicUtils.operation(eqn)
	return multiply_powers(eqn, op)
end

# Operators required for each rule:
function get_simplifier(binops::A, unaops::B) where {A,B}
    PLUS_RULES = [
       rule for (required_ops, rule) in [
       ((+,), @rule(~x::isnotflat(+) => flatten_term(+, ~x))),
       ((+,), @rule(~x::needs_sorting(+) => sort_args(+, ~x))),
       ((+,), @ordered_acrule(~a::is_literal_number + ~b::is_literal_number => ~a + ~b)),
       ((+,), @acrule(*(~~x) + *(~β, ~~x) => *(1 + ~β, (~~x)...))),
       ((+,), @acrule(*(~α, ~~x) + *(~β, ~~x) => *(~α + ~β, (~~x)...))),
       ((+,), @acrule(*(~~x, ~α) + *(~~x, ~β) => *(~α + ~β, (~~x)...))),
       ((+,), @acrule(~x + *(~β, ~x) => *(1 + ~β, ~x))),
       ((+,), @acrule(*(~α::is_literal_number, ~x) + ~x => *(~α + 1, ~x))),
       ((+,), @rule(+(~~x::hasrepeats) => +(merge_repeats(*, ~~x)...))),
       ((+,), @ordered_acrule((~z::_iszero + ~x) => ~x)),
       ((+,), @rule(+(~x) => ~x))]
       if all([(op in binops || op in unaops) for op in required_ops])
    ]
    TIMES_RULES = [
       rule for (required_ops, rule) in [
       ((*,), @rule(~x::isnotflat(*) => flatten_term(*, ~x))),
       ((*,), @rule(~x::needs_sorting(*) => sort_args(*, ~x))),
       ((*,), @ordered_acrule(~a::is_literal_number * ~b::is_literal_number => ~a * ~b)),
       ((*,), @rule(*(~~x::hasrepeats) => *(merge_repeats(^, ~~x)...))),
       ((*,), @acrule((~y)^(~n) * ~y => (~y)^(~n+1))),
       ((*,), @ordered_acrule((~x)^(~n) * (~x)^(~m) => (~x)^(~n + ~m))),
       ((*,), @ordered_acrule((~z::_isone  * ~x) => ~x)),
       ((*,), @ordered_acrule((~z::_iszero *  ~x) => ~z)),
       ((*,), @rule(*(~x) => ~x))]
       if all([(op in binops || op in unaops) for op in required_ops])
    ]
    POW_RULES =[
       rule for (required_ops, rule) in [
       ((*,), @rule(^(*(~~x), ~y::_isinteger) => *(map(a->SymbolicUtils.pow(a, ~y), ~~x)...))),
       ((*,), @rule((((~x)^(~p::_isinteger))^(~q::_isinteger)) => (~x)^((~p)*(~q)))),
       ((*,), @rule(^(~x, ~z::_iszero) => 1)),
       ((*,), @rule(^(~x, ~z::_isone) => ~x)),
       ((*, /,), @rule(inv(~x) => ~x ^ -1))]
       if all([(op in binops || op in unaops) for op in required_ops])
    ]
    ASSORTED_RULES =[
       rule for (required_ops, rule) in [
       ((), @rule(identity(~x) => ~x)),
       ((*,), @rule(-(~x) => -1*~x)),
       ((*, -,), @rule(-(~x, ~y) => ~x + -1(~y))),
       ((/, *,), @rule(~x / ~y => ~x * SymbolicUtils.pow(~y, -1))),
       ((), @rule(one(~x) => one(symtype(~x)))),
       ((), @rule(zero(~x) => zero(symtype(~x))))]
       if all([(op in binops || op in unaops) for op in required_ops])
    ]
    TRIG_RULES = [
       rule for (required_ops, rule) in [
       ((sin, cos, *, +,), @acrule(sin(~x)^2 + cos(~x)^2 => one(~x))),
       ((sin, cos, *, +,), @acrule(sin(~x)^2 + -1        => cos(~x)^2)),
       ((sin, cos, *, +,), @acrule(cos(~x)^2 + -1        => sin(~x)^2)),
       ((tan, sec, *, +,), @acrule(tan(~x)^2 + -1*sec(~x)^2 => one(~x))),
       ((tan, sec, *, +,), @acrule(tan(~x)^2 +  1 => sec(~x)^2)),
       ((tan, sec, *, +,), @acrule(sec(~x)^2 + -1 => tan(~x)^2)),
       ((cot, csc, *, +,), @acrule(cot(~x)^2 + -1*csc(~x)^2 => one(~x))),
       ((cot, csc, *, +,), @acrule(cot(~x)^2 +  1 => csc(~x)^2)),
       ((cot, csc, *, +,), @acrule(csc(~x)^2 + -1 => cot(~x)^2))]
       if all([(op in binops || op in unaops) for op in required_ops])
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
    serial_polynormal_simplifier = If(istree,
                                      Fixpoint(Chain((polynormalize,
                                                      Fixpoint(default_simplifier())))))
    return serial_polynormal_simplifier
end

function custom_simplify(init_eqn::T, options::Options)::Tuple{SYMBOLIC_UTILS_TYPES, Bool} where {T<:SYMBOLIC_UTILS_TYPES}
    if !istree(init_eqn) #simplifier will return nothing if not a tree.
        return init_eqn, false
    end
    simplifier = get_simplifier(options.binops, options.unaops)
    eqn = simplifier(init_eqn)::SYMBOLIC_UTILS_TYPES #simplify(eqn, polynorm=true)

	# Remove power laws
    eqn, complete = multiply_powers(eqn::SYMBOLIC_UTILS_TYPES)
    if !complete
        return init_eqn, false
    else
        return eqn, true
    end
end
