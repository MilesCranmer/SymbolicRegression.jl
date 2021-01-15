@everywhere include("src/hyperparams.jl")
@everywhere include("src/sr.jl")
using SR

RunSR(100, Options())
rmprocs(nprocs)
