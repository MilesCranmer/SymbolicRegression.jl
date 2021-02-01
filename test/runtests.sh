#!/bin/bash
cwd=$(pwd)
parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

cd $parent_path/..

echo "Basic run"                               && julia --project=. test/basic.jl                 && \
echo "Manual distributed with user-defined op" && julia --project=. test/manual_distributed.jl    && \
echo "Auto distributed with user-defined op"   && julia --project=. test/user_defined_operator.jl

cd $cwd
