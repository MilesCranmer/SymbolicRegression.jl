# HACK
using Pkg, Distributed
procs = addprocs(4)

# Activate env on workers:
project_path = splitdir(Pkg.project().path)[1]
@everywhere procs begin
    Base.MainInclude.eval(
        quote
            using Pkg
            Pkg.activate($$project_path)
            # Import package on workers:
            import ReverseDiff
        end,
    )
end
# END HACK