# Using SymbolicRegression.jl on a Cluster

Here, we look at how to run SymbolicRegression.jl efficiently on an HPC cluster managed by Slurm.
Both methods utilize [`SlurmClusterManager.jl`](https://github.com/JuliaParallel/SlurmClusterManager.jl),
which extends Distributed.jl (part of the Julia standard library) to spread out
worker processes across a slurm allocation.

For other cluster managers, see the [`ClusterManagers.jl`](https://github.com/JuliaParallel/ClusterManagers.jl) documentation.

## Example Script

Here is the example script we would like to run using our slurm cluster.
We will pass the `addprocs_function` to the `SRRegressor` constructor,
which will be used to add worker processes to the cluster.

```julia
# script.jl

using SymbolicRegression

using Distributed: addprocs
using SlurmClusterManager: SlurmManager
using MLJ: machine, fit!

# Figure out how large a job we are launching
num_tasks = parse(Int, ENV["SLURM_NTASKS"])

# Define a custom loss function (this will
# be automatically passed to the workers)
my_loss(pred, targ) = abs2(pred - targ)

# Create a simple dataset
X = (; x1=randn(10_000), x2=20rand(10_000))
y = 2 .* cos.(X.x2) .+ X.x1 .^ 2 .- 1

add_slurm(_; kws...) = addprocs(SlurmManager(); kws...)

model = SRRegressor(;
    unary_operators=(),
    binary_operators=(+, *, -, /, mod),
    niterations=5000,
    elementwise_loss=my_loss,
    ######################################
    #= KEY OPTIONS FOR DISTRIBUTED MODE =#
    parallelism=:multiprocessing,
    addprocs_function=add_slurm,
    #numprocs=num_tasks,  # <- Not relevant for `SlurmManager`, but some other cluster managers need it
    ######################################
    # Scaled # of populations means workers can stay busy:
    populations=num_tasks * 3,
    # Larger ncycles_per_iteration means reduced
    # communication overhead with head worker node:
    ncycles_per_iteration=300,
    # If you need additional modules on workers, pass them to `worker_imports` as symbols:
    #worker_imports=[:VectorizationBase],
)

mach = machine(model, X, y)
fit!(mach)
```

Save this as `script.jl`.

This script should be launched once within the slurm allocation;
`SlurmManager` will then automatically add worker processes via
Julia's Distributed.jl.

## Interactive Mode, using `salloc`

Now, let's see how to launch this. The first technique
is interactive - this is useful at the prototyping stage,
as you can quickly re-run the script within the same allocation.

First, request resources:

```bash
salloc -p YOUR_PARTITION -N 2
```

with whatever other settings you need (follow your institution's documentation).

Then, view the allocated nodes:

```bash
squeue -u $USER
```

You should then usually be able to directly connect
to one of the allocated nodes:

```bash
ssh YOUR_NODE_NAME
```

On this node, you can now run the script.
When you do this, because you are running interactively,
you will need to declare the number of tasks. Do this
with `SLURM_NTASKS`:

```bash
SLURM_NTASKS=127 julia --project=. script.jl
```

`SLURM_NTASKS` specifies how many worker processes to spawn.
You might also want to declare `JULIA_NUM_THREADS=1` here,
to not overuse resources.

## Batch Mode, using `sbatch`

The more common technique is to create a batch script,
which you can then submit to the cluster.

Let's say we want to create a batch script
on partition `gen`, and allocate 128 SymbolicRegression workers.
For each worker, we'll assign 1 CPU core.
Let's also say that we'll run this job for up to 1 day.

Create a batch script, `batch.sh`:

```bash
#!/usr/bin/env bash
#SBATCH -p gen
#SBATCH -n 128
#SBATCH --cpus-per-task=1
#SBATCH --time=1-00:00:00
#SBATCH --job-name=sr_example

julia --project=. script.jl
```

We can simply submit it:

```bash
sbatch batch.sh
```

Slurm will then allocate the necessary nodes automatically.

## Explicit Worker Management

For more explicit control over the worker processes,
including the ability to specify multiple functions that
need to be defined on each worker (normally only one level
of functions are passed to each worker), you can pass
a list of processes directly to the `SRRegressor` constructor.

```julia
using SymbolicRegression

using Distributed: addprocs, @everywhere
using SlurmClusterManager: SlurmManager
using MLJ: machine, fit!

num_tasks = parse(Int, ENV["SLURM_NTASKS"])

procs = addprocs(SlurmManager())

@everywhere begin
    # define functions you need on workers
    function my_loss(pred, targ)
        abs2(pred - targ)
    end

    # define any other modules you need on workers
    using VectorizationBase
end

model = SRRegressor(;
    #= same as before =#
    #= ... =#

    procs=procs,  # Pass workers explicitly
    addprocs_function=nothing,  # <- Only used for SR-managed workers
)
```
