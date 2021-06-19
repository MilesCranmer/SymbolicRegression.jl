import pandas as pd
import numpy as np


class Node:
    """Simple tree storing data at each node"""

    def __init__(self):
        self.data = {}
        self.parent = None
        self.children = []

    def __repr__(self):
        return f"Node with {len(self.children)} children: " + str(self.data)


# Pre-process with:
# Delete first two lines.
# :%s/╎/|/gce
# %g/^/exe "norm v$F|/[0-9]\<enter>hr|"
f = open("prof_v5.txt", "r")
lines = f.read().split("\n")
nlines = len(lines)


def collect_children(parent, start_line_idx):

    for line_idx in range(start_line_idx, nlines):

        l = lines[line_idx]
        l = l.split("|")
        indent = len(l) - 1
        same_level = indent == parent.data["indent"]
        if same_level:
            break

        is_child = indent == parent.data["indent"] + 1
        too_nested = indent > 25
        if is_child and not too_nested:
            tokens = l[-1].split()
            time = int(tokens[0])
            info = " ".join(tokens[1:])
            new_node = Node()
            new_node.data = {"time": time, "info": info, "indent": indent}
            new_node.parent = parent
            collect_children(new_node, line_idx + 1)
            new_node.children = sorted(new_node.children, key=lambda n: -n.data["time"])
            parent.children.append(new_node)

    return


root = Node()
root.data = {"time": 0, "info": "", "indent": 4}
collect_children(root, 0)


def go_to_level(node, levels):
    for level in levels:
        node = node.children[level]
    return node


# Walk through biggest functions:
print(go_to_level(root, [0] * 13 + [1] + [0] * 4))
print(go_to_level(root, [0] * 15))
print(go_to_level(root, [0] * 13 + [1] + [0]))
