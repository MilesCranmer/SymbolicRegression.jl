#!/bin/bash

julia --code-coverage=user --project=. -e 'import Pkg; Pkg.test("SymbolicRegression"; coverage=true)' && \
    ./test/pipelines.sh --code-coverage=user
    julia coverage.jl
