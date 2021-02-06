#!/bin/bash
cwd=$(pwd)
parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
extra_flags=$1

cd $parent_path/..

echo "Manual distributed with user-defined op" && julia $extra_flags --project=. test/manual_distributed.jl    && \
echo "Auto distributed with user-defined op"   && julia $extra_flags --project=. test/user_defined_operator.jl

cd $cwd
