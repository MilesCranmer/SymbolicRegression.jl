module TemplateExpressionMacroModule

"""
    @template(
        parameters=(p1=10, p2=10, p3=1),
        expressions=(f, g),
    ) do x1, x2, class
        return p1[class] * x1^2 + f(x1, x2, p2[class]) - p3[1],
    end

Creates a template expression with the given parameters and expressions.
The parameters are used to define constants that can be indexed, and the
expressions define the function keys for the template structure.

# Arguments
- `parameters`: A NamedTuple of parameter names and their sizes
- `expressions`: A Tuple of function names to use in the template
- `do` block: A function that takes arguments and returns an expression

# Returns
A function that takes operators and variable_names and returns a TemplateExpression.

# Example
```julia
template = @template(
    parameters=(p1=10, p2=10, p3=1),
    expressions=(f, g),
) do x1, x2, class
    return p1[class] * x1^2 + f(x1, x2, p2[class]) - p3[1]
end

# Then use it with:
operators = Options().operators
variable_names = ["x1", "x2", "class"]
expr = template(operators, variable_names)
```
"""
macro template(f, args...)
    return esc(template(f, args...))
end

function template(f, args...)
    # Extract the parameters and expressions from the arguments
    parameters = nothing
    expressions = nothing

    for arg in args
        if Meta.isexpr(arg, :(=))
            name, value = arg.args
            if name == :parameters
                parameters = value
            elseif name == :expressions
                expressions = value
            end
        end
    end

    # Only expressions are required now
    if isnothing(expressions)
        throw(ArgumentError("expressions must be specified"))
    end

    # Validate expressions format
    if !Meta.isexpr(expressions, :tuple)
        throw(ArgumentError("expressions must be a tuple of the form `(f, g, ...)`"))
    end

    # Validate parameters format if provided
    if !isnothing(parameters)
        if !Meta.isexpr(parameters, :tuple)
            throw(
                ArgumentError(
                    "parameters must be a tuple of parameter name-size pairs like `(p1=10, p2=10, p3=1)`",
                ),
            )
        end

        # Check each parameter is a name=value pair
        for param in parameters.args
            if !Meta.isexpr(param, :(=))
                throw(
                    ArgumentError(
                        "parameters must be a tuple of parameter name-size pairs like `(p1=10, p2=10, p3=1)`",
                    ),
                )
            end
        end
    end

    # Extract the function body and arguments
    if Meta.isexpr(f, :do)
        func = f.args[2]
    else
        func = f
    end

    if !Meta.isexpr(func, :->)
        throw(ArgumentError("Expected a do block"))
    end

    # Convert expressions tuple to a tuple of symbols
    function_keys = Tuple(QuoteNode(ex) for ex in expressions.args)
    expr_names = expressions.args

    func_args = func.args[1]
    if !Meta.isexpr(func_args, :tuple)
        throw(ArgumentError("Expected a tuple of arguments for the function arguments"))
    end
    func_body = func.args[2]
    func_args = func_args.args

    # Create the TemplateStructure with or without parameters
    if isnothing(parameters)
        quote
            TemplateExpressionSpec(;
                structure=TemplateStructure{($(function_keys...),)}(
                    function ((; $(expr_names...)), ($(func_args...),))
                        return $(func_body)
                    end
                ),
            )
        end
    else
        # Convert parameters tuple to a tuple of symbols
        param_keys = Tuple(QuoteNode(p.args[1]) for p in parameters.args)
        param_names = [p.args[1] for p in parameters.args]

        quote
            TemplateExpressionSpec(;
                structure=TemplateStructure{($(function_keys...),),($(param_keys...),)}(
                    function (
                        (; $(expr_names...)), (; $(param_names...)), ($(func_args...),)
                    )
                        return $(func_body)
                    end;
                    num_parameters=$(parameters),
                ),
            )
        end
    end
end

end
