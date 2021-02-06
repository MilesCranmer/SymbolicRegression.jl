#!/bin/bash

julia --project=. -e 'import Pkg; Pkg.add("Coverage")' && \
    julia --color=yes --inline=yes --depwarn=yes --code-coverage=user --project=. -e 'import Pkg; Pkg.test(coverage=true)' && \
    ./test/pipelines.sh --code-coverage=user
    julia coverage.jl
