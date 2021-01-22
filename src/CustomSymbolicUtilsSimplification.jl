using SymbolicUtils
using SymbolicUtils.Rewriters

const AllEquationTypes = Union{<:Real,SymbolicUtils.Sym{<:Number},SymbolicUtils.Term{<:Number}}

function multiply_powers(eqn::T)::AllEquationTypes where {T<:Union{<:Real,SymbolicUtils.Sym{<:Number}}}
	return eqn
end

function multiply_powers(eqn::T, op::F)::AllEquationTypes where {F<:Function,T<:SymbolicUtils.Term{<:Number}}
	args = SymbolicUtils.arguments(eqn)
	nargs = length(args)
	if nargs == 1
		return op(multiply_powers(args[1]))
	elseif op == ^
		l = multiply_powers(args[1])
		n::Int = args[2]
		if n == 1
			return l
		elseif n == -1
			return 1 / l
		elseif n > 1
			return reduce(*, [l for i=1:n])
		elseif n < -1
			return reduce(/, vcat([1], [l for i=1:n]))
		else
			return 1.0
		end
	elseif nargs == 2
		return op(multiply_powers(args[1]), multiply_powers(args[2]))
	else
		return mapreduce(multiply_powers, op, args)
	end
end

function multiply_powers(eqn::T)::AllEquationTypes where {T<:SymbolicUtils.Term{<:Number}}
	op = SymbolicUtils.operation(eqn)
	return multiply_powers(eqn, op)
end

function custom_simplify(eqn::T, options::Options)::AllEquationTypes where {T<:AllEquationTypes}

	# Full number simplifier:
	# f = Fixpoint(number_simplifier())
	# eqn = PassThrough(f)(to_symbolic(eqn))
	eqn = simplify(eqn) #,SymbolicUtils.RuleSet(RULES))

	# Remove power laws
	if ~((^) in options.binops)
		eqn = multiply_powers(eqn)
	end
	return eqn
end


