module TemplateExpressionMacroModule

"""
    @template_spec(
        expressions=(f, g, ...),
        [parameters=(p1=size1, p2=size2, ...)],
        [num_features=(f=n1, g=n2, ...)]
    ) do x1, x2, ...
        # template function body
    end

Creates a TemplateExpressionSpec with a custom template structure for symbolic regression.

This macro allows defining structured symbolic expressions with constrained composition
of sub-expressions and parameterized components.

# Arguments
- `expressions`: A tuple of function names that will be composed in the template.
- `parameters`: Optional. A named tuple of parameter name-size pairs. These parameters
    can be indexed and accessed in the template function.
- `num_features`: Optional. A named tuple specifying how many features each expression function can access.
    Normally this will be inferred automatically from the template function.

# Example
```julia
expr_spec = @template_spec(
    parameters=(p1=10, p2=10, p3=1),
    expressions=(f, g),
) do x1, x2, class
    return p1[class] * g(x1^2) + f(x1, x2, p2[class]) - p3[1]
end
```
"""
macro template_spec(f, args...)
    return esc(template_spec(f, args...))
end

function template_spec(func, args...)
    # Extract the parameters and expressions from the arguments
    parameters = nothing
    expressions = nothing
    num_features = nothing

    for arg in args
        if Meta.isexpr(arg, :(=))
            name, value = arg.args
            if name == :parameters
                !isnothing(parameters) && error("cannot set `parameters` keyword twice")
                parameters = value
            elseif name == :expressions
                !isnothing(expressions) && error("cannot set `expressions` keyword twice")
                expressions = value
            elseif name == :num_features
                !isnothing(num_features) && error("cannot set `num_features` keyword twice")
                num_features = value
            else
                error("unrecognized keyword $(name)")
            end
        else
            error("no positional args accepted after the first")
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
                    end;
                    num_features=$(num_features),
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
                    num_features=$(num_features),
                    num_parameters=$(parameters),
                ),
            )
        end
    end
end

end
