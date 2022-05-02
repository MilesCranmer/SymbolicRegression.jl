from glob import glob
import re

# Use src/Deprecates.jl to replace all deprecated functions
# in entire codebase, excluding src/Deprecates.jl

# First, we build the library:
with open("src/Deprecates.jl", "r") as f:
    library = {}
    for line in f.read().split("\n"):
        # If doesn't start with `@deprecate`, skip:
        if not line.startswith("@deprecate"):
            continue

        # Each line is in the format:
        # @deprecate <function> <replacement>
        function_name = line.split(" ")[1]
        replacement = line.split(" ")[2]
        library[function_name] = replacement

# Now, we replace all deprecated functions in src/*.jl:
for fname in glob("**/*.jl"):
    if fname == "src/Deprecates.jl":
        continue
    with open(fname, "r") as f:
        contents = f.read()
        for function_name in library:
            contents = re.sub(
                r"\b" + function_name + r"\b", library[function_name], contents
            )
    with open(fname, "w") as f:
        f.write(contents)