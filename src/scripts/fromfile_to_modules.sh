#!/bin/bash
# Requires vim-stream (https://github.com/MilesCranmer/vim-stream)

# The user passes files as arguments:
FILES=$@

# Loop through files:
for file in $FILES; do
    base=$(basename ${file%.*})
    cat $file | vims -t '%g/^@from/s/@from "\(.\{-}\)\.jl" import/import .\1:/g' -e 'using FromFile' 'dd' -s "Omodule ${base}\<enter>" 'Go\<enter>end' > tmp.jl
    mv tmp.jl $file
done