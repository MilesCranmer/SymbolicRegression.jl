module SymbolicRegressionTablesExt

using Tables: Tables
import SymbolicRegression.HallOfFameModule: HOFRows, member_to_row

# Make HOFRows compatible with the Tables.jl interface
# HOFRows is already iterable via Base.iterate, so we just need to declare compatibility
Tables.istable(::Type{<:HOFRows}) = true
Tables.rowaccess(::Type{<:HOFRows}) = true
Tables.rows(view::HOFRows) = view  # Return itself since it's already iterable

# Provide schema information for better Tables.jl integration
function Tables.schema(rows::HOFRows)
    if isempty(rows.members)
        # Empty table - can't infer schema
        return nothing
    end

    # Get column names from either column specs or first row
    if rows.columns !== nothing
        # Use explicit column specs
        names = Tuple(col.name for col in rows.columns)
        # We can't reliably infer types without evaluating, so return nothing for types
        return Tables.Schema(names, nothing)
    else
        # Infer from first row
        first_row = member_to_row(
            rows.members[1], rows.dataset, rows.options; pretty=rows.pretty
        )
        if rows.include_score
            # Will add score in iteration
            names = (keys(first_row)..., :score)
        else
            names = keys(first_row)
        end
        # Get types from first row
        types = if rows.include_score
            (typeof.(values(first_row))..., Float64)  # Assume Float64 for score
        else
            typeof.(values(first_row))
        end
        return Tables.Schema(names, types)
    end
end

end
