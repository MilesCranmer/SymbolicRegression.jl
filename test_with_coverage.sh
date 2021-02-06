#!/bin/bash

julia --color=yes --inline=yes --depwarn=yes --code-coverage=user --project=. -e 'import pkg; pkg.test(coverage=true)' && \
    ./test/pipelines.sh --code-coverage=user
    julia coverage.jl
