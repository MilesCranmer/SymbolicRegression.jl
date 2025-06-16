"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SemanticMmlHeuristic = exports.SemanticMultiHeuristic = exports.SemanticTreeHeuristic = void 0;
class SemanticAbstractHeuristic {
    constructor(name, method, predicate = (_x) => false) {
        this.name = name;
        this.apply = method;
        this.applicable = predicate;
    }
}
class SemanticTreeHeuristic extends SemanticAbstractHeuristic {
}
exports.SemanticTreeHeuristic = SemanticTreeHeuristic;
class SemanticMultiHeuristic extends SemanticAbstractHeuristic {
}
exports.SemanticMultiHeuristic = SemanticMultiHeuristic;
class SemanticMmlHeuristic extends SemanticAbstractHeuristic {
}
exports.SemanticMmlHeuristic = SemanticMmlHeuristic;
