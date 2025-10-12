module SymbolicRegressionTablesExt

using Tables: Tables
import SymbolicRegression.HallOfFameModule: HOFRows

# Make HOFRows compatible with the Tables.jl interface
# HOFRows is already iterable via Base.iterate, so we just need to declare compatibility
Tables.istable(::Type{<:HOFRows}) = true
Tables.rowaccess(::Type{<:HOFRows}) = true
Tables.rows(view::HOFRows) = view  # Return itself since it's already iterable

end
