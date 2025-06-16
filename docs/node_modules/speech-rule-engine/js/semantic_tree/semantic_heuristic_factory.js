"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SemanticHeuristics = void 0;
exports.SemanticHeuristics = {
    factory: null,
    updateFactory: function (nodeFactory) {
        exports.SemanticHeuristics.factory = nodeFactory;
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
        exports.SemanticHeuristics.heuristics.set(name, heuristic);
        if (!exports.SemanticHeuristics.flags[name]) {
            exports.SemanticHeuristics.flags[name] = false;
        }
    },
    run: function (name, root, opt_alternative) {
        const heuristic = exports.SemanticHeuristics.heuristics.get(name);
        return heuristic &&
            !exports.SemanticHeuristics.blacklist[name] &&
            (exports.SemanticHeuristics.flags[name] || heuristic.applicable(root))
            ? heuristic.apply(root)
            : opt_alternative
                ? opt_alternative(root)
                : root;
    }
};
