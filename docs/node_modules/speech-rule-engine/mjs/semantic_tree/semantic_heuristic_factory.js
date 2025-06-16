export const SemanticHeuristics = {
    factory: null,
    updateFactory: function (nodeFactory) {
        SemanticHeuristics.factory = nodeFactory;
    },
    heuristics: new Map(),
    flags: {
        combine_juxtaposition: true,
        convert_juxtaposition: true,
        multioperator: true
    },
    blacklist: {},
    add: function (heuristic) {
        const name = heuristic.name;
        SemanticHeuristics.heuristics.set(name, heuristic);
        if (!SemanticHeuristics.flags[name]) {
            SemanticHeuristics.flags[name] = false;
        }
    },
    run: function (name, root, opt_alternative) {
        const heuristic = SemanticHeuristics.heuristics.get(name);
        return heuristic &&
            !SemanticHeuristics.blacklist[name] &&
            (SemanticHeuristics.flags[name] || heuristic.applicable(root))
            ? heuristic.apply(root)
            : opt_alternative
                ? opt_alternative(root)
                : root;
    }
};
