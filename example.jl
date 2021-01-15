@everywhere include("src/hyperparams.jl")
@everywhere include("src/sr.jl")

fullRun(100, npop=1000, ncyclesperiteration=300, fractionReplaced=0.100000f0, verbosity=round(Int32, 1000000000.000000), topn=10)
rmprocs(nprocs)
