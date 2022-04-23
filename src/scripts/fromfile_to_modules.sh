#!/bin/bash
# Requires vim-stream (https://github.com/MilesCranmer/vim-stream)

# The user passes files as arguments:
FILES=$@

# Loop through files:
for file in $FILES; do
    base=$(basename ${file%.*})
    cat $file | vims -t '%g/^@from/s/@from "\(.\{-}\)\.jl" import/import ..\1Module:/g' -e 'using FromFile' 'dd' -s "Omodule ${base}Module\<enter>" 'Go\<enter>end' | sed "s/^ $//g" > tmp.jl
    mv tmp.jl $file
done


# Changes to make:
# - Run this file on everything.
# - Change `import ..` to `import .` in SymbolicRegression.jl
# - Rename module that have same name as existing variables:
    # - All files are mapped to _{file}.jl, and modules as well.