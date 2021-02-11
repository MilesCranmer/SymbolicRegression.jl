using FromFile

@from "ProgramConstants.jl" import CONST_TYPE, maxdegree
@from "Dataset.jl" import Dataset
@from "Equation.jl" import Node, copyNode
@from "Options.jl" import Options
@from "Operators.jl" import plus, sub, mult, square, cube, pow, div, log_abs, log2_abs, log10_abs, sqrt_abs, neg, greater, greater, relu, logical_or, logical_and
