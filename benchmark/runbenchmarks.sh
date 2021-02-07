#/bin/bash
# In root.
cp benchmark/Project.toml     .Project.toml
cp benchmark/Manifest.toml    .Manifest.toml
cp benchmark/runbenchmarks.jl .runbenchmarks.jl
cp benchmark/benchmarks.jl    .benchmarks.jl

for commit in $(git log --pretty=oneline --since="2 weeks ago" | vims -l 'wd$'); do
    git checkout $commit
    mkdir -p benchmark
    cp .Project.toml     benchmark/Project.toml
    cp .Manifest.toml    benchmark/Manifest.toml
    cp .runbenchmarks.jl benchmark/runbenchmarks.jl
    cp .benchmarks.jl    benchmark/benchmarks.jl
    cat $commit >> output.csv
    julia --project=benchmark benchmark/runbenchmarks.jl
    git checkout -f
    rm benchmark/Project.toml
    rm benchmark/Manifest.toml
    rm benchmark/runbenchmarks.jl
    rm benchmark/benchmarks.jl
done
