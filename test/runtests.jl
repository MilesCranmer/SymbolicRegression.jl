using SafeTestsets

# HACK
using Pkg
using Distributed
import ReverseDiff
procs = addprocs(4)

# Activate env on workers:
project_path = splitdir(Pkg.project().path)[1]
@everywhere procs begin
    Base.MainInclude.eval(
        quote
            using Pkg
            Pkg.activate($$project_path)
        end,
    )
end

# Import package on workers:
@everywhere procs begin
    Base.MainInclude.eval(import ReverseDiff)
end

# Import SymbolicRegression on workers:
@everywhere procs begin
    Base.MainInclude.eval(using SymbolicRegression)
end
# END HACK

if false
	@safetestset "Unit tests" begin
		include("unittest.jl")
	end
	@safetestset "End to end test" begin
		include("full.jl")
	end
end
