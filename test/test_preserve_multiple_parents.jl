using SymbolicRegression
using Test

options = Options(;
    binary_operators=(+, -, *, ^, /, greater), unary_operators=(cos, exp, sin)
)
x1, x2, x3 = Node("x1"), Node("x2"), Node("x3")

base_tree = cos(x1 - 3.2 * x2) - safe_pow(x1, 3.2)
tree = sin(base_tree) + base_tree

# The base tree is exactly the same:
@test tree.l.l === tree.r
@test hash(tree.l.l) == hash(tree.r)

# Now, let's change something in the base tree:
old_tree = deepcopy(tree)
base_tree.l.l = x3 * x2 - 1.5

# Should change:
@test string_tree(tree, options) != string_tree(old_tree, options)

# But the linkage should be preserved:
@test tree.l.l === tree.r
@test hash(tree.l.l) == hash(tree.r)

# When we copy with the normal copy, the topology breaks:
copy_without_topology = copy_node(tree)
@test !(copy_without_topology.l.l === copy_without_topology.r)

# But with the topology preserved in the copy, it should be the same:
copy_with_topology = copy_node(tree; preserve_topology=true)
@test copy_with_topology.l.l === copy_with_topology.r

# We can also tweak the new tree, and the edits should be propagated:
copied_base_tree = copy_with_topology.l.l
# (First, assert that it is the same as the old base tree)
@test string_tree(copied_base_tree, options) == string_tree(base_tree, options)

# Now, let's tweak the new tree's base tree:
copied_base_tree.l.l = x1 * x2 * 5.2 - exp(x3)
# "exp" should appear *twice* now:
copy_with_topology
@test length(collect(eachmatch(r"exp", string_tree(copy_with_topology, options)))) == 2
@test copy_with_topology.l.l === copy_with_topology.r
@test hash(copy_with_topology.l.l) == hash(copy_with_topology.r)
@test string_tree(copy_with_topology.l.l, options) != string_tree(base_tree, options)

# We also test whether `convert` breaks shared children.
# The node type here should be Float64.
@test typeof(tree).parameters[1] == Float64
# Let's convert to Float32:
float32_tree = convert(Node{Float32}, tree)
@test typeof(float32_tree).parameters[1] == Float32
# The linkage should be kept:
@test float32_tree.l.l === float32_tree.r
