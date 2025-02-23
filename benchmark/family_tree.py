import json
import networkx as nx
from tqdm import tqdm


def load_pysr_graph(json_path, progress=True):
    """Load a PySR recorder JSON file into a NetworkX directed graph.

    Args:
        json_path: Path to pysr_recorder.json
        progress: Show progress bars

    Returns:
        NetworkX DiGraph with:
        - Node attributes: tree, cost, loss, parent
        - Edge attributes: type, time, mutation_details
    """
    # Load JSON data
    with open(json_path) as f:
        data = json.load(f)

    G = nx.DiGraph()

    # First pass: Create all nodes with their attributes
    mutations = data.get("mutations", {})
    for member_id, member_data in tqdm(
        mutations.items(),
        desc="Adding nodes" if progress else None,
        disable=not progress,
    ):
        # Convert string ID to int
        member_id = int(member_id)
        G.add_node(member_id, **member_data)

    # Debug print - check a sample member's data
    sample_id = next(iter(mutations))
    print("\nSample member data:")
    print(f"ID: {sample_id}")
    print(f"Parent: {mutations[sample_id].get('parent')}")
    print(f"Events: {len(mutations[sample_id].get('events', []))}")
    if mutations[sample_id].get("events"):
        print("First event:", mutations[sample_id]["events"][0])

    # Count event types
    event_counts = {"mutate": 0, "crossover": 0, "tuning": 0, "other": 0}
    edge_counts = {"parent": 0, "mutate": 0, "crossover": 0, "tuning": 0}

    # Second pass: Create edges based on relationships
    for member_id_str, member_data in tqdm(
        mutations.items(),
        desc="Processing edges" if progress else None,
        disable=not progress,
    ):
        member_id = int(member_id_str)

        # Add parent edge if exists
        parent_id = member_data.get("parent")
        if parent_id:
            parent_id = int(parent_id)
            if parent_id in G:
                G.add_edge(parent_id, member_id, type="parent")
                edge_counts["parent"] += 1

        # Process all events
        for event in member_data.get("events", []):
            event_type = event.get("type")
            event_counts[event_type if event_type in event_counts else "other"] += 1

            # Mutation events
            if event_type == "mutate":
                child_id = event.get("child")
                if child_id:
                    child_id = int(child_id)
                    if child_id in G:
                        G.add_edge(
                            member_id,
                            child_id,
                            type="mutate",
                            time=event.get("time"),
                            details=event.get("mutation", {}),
                        )
                        edge_counts["mutate"] += 1

            # Crossover events
            elif event_type == "crossover":
                parent1 = event.get("parent1")
                parent2 = event.get("parent2")
                child1 = event.get("child1")
                child2 = event.get("child2")

                # Convert IDs to integers
                if parent1:
                    parent1 = int(parent1)
                if parent2:
                    parent2 = int(parent2)
                if child1:
                    child1 = int(child1)
                if child2:
                    child2 = int(child2)

                # Crossover events - connect both parents to both children
                # For child1:
                if parent1 and child1 and child1 in G:
                    G.add_edge(
                        parent1,
                        child1,
                        type="crossover",
                        time=event.get("time"),
                        partner=parent2,
                        details=event.get("details", {}),
                    )
                    edge_counts["crossover"] += 1
                if parent2 and child1 and child1 in G:
                    G.add_edge(
                        parent2,
                        child1,
                        type="crossover",
                        time=event.get("time"),
                        partner=parent1,
                        details=event.get("details", {}),
                    )
                    edge_counts["crossover"] += 1

                # For child2:
                if parent1 and child2 and child2 in G:
                    G.add_edge(
                        parent1,
                        child2,
                        type="crossover",
                        time=event.get("time"),
                        partner=parent2,
                        details=event.get("details", {}),
                    )
                    edge_counts["crossover"] += 1
                if parent2 and child2 and child2 in G:
                    G.add_edge(
                        parent2,
                        child2,
                        type="crossover",
                        time=event.get("time"),
                        partner=parent1,
                        details=event.get("details", {}),
                    )
                    edge_counts["crossover"] += 1

            # Tuning events
            elif event_type == "tuning":
                child_id = event.get("child")
                if child_id:
                    child_id = int(child_id)
                    if child_id in G:
                        G.add_edge(
                            member_id,
                            child_id,
                            type="tuning",
                            time=event.get("time"),
                            details=event.get("mutation", {}),
                        )
                        edge_counts["tuning"] += 1

    print("\nEvent counts:", event_counts)
    print("Edge counts:", edge_counts)
    return G


def simplify_graph(G):
    """Create a simplified version with only essential attributes"""
    simple_G = nx.DiGraph()

    for node, data in G.nodes(data=True):
        # Keep full tree and add a truncated version for display
        tree = data.get("tree", "No equation")
        display_tree = str(tree)
        if len(display_tree) > 30:  # Truncate long equations
            display_tree = display_tree[:27] + "..."

        simple_G.add_node(
            node,
            cost=data.get("cost"),
            loss=data.get("loss"),
            tree=tree,
            display_tree=display_tree,
        )

    for u, v, data in G.edges(data=True):
        simple_G.add_edge(u, v, type=data.get("type"), time=data.get("time"))

    return simple_G


if __name__ == "__main__":
    # Example usage
    G = load_pysr_graph("pysr_recorder.json")

    # Basic stats
    print(f"Loaded graph with {len(G)} nodes and {G.size()} edges")

    # Save simplified version
    simple_G = simplify_graph(G)
    nx.write_graphml(simple_G, "pysr_graph.graphml")
