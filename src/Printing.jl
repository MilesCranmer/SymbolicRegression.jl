"""Defines printing methods of exported types (aside from expressions themselves)"""
module PrintingModule

using ..CoreModule: Options
using ..MLJInterfaceModule: SRRegressor, SRFitResult

function Base.print(io::IO, @nospecialize(options::Options))
    return print(
        io,
        "Options(" *
        "binops=$(options.operators.binops), " *
        "unaops=$(options.operators.unaops), "
        # Fill in remaining fields automatically:
        *
        join(
            [
                if fieldname in (:optimizer_options, :mutation_weights)
                    "$(fieldname)=..."
                else
                    "$(fieldname)=$(getfield(options, fieldname))"
                end for
                fieldname in fieldnames(Options) if fieldname ∉ [:operators, :nuna, :nbin]
            ],
            ", ",
        ) *
        ")",
    )
end
function Base.show(io::IO, ::MIME"text/plain", @nospecialize(options::Options))
    return Base.print(io, options)
end

function Base.show(io::IO, ::MIME"text/plain", @nospecialize(fitresult::SRFitResult))
    print(io, "SRFitResult for $(fitresult.model):")
    print(io, "\n")
    print(io, "  state:\n")
    print(io, "    [1]: $(typeof(fitresult.state[1])) with ")
    print(io, "$(length(fitresult.state[1])) × $(length(fitresult.state[1][1])) ")
    print(io, "populations of $(fitresult.state[1][1][1].n) members\n")
    print(io, "    [2]: $(typeof(fitresult.state[2])) ")
    if fitresult.model isa SRRegressor
        print(io, "with $(sum(fitresult.state[2].exists)) saved expressions")
    else
        print(io, "with $(map(s -> sum(s.exists), fitresult.state[2])) saved expressions")
    end
    print(io, "\n")
    print(io, "  num_targets: $(fitresult.num_targets)")
    print(io, "\n")
    print(io, "  variable_names: $(fitresult.variable_names)")
    print(io, "\n")
    print(io, "  y_variable_names: $(fitresult.y_variable_names)")
    print(io, "\n")
    print(io, "  X_units: $(fitresult.X_units)")
    print(io, "\n")
    print(io, "  y_units: $(fitresult.y_units)")
    print(io, "\n")
    return nothing
end

end
